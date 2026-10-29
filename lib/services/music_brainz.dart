import 'dart:convert';

import 'package:http/http.dart' as http;

final musicBrainz = MusicBrainzClient();

const musicApiHeaders = {
  'User-Agent': 'Cosmodrome/1.0 (cosmodrome-app)',
  'Accept': 'application/json',
};

const _timeout = Duration(seconds: 8);

Future<Map<String, dynamic>?> getMusicJson(Uri uri) async =>
    (await _getMusicJson(uri)).$1;

Future<(Map<String, dynamic>?, int?)> _getMusicJson(Uri uri) async {
  try {
    final response = await http
        .get(uri, headers: musicApiHeaders)
        .timeout(_timeout);
    if (response.statusCode != 200) return (null, response.statusCode);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    return (body is Map<String, dynamic> ? body : null, 200);
  } catch (_) {
    return (null, null);
  }
}

class MusicBrainzClient {
  static const _gap = Duration(milliseconds: 1100);

  Future<void> _queue = Future.value();
  DateTime _lastCall = DateTime.fromMillisecondsSinceEpoch(0);

  Future<Map<String, dynamic>?> get(String path, Map<String, String> params) {
    final run = _queue.then((_) async {
      final wait = _gap - DateTime.now().difference(_lastCall);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      final uri = Uri.https('musicbrainz.org', '/ws/2/$path', {
        ...params,
        'fmt': 'json',
      });
      try {
        final (body, status) = await _getMusicJson(uri);
        if (status != 503) return body;
        await Future<void>.delayed(_gap * 2);
        return (await _getMusicJson(uri)).$1;
      } finally {
        _lastCall = DateTime.now();
      }
    });
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }
}
