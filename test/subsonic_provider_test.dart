import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

Subsonic subsonic(String baseUrl) =>
    Subsonic(baseUrl: baseUrl, username: 'tester', password: 'pw');

void main() {
  group('server urls', () {
    test('https is kept', () {
      final uri = Uri.parse(
        subsonic('https://music.example.com').streamUrl('1'),
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'music.example.com');
      expect(uri.port, 443);
      expect(uri.path, '/rest/stream');
      expect(uri.queryParameters['id'], '1');
    });

    test('http and bare hosts use http', () {
      expect(
        subsonic('http://localhost:4533').restUri('ping.view').scheme,
        'http',
      );
      final bare = subsonic('localhost:4533').restUri('ping.view');
      expect(bare.scheme, 'http');
      expect(bare.port, 4533);
    });

    test('scheme does not change the account keys', () {
      expect(
        subsonic('https://music.example.com').baseUrl,
        'music.example.com',
      );
      expect(subsonic('HTTPS://music.example.com').scheme, 'https');
    });
  });

  group('restoring a session', () {
    late ServerSocket silent;
    late HttpServer live;
    final held = <Socket>[];

    setUp(() async {
      // accepts connections but never answers
      silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      silent.listen(held.add);

      live = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      live.listen((request) {
        request.response
          ..write(
            jsonEncode({
              'subsonic-response': {
                'status': 'failed',
                'error': {'code': 40, 'message': 'wrong username or password'},
              },
            }),
          )
          ..close();
      });
    });

    tearDown(() async {
      for (final socket in held) {
        socket.destroy();
      }
      held.clear();
      await silent.close();
      await live.close(force: true);
    });

    test('does not wait on servers that never answer', () async {
      final silentUrl = 'http://127.0.0.1:${silent.port}';
      final liveUrl = 'http://127.0.0.1:${live.port}';
      FlutterSecureStorage.setMockInitialValues({
        'subsonic_known_servers': jsonEncode([
          {'baseUrl': silentUrl, 'name': 'silent'},
          {'baseUrl': '$silentUrl/again', 'name': 'silent too'},
          {'baseUrl': liveUrl, 'name': 'live'},
        ]),
      });

      final provider = SubsonicProvider();
      final liveSeen = Completer<void>();
      provider.addListener(() {
        final server = provider.knownServers
            .where((s) => s.baseUrl == liveUrl)
            .firstOrNull;
        if (server?.canConnect == true && !liveSeen.isCompleted) {
          liveSeen.complete();
        }
      });

      final watch = Stopwatch()..start();
      await provider.tryRestoreSession();
      expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
      expect(provider.knownServers.map((s) => s.name), [
        'silent',
        'silent too',
        'live',
      ]);

      // the live server shows up while the silent ones are still pending
      await liveSeen.future.timeout(const Duration(seconds: 2));
      expect(provider.knownServers.first.canConnect, isFalse);
    });
  });
}
