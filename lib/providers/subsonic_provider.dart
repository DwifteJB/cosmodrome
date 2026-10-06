import 'dart:async';
import 'dart:convert';

import 'package:cosmodrome/helpers/subsonic-api-helper/api/basic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/user.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/providers/subsonic_account.dart';
import 'package:cosmodrome/services/offline_cache_service.dart';
import 'package:cosmodrome/utils/logger/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _keyAccounts = 'subsonic_accounts';
const _keyActiveId = 'subsonic_active_id';
const _keyKnownServers = 'subsonic_known_servers';

enum AuthState { initial, loading, authenticated, unauthenticated }

class SubsonicProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  AuthState _authState = AuthState.initial;
  final List<SubsonicAccount> _accounts = [];

  final List<SubsonicServer> knownServers = [];

  String? _activeId;
  String? _errorMessage;
  bool _isOffline = false;
  int _pingFailures = 0;
  bool _canPollConnectivity = true;
  bool _connectivityCheckInFlight = false;
  Timer? _connectivityPoller;
  final Map<String, int> _connectivityFailureCounts = {};
  final Map<String, DateTime> _connectivityDebounceUntil = {};

  List<SubsonicAccount> get accounts => List.unmodifiable(_accounts);
  SubsonicAccount? get activeAccount => _activeId == null
      ? null
      : _accounts.where((a) => a.id == _activeId).firstOrNull;
  String? get errorMessage => _errorMessage;

  bool get isOffline => _isOffline;

  @visibleForTesting
  void debugUseAccount(SubsonicAccount account) {
    _accounts
      ..clear()
      ..add(account);
    _activeId = account.id;
    _authState = AuthState.authenticated;
    notifyListeners();
  }

  /// The current subsonic istance for the active account. Will throw if not authenticated.
  /// Should use this instead of .activeAccount.subsonic
  Subsonic get subsonic {
    assert(activeAccount != null, 'SubsonicProvider: no active account');
    return activeAccount!.subsonic;
  }

  /// Adds a new account and makes it active. If an account with the same id
  /// already exists, it will be replaced. Returns an error message on failure.
  Future<String?> addAccount({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    _errorMessage = null;
    notifyListeners();

    // try get timeout seconds from servers list if it exists, otherwise use default
    final existingServer = knownServers.firstWhere(
      (s) => baseUrl.contains(s.baseUrl),
      orElse: () => SubsonicServer(baseUrl: baseUrl, name: baseUrl),
    );

    final sub = Subsonic(
      baseUrl: baseUrl,
      username: username,
      password: password,
      timeoutSeconds: existingServer.timeoutSeconds,
    );

    final ping = await sub.ping();
    if (!ping.success) {
      final error = ping.errorMessage ?? 'Could not reach server';
      _errorMessage = error;
      loggerPrint('SubsonicProvider: ping failed - $error');
      notifyListeners();
      return error;
    }

    try {
      final user = await sub.getUser();
      // the ping above probed which login method this server accepts, keep it
      // so we don't have to probe again every launch
      final account = SubsonicAccount(
        baseUrl: baseUrl,
        username: username,
        password: password,
        user: user,
        loginMethod: sub.loginMethod,
      );

      // if account with same id exists, replace it. otherwise add new

      final existing = _accounts.indexWhere((a) => a.id == account.id);
      if (existing != -1) {
        _accounts[existing] = account;
        loggerPrint('SubsonicProvider: updated existing account ${account.id}');
      } else {
        _accounts.add(account);
        loggerPrint('SubsonicProvider: added account ${account.id}');
      }

      _activeId = account.id;
      _isOffline = false;
      clearCoverArtCache();
      _startConnectivityPolling();
      await _persist();
      _setState(AuthState.authenticated);
      return null;
    } catch (e) {
      final error = e.toString();
      _errorMessage = error;
      loggerPrint('SubsonicProvider: addAccount failed - $error');
      notifyListeners();
      return error;
    }
  }

  Future<bool> addKnownServer(
    String baseUrl, {
    String? name,
    int? timeoutSeconds = 15,
  }) async {
    if (knownServers.any((s) => s.baseUrl == baseUrl)) {
      loggerPrint('SubsonicProvider: server $baseUrl already known');
      return true; // already known, consider it a success
    }

    final server = SubsonicServer(baseUrl: baseUrl, name: name ?? baseUrl);
    final success = await server.tryConnect();

    if (success) {
      knownServers.add(server);
      loggerPrint(
        'SubsonicProvider: added known server $baseUrl, can connect successfully',
      );
    } else {
      loggerPrint(
        'SubsonicProvider: failed to connect to server $baseUrl, cannot add as known server',
      );
    }

    await _persist(); // save known servers to storage
    notifyListeners();
    return success;
  }

  /// Pings the active server and updates [isOffline]
  Future<void> checkConnectivity() async {
    if (!_canPollConnectivity || _connectivityCheckInFlight) return;

    final account = activeAccount;
    if (account == null) return;

    _connectivityCheckInFlight = true;

    try {
      final now = DateTime.now();
      if (_isServerDebounced(account.baseUrl, now)) {
        return;
      }

      // ping never throws, it reports failures in its result
      final result = await account.subsonic.ping(timeoutSeconds: 8);
      // auth errors mean we can still "connect" with proper creds
      final failed = !result.success && result.errorCode == null;

      if (failed) {
        _pingFailures++;
        _recordServerFailure(account.baseUrl, now);
      } else {
        _pingFailures = 0;
        _recordServerSuccess(account.baseUrl);
      }
      // one blip shouldn't lock the ui, wait for a second miss
      final offline = failed && (_isOffline || _pingFailures >= 2);

      var changed = false;
      if (_isOffline != offline) {
        _isOffline = offline;
        changed = true;
      }

      final idx = knownServers.indexWhere((s) => s.baseUrl == account.baseUrl);
      if (idx >= 0 && knownServers[idx].canConnect != !offline) {
        knownServers[idx].canConnect = !offline;
        changed = true;
      }

      final serverChanged = await _refreshKnownServersConnectivity(
        skipBaseUrl: account.baseUrl,
      );
      if (changed || serverChanged) {
        notifyListeners();
      }
    } finally {
      _connectivityCheckInFlight = false;
    }
  }

  /// deletes cache for the active account and all known servers, then tries to ping them to refresh connectivity status
  Future<void> deleteCacheForActiveAccount() async {
    final active = activeAccount;
    if (active == null) return;

    await offlineCacheService.clearCacheForAccount(active.id);

    active.subsonic.clearCache();

    await _refreshKnownServersConnectivity();
    await checkConnectivity();
  }

  @override
  void dispose() {
    _connectivityPoller?.cancel();
    super.dispose();
  }

  /// Removes an account by id. If it was the active account, switches to
  /// the next available one (or sets unauthenticated if none remain).
  Future<void> removeAccount(String id) async {
    _accounts.removeWhere((a) => a.id == id);
    loggerPrint('SubsonicProvider: removed account $id');

    if (_activeId == id) {
      _activeId = _accounts.firstOrNull?.id;
      clearCoverArtCache();
    }

    await _persist();
    _setState(
      _accounts.isEmpty ? AuthState.unauthenticated : AuthState.authenticated,
    );
  }

  /// Updates an existing server's name (and optionally URL).
  /// If the URL changes, the new URL is pinged to verify it works, and all
  /// accounts tied to the old URL are removed (their baseUrl is immutable).
  /// Returns false if the new URL cannot be reached.
  Future<bool> updateKnownServer(
    String oldBaseUrl, {
    required String newName,
    String? newBaseUrl,
  }) async {
    final idx = knownServers.indexWhere((s) => s.baseUrl == oldBaseUrl);
    if (idx == -1) return false;

    final old = knownServers[idx];
    String normalizedUrl = (newBaseUrl?.trim().isNotEmpty == true)
        ? newBaseUrl!
        : oldBaseUrl;
    if (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }

    if (normalizedUrl != oldBaseUrl) {
      final newServer = SubsonicServer(baseUrl: normalizedUrl, name: newName);
      final success = await newServer.tryConnect();
      if (!success) return false;

      knownServers[idx] = newServer;

      final hadActive = activeAccount?.baseUrl == oldBaseUrl;
      _accounts.removeWhere((a) => a.baseUrl == oldBaseUrl);
      if (hadActive) {
        _activeId = _accounts.firstOrNull?.id;
        clearCoverArtCache();
      }
    } else {
      knownServers[idx] = SubsonicServer(
        baseUrl: old.baseUrl,
        name: newName,
        timeoutSeconds: old.timeoutSeconds,
        canConnect: old.canConnect,
      );
    }

    await _persist();
    if (normalizedUrl != oldBaseUrl && _accounts.isEmpty) {
      _setState(AuthState.unauthenticated);
    } else {
      notifyListeners();
    }
    return true;
  }

  /// Updates an existing account's credentials. If the username changes the
  /// old account record is removed after the new one is successfully added.
  Future<String?> updateAccount({
    required String oldId,
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final error = await addAccount(
      baseUrl: baseUrl,
      username: username,
      password: password,
    );
    if (error == null) {
      final newId = '$username@$baseUrl';
      if (oldId != newId) {
        _accounts.removeWhere((a) => a.id == oldId);
        if (_activeId == oldId) _activeId = newId;
        await _persist();
        notifyListeners();
      }
    }
    return error;
  }

  Future<void> removeKnownServer(String baseUrl) async {
    knownServers.removeWhere((s) => s.baseUrl == baseUrl);

    // remove all accounts that belong to this server

    // check if the active account belongs to this server, if so switch to another one (or unauthenticated if none remain)
    if (activeAccount?.baseUrl == baseUrl) {
      _activeId = _accounts.where((a) => a.baseUrl != baseUrl).firstOrNull?.id;
      clearCoverArtCache();
      if (_activeId == null) {
        _setState(AuthState.unauthenticated);
      }
    }

    // remove accounts from this server
    _accounts.removeWhere((a) => a.baseUrl == baseUrl);

    loggerPrint('SubsonicProvider: removed known server $baseUrl');
    await _persist(); // save known servers to storage
    notifyListeners();
  }

  void setAppLifecycleState(AppLifecycleState state) {
    final canPoll = state == AppLifecycleState.resumed;
    if (_canPollConnectivity == canPoll) {
      return;
    }

    _canPollConnectivity = canPoll;
    if (!canPoll) {
      _connectivityPoller?.cancel();
      _connectivityPoller = null;
      return;
    }

    if (_authState == AuthState.authenticated && activeAccount != null) {
      _startConnectivityPolling();
      unawaited(checkConnectivity());
    }
  }

  /// Switches the active account.
  /// if [id] is "none", will switch to no account
  void switchAccount(String id) {
    final none = id == "none";
    assert(
      none || _accounts.any((a) => a.id == id),
      'switchAccount: unknown id $id',
    );
    _activeId = none ? null : id;
    _isOffline = false;
    clearCoverArtCache();
    _startConnectivityPolling();

    if (none) {
      loggerPrint('SubsonicProvider: switched to no active account');
      _setState(AuthState.unauthenticated);
      return;
    }
    loggerPrint('SubsonicProvider: switched to $id');

    _getAvatarsForActiveAccount();
    unawaited(checkConnectivity());

    _storage.write(key: _keyActiveId, value: id);
    notifyListeners();
  }

  /// Attempts to restore accounts and active session from storage.
  /// Also attempts to get all known servers from the accounts and test connectivity, removing those that fail.
  /// For ALL accounts.
  Future<void> tryRestoreSession() async {
    _setState(AuthState.loading);

    // read known servers first
    await _getKnownServersFromStorage();

    final raw = await _storage.read(key: _keyAccounts);
    final activeId = await _storage.read(key: _keyActiveId);

    if (raw == null) {
      loggerPrint('SubsonicProvider: no saved accounts');
      return _setState(AuthState.unauthenticated);
    }

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        final account = SubsonicAccount.fromJson(item as Map<String, dynamic>);
        _accounts.add(account);
        loggerPrint('SubsonicProvider: restored account ${account.id}');
      }
    } catch (e) {
      loggerPrint('SubsonicProvider: failed to restore accounts - $e');
      await _storage.delete(key: _keyAccounts);
      return _setState(AuthState.unauthenticated);
    }

    if (_accounts.isEmpty) {
      return _setState(AuthState.unauthenticated);
    }

    // restore active account, default to first if missing or invalid
    _activeId = _accounts.any((a) => a.id == activeId)
        ? activeId
        : _accounts.first.id;

    clearCoverArtCache();

    _getAvatarsForActiveAccount();
    _startConnectivityPolling();
    loggerPrint('SubsonicProvider: active account is $_activeId');
    _setState(AuthState.authenticated);
    await checkConnectivity();
  }

  Future<void> _getAvatarsForActiveAccount() async {
    final active = activeAccount;
    if (active == null || active.avatar.isNotEmpty) return;

    if (await _fetchAvatar(active)) notifyListeners();
  }

  /// Fetches the active account's avatar if its server is known to be reachable.
  Future<void> _getAvatarForReachableActiveAccount() async {
    final account = activeAccount;
    if (account == null || account.avatar.isNotEmpty) return;

    // check if the server is reachable before trying to fetch avatar
    final reachable =
        knownServers
            .where((s) => account.baseUrl.contains(s.baseUrl))
            .firstOrNull
            ?.canConnect ??
        false;
    if (!reachable) {
      loggerPrint(
        'SubsonicProvider: skipping avatar fetch for ${account.username} because server ${account.baseUrl} is not reachable',
      );
      return;
    }

    await _fetchAvatar(account);
  }

  /// Returns whether the avatar was fetched successfully.
  Future<bool> _fetchAvatar(SubsonicAccount account) async {
    try {
      account.avatar = await account.subsonic.getAvatar();
      loggerPrint('SubsonicProvider: fetched avatar for ${account.username}');
      return true;
    } catch (e) {
      loggerPrint(
        'SubsonicProvider: failed to fetch avatar for ${account.username} - $e',
      );
      return false;
    }
  }

  Future<void> _getKnownServersFromStorage() async {
    final raw = await _storage.read(key: _keyKnownServers);
    if (raw == null) {
      loggerPrint('SubsonicProvider: no known servers in storage');
      return;
    }

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        final server = SubsonicServer(
          baseUrl: item['baseUrl'] as String,
          name: item['name'] as String,
        );

        // try connecting to the server before adding it to the known servers list
        if (!await server.tryConnect(timeoutSeconds: 3)) {
          loggerPrint(
            'SubsonicProvider: cannot connect to known server ${server.baseUrl}, skipping',
          );
        }

        knownServers.add(server);
        loggerPrint(
          'SubsonicProvider: restored known server ${server.baseUrl}',
        );
      }
    } catch (e) {
      loggerPrint('SubsonicProvider: failed to restore known servers - $e');
      await _storage.delete(key: _keyKnownServers);
    }
  }

  bool _isServerDebounced(String baseUrl, DateTime now) {
    final until = _connectivityDebounceUntil[baseUrl];
    if (until == null) return false;

    if (!now.isBefore(until)) {
      _connectivityDebounceUntil.remove(baseUrl);
      _connectivityFailureCounts.remove(baseUrl);
      return false;
    }

    return true;
  }

  // saves accounts to storage! saving!
  Future<void> _persist() async {
    final json = jsonEncode(_accounts.map((a) => a.toJson()).toList());
    await _storage.write(key: _keyAccounts, value: json);
    if (_activeId != null) {
      await _storage.write(key: _keyActiveId, value: _activeId);
    }

    // also save known servers
    final serversJson = jsonEncode(
      knownServers.map((s) => {'baseUrl': s.baseUrl, 'name': s.name}).toList(),
    );
    await _storage.write(key: _keyKnownServers, value: serversJson);

    // TEMP? get all avatars
    await _getAvatarForReachableActiveAccount();
  }

  void _recordServerFailure(String baseUrl, DateTime now) {
    final failureCount = (_connectivityFailureCounts[baseUrl] ?? 0) + 1;
    if (failureCount >= 3) {
      _connectivityFailureCounts.remove(baseUrl);
      _connectivityDebounceUntil[baseUrl] = now.add(
        const Duration(seconds: 60),
      );
      loggerPrint(
        'SubsonicProvider: debouncing $baseUrl for 60 seconds after repeated connectivity failures',
      );
      return;
    }

    _connectivityFailureCounts[baseUrl] = failureCount;
  }

  void _recordServerSuccess(String baseUrl) {
    _connectivityFailureCounts.remove(baseUrl);
    _connectivityDebounceUntil.remove(baseUrl);
  }

  Future<bool> _refreshKnownServersConnectivity({String? skipBaseUrl}) async {
    if (!_canPollConnectivity) return false;

    var changed = false;
    final now = DateTime.now();
    for (final server in knownServers) {
      if (skipBaseUrl != null && server.baseUrl == skipBaseUrl) {
        continue;
      }
      if (_isServerDebounced(server.baseUrl, now)) {
        continue;
      }

      final before = server.canConnect;
      final after = await server.tryConnect(timeoutSeconds: 3);
      if (after) {
        _connectivityFailureCounts.remove(server.baseUrl);
        _connectivityDebounceUntil[server.baseUrl] = now.add(
          const Duration(minutes: 3),
        );
      } else {
        _recordServerFailure(server.baseUrl, now);
      }
      if (before != after) {
        changed = true;
      }
    }
    return changed;
  }

  void _setState(AuthState state) {
    _authState = state;
    notifyListeners();
  }

  void _startConnectivityPolling() {
    if (!_canPollConnectivity) {
      _connectivityPoller?.cancel();
      _connectivityPoller = null;
      return;
    }

    _connectivityPoller?.cancel();
    _connectivityPoller = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(checkConnectivity());
    });
  }
}

class SubsonicServer {
  final String name;
  final String baseUrl;
  final int timeoutSeconds;
  bool canConnect = false;

  SubsonicServer({
    required this.baseUrl,
    required this.name,
    this.timeoutSeconds = 15,
    this.canConnect = false,
  });

  Future<bool> tryConnect({int? timeoutSeconds}) async {
    // just do a simple get check to see if the server is reachable & we get an error response (since we don't have credentials yet)
    final sub = Subsonic(
      baseUrl: baseUrl,
      username: 'dummy',
      password: 'dummy',
    );

    // ping never throws; with dummy creds it should fail with a subsonic API error
    final res = await sub.ping(
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
    );

    if (res.success) {
      // this should never happen so if it does its funny
      loggerPrint(
        'SubsonicServer: unexpected successful ping to $baseUrl with dummy credentials',
      );
    }

    // a subsonic API error means the server is reachable, which is expected.
    // any other error just means that its blocked/unreachable probably
    // (this happens a lot with local IPs since its trying to connect to "itself")
    canConnect = res.success || res.errorCode != null;
    return canConnect;
  }
}
