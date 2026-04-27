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
  late final SubsonicAuth auth;
  int timeoutSeconds;

  SubsonicLoginMethod loginMethod = SubsonicLoginMethod.undetermined;

  Subsonic({
    required String baseUrl,
    required String username,
    required String password,
    this.timeoutSeconds = 15,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'^https?://'), '') {
    auth = SubsonicAuth(username: username, password: password);
  
  }

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

    final query = {
      ...getLoginParams(loginMethod),
      'v': _apiVersion,
      'c': _clientName,
      'p': auth.password,
      'f': 'json',
      ...params,
    };

    final uri = Uri.http(baseUrl, '/rest/$endpoint', query);
    final response = await http
        .get(uri)
        .timeout(
          Duration(seconds: timeoutSeconds ?? this.timeoutSeconds),
          onTimeout: () {
            loggerPrint(
              'API request to $endpoint timed out after ${timeoutSeconds ?? this.timeoutSeconds} seconds',
            );
            throw Exception(
              'API request to $endpoint timed out after ${timeoutSeconds ?? this.timeoutSeconds} seconds',
            );
          },
        );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    final root = body['subsonic-response'] as Map<String, dynamic>;

    // if no subsonic-response or status, something is very wrong, therefore show HTTP error

    if (root['status'] == null || body['subsonic-response'] == null) {
      loggerPrint(
        'HTTP error ${response.statusCode} from $endpoint: ${response.body}',
      );
      throw Exception('HTTP ${response.statusCode} from $endpoint');
    }

    if (root['status'] == 'failed') {
      final err = root['error'] as Map<String, dynamic>;
      final SubsonicError error = getErrorFromCode(
        (err['code'] as num).toInt(),
      );
      // ignore if ping.view / ping
      if (!endpoint.startsWith("ping")) {
        loggerPrint(
          'Subsonic API error from $endpoint: $error (${err['message']})',
        );
      }
      // throw string of useful error
      final usefulError = errorToSensibleNames(error);
      throw Exception(
        'Subsonic API error from $endpoint: $usefulError (${err['message']})',
      );
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
    final query = {
      ...getLoginParams(loginMethod),
      'v': _apiVersion,
      'c': _clientName,
      ...params,
    };

    final uri = Uri.http(baseUrl, '/rest/$endpoint', query);
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
    // try token first
    try {
      var query = getLoginParams(SubsonicLoginMethod.token);

      final uri = Uri.http(baseUrl, '/rest/ping.view', query);
      loggerPrint('Determining login method: trying token login at $uri');
      final response = await http
          .get(uri)
          .timeout(
            Duration(seconds: timeoutSeconds),
            onTimeout: () {
              loggerPrint(
                'Token login attempt timed out after $timeoutSeconds seconds',
              );
              throw Exception(
                'Token login attempt timed out after $timeoutSeconds seconds',
              );
            },
          );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final root = body['subsonic-response'] as Map<String, dynamic>;
        if (root['status'] == 'ok') {
          loginMethod = SubsonicLoginMethod.token;
          return loginMethod;
        } else {
          loggerPrint(
            'Token login attempt failed with status ${root['status']}',
          );
        }
      }
    } catch (e) {
      loggerPrint('Token login failed: $e');
    }

    // try password login
    try {
      final query = getLoginParams(SubsonicLoginMethod.password);

      final uri = Uri.http(baseUrl, '/rest/ping.view', query);
      loggerPrint('Determining login method: trying password login at $uri');
      final response = await http
          .get(uri)
          .timeout(
            Duration(seconds: timeoutSeconds),
            onTimeout: () {
              loggerPrint(
                'Password login attempt timed out after $timeoutSeconds seconds',
              );
              throw Exception(
                'Password login attempt timed out after $timeoutSeconds seconds',
              );
            },
          );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final root = body['subsonic-response'] as Map<String, dynamic>;
        if (root['status'] == 'ok') {
          loginMethod = SubsonicLoginMethod.password;
          return loginMethod;
        }
      }
    } catch (e) {
      loggerPrint('Password login failed: $e');
    }

    // try encrypted password login
    // (note: subsonic doesn't actually support this, some forks tho do)
    /*
if strings.HasPrefix(p, "enc:") {
		decoded, err := hex.DecodeString(p[4:])
		if err != nil {
			return nil, 40, "Wrong username or password."
		}
		password = string(decoded)
	}
    */

    try {
      final query = getLoginParams(SubsonicLoginMethod.encryptedPassword);

      final uri = Uri.http(baseUrl, '/rest/ping.view', query);
      loggerPrint(
        'Determining login method: trying encrypted password login at $uri',
      );
      final response = await http
          .get(uri)
          .timeout(
            Duration(seconds: timeoutSeconds),
            onTimeout: () {
              loggerPrint(
                'Encrypted password login attempt timed out after $timeoutSeconds seconds',
              );
              throw Exception(
                'Encrypted password login attempt timed out after $timeoutSeconds seconds',
              );
            },
          );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final root = body['subsonic-response'] as Map<String, dynamic>;
        if (root['status'] == 'ok') {
          loginMethod = SubsonicLoginMethod.encryptedPassword;
          return loginMethod;
        }
      }
    } catch (e) {
      loggerPrint('Encrypted password login failed: $e');
    }

    return SubsonicLoginMethod.undetermined;
  }

  Map<String, String> getLoginParams(SubsonicLoginMethod loginMethod) {
    // get login params based on login method
    switch (loginMethod) {
      case SubsonicLoginMethod.password:
        return {
          'u': auth.username,
          'p': auth.password,
          'v': _apiVersion,
          'c': _clientName,
          'f': 'json',
        };
      case SubsonicLoginMethod.encryptedPassword:
        var encryptedPassword = 'enc:';
        // encode string with hex
        final bytes = utf8.encode(auth.password);
        final hexString = bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        encryptedPassword += hexString;
        return {
          'u': auth.username,
          'p': encryptedPassword,
          'v': _apiVersion,
          'c': _clientName,
          'f': 'json',
        };
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
    
    final query = <String, dynamic>{
      ...getLoginParams(loginMethod),
      'v': _apiVersion,
      'c': _clientName,
      'f': 'json',
      ...params,
    };

    final uri = Uri.http(baseUrl, '/rest/$endpoint', query);

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
    if (root['status'] == 'failed') {
      final err = root['error'] as Map<String, dynamic>;
      final SubsonicError error = getErrorFromCode(
        (err['code'] as num).toInt(),
      );
      throw Exception(
        'Subsonic API error from $endpoint: ${errorToSensibleNames(error)}',
      );
    }
    return root;
  }

  /// Builds a stream URL without making an HTTP request.
  /// Safe to use directly in just_audio's setUrl().
  String streamUrl(String id) {

    return Uri.http(baseUrl, '/rest/stream', {
      'id': id,
      ...getLoginParams(loginMethod),
      'v': _apiVersion,
      'c': _clientName,
    }).toString();
  }
}

enum SubsonicLoginMethod { password, encryptedPassword, token, undetermined }
