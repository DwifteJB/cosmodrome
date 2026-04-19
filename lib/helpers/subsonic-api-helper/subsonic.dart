import 'dart:convert';

import 'package:cosmodrome/helpers/subsonic-api-helper/errors.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic_auth.dart';
import 'package:cosmodrome/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _apiVersion = '1.16.1';
const _cacheTTL = Duration(seconds: 60 * 5); // 5 minutes
const _clientName = 'cosmodrome';

final excludedPingEndpoints = {'ping.view', 'getUser'};

// global cache — keyed as "baseUrl|username|endpoint?params"
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

  Subsonic({
    required String baseUrl,
    required String username,
    required String password,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'^https?://'), '') {
    auth = SubsonicAuth(username: username, password: password);
  }

  Future<Map<String, dynamic>> apiRequest(
    String endpoint, {
    Map<String, String> params = const {},
    int timeoutSeconds = 5,
  }) async {
    // check to see if theres a cached result that isn't expired
    final cacheKey =
        '$baseUrl|${auth.username}|$endpoint?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final cached = _apiCache[cacheKey];

    if (cached != null &&
        !cached.isExpired &&
        !excludedPingEndpoints.contains(endpoint)) {
      loggerPrint('Cache hit for $cacheKey');
      return cached.data;
    }

    // cleanup old cache entries
    _apiCache.removeWhere((key, value) => value.isExpired);

    final tok = auth.generateToken();
    final query = {
      'u': auth.username,
      't': tok.token,
      's': tok.salt,
      'v': _apiVersion,
      'c': _clientName,
      'f': 'json',
      ...params,
    };

    final uri = Uri.http(baseUrl, '/rest/$endpoint', query);
    loggerPrint('Making API request to $uri');
    final response = await http
        .get(uri)
        .timeout(
          Duration(seconds: timeoutSeconds),
          onTimeout: () {
            loggerPrint(
              'API request to $endpoint timed out after $timeoutSeconds seconds',
            );
            throw Exception(
              'API request to $endpoint timed out after $timeoutSeconds seconds',
            );
          },
        );

    loggerPrint("made request!");

    if (response.statusCode != 200) {
      loggerPrint(
        'HTTP error ${response.statusCode} from $endpoint: ${response.body}',
      );
      throw Exception('HTTP ${response.statusCode} from $endpoint');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final root = body['subsonic-response'] as Map<String, dynamic>;

    if (root['status'] == 'failed') {
      final err = root['error'] as Map<String, dynamic>;
      final SubsonicError error = getErrorFromCode(
        (err['code'] as num).toInt(),
      );
      loggerPrint(
        'Subsonic API error from $endpoint: $error (${err['message']})',
      );
      // throw string of useful error
      final usefulError = errorToSensibleNames(error);
      throw Exception(
        'Subsonic API error from $endpoint: $usefulError (${err['message']})',
      );
    }

    loggerPrint('API request to $endpoint successful: ${root['status']}');

    // save to cache
    _apiCache[cacheKey] = ApiResultCache(root);

    return root;
  }

  // since avatar uses binary, this is required for it
  Future<Uint8List> bytesApiRequest(
    String endpoint, {
    Map<String, String> params = const {},
  }) async {
    final tok = auth.generateToken();
    final query = {
      'u': auth.username,
      't': tok.token,
      's': tok.salt,
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

  void clearCacheStartingWith(String endpoint) {
    final prefix = '$baseUrl|${auth.username}|$endpoint';
    _apiCache.removeWhere((key, value) => key.startsWith(prefix));
  }

  Future<Map<String, dynamic>> multiParamRequest(
    String endpoint, {
    Map<String, dynamic> params = const {},
    int timeoutSeconds = 5,
  }) async {
    final tok = auth.generateToken();
    final query = <String, dynamic>{
      'u': auth.username,
      't': tok.token,
      's': tok.salt,
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
    final tok = auth.generateToken();
    return Uri.http(baseUrl, '/rest/stream', {
      'id': id,
      'u': auth.username,
      't': tok.token,
      's': tok.salt,
      'v': _apiVersion,
      'c': _clientName,
    }).toString();
  }
}
