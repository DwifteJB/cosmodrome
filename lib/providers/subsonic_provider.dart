import 'dart:convert';

import 'package:cosmodrome/helpers/subsonic-api-helper/api/basic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/user.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/providers/subsonic_account.dart';
import 'package:cosmodrome/utils/logger.dart';
import 'package:flutter/foundation.dart';
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

  List<SubsonicAccount> get accounts => List.unmodifiable(_accounts);
  SubsonicAccount? get activeAccount => _activeId == null
      ? null
      : _accounts.where((a) => a.id == _activeId).firstOrNull;
  AuthState get authState => _authState;

  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _authState == AuthState.authenticated;

  /// The current subsonic istance for the active account. Will throw if not authenticated.
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

    final sub = Subsonic(
      baseUrl: baseUrl,
      username: username,
      password: password,
    );

    final ping = await sub.ping();
    if (!ping.success) {
      final error = ping.errorMessage ?? 'Could not reach server';
      _errorMessage = error;
      loggerPrint('SubsonicProvider: ping failed — $error');
      notifyListeners();
      return error;
    }

    try {
      final user = await sub.getUser();
      final account = SubsonicAccount(
        baseUrl: baseUrl,
        username: username,
        password: password,
        user: user,
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
      await _persist();
      _setState(AuthState.authenticated);
      return null;
    } catch (e) {
      final error = e.toString();
      _errorMessage = error;
      loggerPrint('SubsonicProvider: addAccount failed — $error');
      notifyListeners();
      return error;
    }
  }

  Future<bool> addKnownServer(String baseUrl, {String? name}) async {
    if (knownServers.any((s) => s.baseUrl == baseUrl)) {
      loggerPrint('SubsonicProvider: server $baseUrl already known');
      return true; // already known, consider it a success
    }

    final server = SubsonicServer(baseUrl: baseUrl, name: name ?? baseUrl);
    final success = await server.tryConnect();
    if (success) {
      knownServers.add(server);
      loggerPrint('SubsonicProvider: added known server $baseUrl');
    } else {
      loggerPrint('SubsonicProvider: failed to connect to server $baseUrl');
    }

    await _persist(); // save known servers to storage
    return success;
  }

  /// Removes an account by id. If it was the active account, switches to
  /// the next available one (or sets unauthenticated if none remain).
  Future<void> removeAccount(String id) async {
    _accounts.removeWhere((a) => a.id == id);
    loggerPrint('SubsonicProvider: removed account $id');

    if (_activeId == id) {
      _activeId = _accounts.firstOrNull?.id;
    }

    await _persist();
    _setState(
      _accounts.isEmpty ? AuthState.unauthenticated : AuthState.authenticated,
    );
  }

  /// Removes all accounts and clears storage.
  Future<void> removeAllAccounts() async {
    _accounts.clear();
    _activeId = null;
    _errorMessage = null;
    await _storage.delete(key: _keyAccounts);
    await _storage.delete(key: _keyActiveId);
    loggerPrint('SubsonicProvider: all accounts removed');
    _setState(AuthState.unauthenticated);
  }

  Future<void> removeKnownServer(String baseUrl) async {
    knownServers.removeWhere((s) => s.baseUrl == baseUrl);
    loggerPrint('SubsonicProvider: removed known server $baseUrl');
    await _persist(); // save known servers to storage
  }

  /// Switches the active account.
  void switchAccount(String id) {
    assert(_accounts.any((a) => a.id == id), 'switchAccount: unknown id $id');
    _activeId = id;
    loggerPrint('SubsonicProvider: switched to $id');
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
      loggerPrint('SubsonicProvider: failed to restore accounts — $e');
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

    loggerPrint('SubsonicProvider: active account is $_activeId');
    _setState(AuthState.authenticated);
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
        knownServers.add(server);
        loggerPrint(
          'SubsonicProvider: restored known server ${server.baseUrl}',
        );
      }
    } catch (e) {
      loggerPrint('SubsonicProvider: failed to restore known servers — $e');
      await _storage.delete(key: _keyKnownServers);
    }
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
  }

  void _setState(AuthState state) {
    _authState = state;
    notifyListeners();
  }
}

class SubsonicServer {
  final String name;
  final String baseUrl;
  bool canConnect = false;

  SubsonicServer({
    required this.baseUrl,
    required this.name,
    this.canConnect = false,
  });

  bool get isLocal => baseUrl.contains('localhost') || baseUrl.contains('100');

  Future<bool> tryConnect() async {
    // just do a simple get check to see if the server is reachable & we get an error response (since we don't have credentials yet)
    final sub = Subsonic(
      baseUrl: baseUrl,
      username: 'dummy',
      password: 'dummy',
    );

    // ping should fail with a catch of (e), but should expel starting with:
    // Subsonic API error

    print(
      "trying to connect to $baseUrl with dummy credentials to test connectivity",
    );

    try {
      print("pinging $baseUrl...");
      final res = await sub.ping();

      print(
        "ping response from $baseUrl: success=${res.success}, error=${res.errorMessage}",
      );

      if (res.success) {
        loggerPrint(
          'SubsonicServer: unexpected successful ping to $baseUrl with dummy credentials',
        );
      }

      if (res.errorMessage != null &&
          res.errorMessage!.contains('Subsonic API error')) {
        loggerPrint(
          'SubsonicServer: received expected API error from $baseUrl, server is reachable',
        );
        canConnect = true;
        return true; // server is reachable and responded with an API error, which is expected
      } else if (res.errorMessage != null) {
        loggerPrint(
          'SubsonicServer: received unexpected error from $baseUrl — ${res.errorMessage}',
        );
        canConnect = false;
        return false; // server is reachable but responded with an unexpected error
      }
      
      return true; // ping succeeded, server is reachable (but we don't expect this since credentials are wrong)
    } catch (e) {
      final error = e.toString();
      if (error.contains('Subsonic API error')) {
        canConnect = true;
        return true; // server is reachable and responded with an API error, which is expected
      } else {
        loggerPrint(
          'SubsonicServer: connection test failed for $baseUrl — $error',
        );
        canConnect = false;
        return false; // some other error occurred, server might not be reachable
      }
    }
  }
}
