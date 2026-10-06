import 'dart:convert';

import 'package:cosmodrome/helpers/subsonic-api-helper/errors.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic_auth.dart';
import 'package:cosmodrome/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _apiVersion = '1.16.1';
const _cacheTTL = Duration(seconds: 60 * 5); // 5 minutes
const _clientName = 'cosmodrome';

final excludedPingEndpoints = {'ping.view', 'getUser'};

// global cache - keyed as "baseUrl|username|endpoint?params"
final Map<String, ApiResultCache<Map<String, dynamic>>> _apiCache = {};

class ApiResultCache<T> {
  final T data;
  final DateTime timestamp;

  ApiResultCache(this.data) : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp) > _cacheTTL;
}

class Subsonic {
  final String baseUrl; // includes port e.g. localhost:4455
  final SubsonicAuth auth;
  int timeoutSeconds;

  SubsonicLoginMethod loginMethod = SubsonicLoginMethod.undetermined;

  Subsonic({
    required String baseUrl,
    required String username,
    required String password,
    this.timeoutSeconds = 15,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'^https?://'), ''),
       auth = SubsonicAuth(username: username, password: password);

  Future<Map<String, dynamic>> apiRequest(
    String endpoint, {
    Map<String, String> params = const {},
    int? timeoutSeconds,
    bool forceRefresh = false,
  }) async {
    await determineLoginMethod();
    // check to see if theres a cached result that isn't expired
    final cacheKey =
        '$baseUrl|${auth.username}|$endpoint?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final cached = _apiCache[cacheKey];

    if (!forceRefresh &&
        cached != null &&
        !cached.isExpired &&
        !excludedPingEndpoints.contains(endpoint)) {
      loggerPrint('Cache hit for $cacheKey');
      return cached.data;
    }

    // cleanup old cache entries
    _apiCache.removeWhere((key, value) => value.isExpired);

    final uri = restUri(endpoint, {'f': 'json', ...params});
    final timeout = timeoutSeconds ?? this.timeoutSeconds;
    final response = await http
        .get(uri)
        .timeout(
          Duration(seconds: timeout),
          onTimeout: () {
            loggerPrint(
              'API request to $endpoint timed out after $timeout seconds',
            );
            throw Exception(
              'API request to $endpoint timed out after $timeout seconds',
            );
          },
        );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    final root = body['subsonic-response'] as Map<String, dynamic>;

    // if no status, something is very wrong, therefore show HTTP error
    if (root['status'] == null) {
      loggerPrint(
        'HTTP error ${response.statusCode} from $endpoint: ${response.body}',
      );
      throw Exception('HTTP ${response.statusCode} from $endpoint');
    }

    if (root['status'] == 'failed') {
      final error = _apiException(endpoint, root);
      // ignore if ping.view / ping
      if (!endpoint.startsWith("ping")) loggerPrint(error.toString());
      throw error;
    }

    loggerPrint('API request to $endpoint successful: ${root['status']}');

    // keep ping/getUser uncached so connectivity/auth checks stay fresh.
    if (!excludedPingEndpoints.contains(endpoint)) {
      _apiCache[cacheKey] = ApiResultCache(root);
    }

    return root;
  }

  // since avatar uses binary, this is required for it
  Future<Uint8List> bytesApiRequest(
    String endpoint, {
    Map<String, String> params = const {},
  }) async {
    await determineLoginMethod();
    final uri = restUri(endpoint, params);
    loggerPrint('Making bytes API request to $uri');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      loggerPrint(
        'HTTP error ${response.statusCode} from $endpoint: ${response.body}',
      );
      throw Exception('HTTP ${response.statusCode} from $endpoint');
    }

    return response.bodyBytes;
  }

  void clearCache() {
    _apiCache.clear();
  }

  void clearCacheStartingWith(String endpoint) {
    final prefix = '$baseUrl|${auth.username}|$endpoint';
    _apiCache.removeWhere((key, value) => key.startsWith(prefix));
  }

  Future<SubsonicLoginMethod> determineLoginMethod() async {
    if (auth.password == 'dummy' && auth.username == 'dummy') {
      loggerPrint(
        'Using dummy credentials, skipping login method determination',
      );
      loginMethod = SubsonicLoginMethod.token;
      return loginMethod;
    }

    if (loginMethod != SubsonicLoginMethod.undetermined) {
      return loginMethod;
    }

    // try token first, then password, then encrypted password
    // (note: subsonic doesn't actually support encrypted passwords, some forks tho do)
    /*
if strings.HasPrefix(p, "enc:") {
		decoded, err := hex.DecodeString(p[4:])
		if err != nil {
			return nil, 40, "Wrong username or password."
		}
		password = string(decoded)
	}
    */
    const attempts = [
      (SubsonicLoginMethod.token, 'token'),
      (SubsonicLoginMethod.password, 'password'),
      (SubsonicLoginMethod.encryptedPassword, 'encrypted password'),
    ];
    for (final (method, label) in attempts) {
      if (await _pingWithLoginMethod(method, label)) {
        loginMethod = method;
        return loginMethod;
      }
    }

    return SubsonicLoginMethod.undetermined;
  }

  Future<bool> _pingWithLoginMethod(
    SubsonicLoginMethod method,
    String label,
  ) async {
    try {
      final uri = Uri.http(baseUrl, '/rest/ping.view', getLoginParams(method));
      loggerPrint('Determining login method: trying $label login at $uri');
      final response = await http
          .get(uri)
          .timeout(
            Duration(seconds: timeoutSeconds),
            onTimeout: () {
              loggerPrint(
                '$label login attempt timed out after $timeoutSeconds seconds',
              );
              throw Exception(
                '$label login attempt timed out after $timeoutSeconds seconds',
              );
            },
          );

      if (response.statusCode != 200) return false;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final root = body['subsonic-response'] as Map<String, dynamic>;
      if (root['status'] == 'ok') return true;
      loggerPrint('$label login attempt failed with status ${root['status']}');
    } catch (e) {
      loggerPrint('$label login failed: $e');
    }
    return false;
  }

  Map<String, String> getLoginParams(SubsonicLoginMethod loginMethod) {
    // get login params based on login method
    Map<String, String> passwordParams(String password) => {
      'u': auth.username,
      'p': password,
      'v': _apiVersion,
      'c': _clientName,
      'f': 'json',
    };

    switch (loginMethod) {
      case SubsonicLoginMethod.password:
        return passwordParams(auth.password);
      case SubsonicLoginMethod.encryptedPassword:
        // encode string with hex
        final hexString = utf8
            .encode(auth.password)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        return passwordParams('enc:$hexString');
      // assume default is TOKEN, since it usually is
      default:
        final tok = auth.generateToken();
        return {'u': auth.username, 't': tok.token, 's': tok.salt, 'f': 'json'};
    }
  }

  Future<Map<String, dynamic>> multiParamRequest(
    String endpoint, {
    Map<String, dynamic> params = const {},
  }) async {
    await determineLoginMethod();
    final uri = restUri(endpoint, {'f': 'json', ...params});

    loggerPrint('Making multi-param API request to $uri');

    final response = await http
        .get(uri)
        .timeout(
          Duration(seconds: timeoutSeconds),
          onTimeout: () {
            throw Exception('API request to $endpoint timed out');
          },
        );
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} from $endpoint');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final root = body['subsonic-response'] as Map<String, dynamic>;
    if (root['status'] == 'failed') throw _apiException(endpoint, root);
    return root;
  }

  SubsonicApiException _apiException(
    String endpoint,
    Map<String, dynamic> root,
  ) {
    final err = root['error'] as Map<String, dynamic>;
    final exception = SubsonicApiException(
      endpoint,
      (err['code'] as num).toInt(),
      err['message'] as String?,
    );
    // the server stopped accepting our login method (e.g. token auth was
    // disabled), so probe again on the next request
    if (exception.error == SubsonicError.tokenAuthNotSupported) {
      loginMethod = SubsonicLoginMethod.undetermined;
    }
    return exception;
  }

  String streamUrl(String id) => restUri('stream', {'id': id}).toString();

  Future<void> warmStream(String id) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(streamUrl(id)))
        ..headers['Range'] = 'bytes=0-0'
        ..maxRedirects = 100;
      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 5));
      await response.stream.listen((_) {}, cancelOnError: true).cancel();
    } catch (_) {
    } finally {
      client.close();
    }
  }

  /// Builds an authenticated `/rest/[endpoint]` uri using the current login method.
  Uri restUri(String endpoint, [Map<String, dynamic> params = const {}]) =>
      Uri.http(baseUrl, '/rest/$endpoint', {
        ...getLoginParams(loginMethod),
        'v': _apiVersion,
        'c': _clientName,
        ...params,
      });
}

enum SubsonicLoginMethod { password, encryptedPassword, token, undetermined }
