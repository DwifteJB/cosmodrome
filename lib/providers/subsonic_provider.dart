import 'dart:convert';

import 'package:cosmodrome/helpers/subsonic-api-helper/api/basic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/user.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/providers/subsonic_account.dart';
import 'package:cosmodrome/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AuthState { initial, loading, authenticated, unauthenticated }

const _keyAccounts = 'subsonic_accounts';
const _keyActiveId = 'subsonic_active_id';

class SubsonicProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  AuthState _authState = AuthState.initial;
  final List<SubsonicAccount> _accounts = [];
  String? _activeId;
  String? _errorMessage;

  AuthState get authState => _authState;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _authState == AuthState.authenticated;

  List<SubsonicAccount> get accounts => List.unmodifiable(_accounts);

  SubsonicAccount? get activeAccount =>
      _activeId == null ? null : _accounts.where((a) => a.id == _activeId).firstOrNull;

  /// The current subsonic istance for the active account. Will throw if not authenticated.
  Subsonic get subsonic {
    assert(activeAccount != null, 'SubsonicProvider: no active account');
    return activeAccount!.subsonic;
  }

  /// Attempts to restore accounts and active session from storage.
  /// For ALL accounts.
  Future<void> tryRestoreSession() async {
    _setState(AuthState.loading);

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

  /// Adds a new account and makes it active. If an account with the same id
  /// already exists, it will be replaced. Returns an error message on failure.
  Future<String?> addAccount({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    _errorMessage = null;
    notifyListeners();

    final sub = Subsonic(baseUrl: baseUrl, username: username, password: password);

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

  /// Removes an account by id. If it was the active account, switches to
  /// the next available one (or sets unauthenticated if none remain).
  Future<void> removeAccount(String id) async {
    _accounts.removeWhere((a) => a.id == id);
    loggerPrint('SubsonicProvider: removed account $id');

    if (_activeId == id) {
      _activeId = _accounts.firstOrNull?.id;
    }

    await _persist();
    _setState(_accounts.isEmpty ? AuthState.unauthenticated : AuthState.authenticated);
  }

  /// Switches the active account.
  void switchAccount(String id) {
    assert(_accounts.any((a) => a.id == id), 'switchAccount: unknown id $id');
    _activeId = id;
    loggerPrint('SubsonicProvider: switched to $id');
    _storage.write(key: _keyActiveId, value: id);
    notifyListeners();
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

  // saves accounts to storage! saving!
  Future<void> _persist() async {
    final json = jsonEncode(_accounts.map((a) => a.toJson()).toList());
    await _storage.write(key: _keyAccounts, value: json);
    if (_activeId != null) {
      await _storage.write(key: _keyActiveId, value: _activeId);
    }
  }

  void _setState(AuthState state) {
    _authState = state;
    notifyListeners();
  }
}
