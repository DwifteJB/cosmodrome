import 'dart:convert';

import 'package:cosmodrome/helpers/subsonic-api-helper/errors.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic_auth.dart';
import 'package:cosmodrome/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _apiVersion = '1.16.1';
const _clientName = 'cosmodrome';

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

  Future<Map<String, dynamic>> apiRequest(
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
      'f': 'json',
      ...params,
    };

    final uri = Uri.http(baseUrl, '/rest/$endpoint', query);
    loggerPrint('Making API request to $uri');
    final response = await http.get(uri);

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

    return root;
  }
}
