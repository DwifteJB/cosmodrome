// provider to properly handle carplay / android auto art

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class CarArt {
  static Directory? _dir;
  static final Map<String, Future<String?>> _covers = {};
  static final Map<int, Future<String?>> _icons = {};

  static Future<String?> cover(String? url) {
    if (url == null || url.isEmpty) return Future.value();
    final uri = Uri.tryParse(url);
    if (uri == null) return Future.value();
    final key = md5
        .convert(
          utf8.encode(
            '${uri.queryParameters['u']}@${uri.authority}|'
            '${uri.queryParameters['id']}|${uri.queryParameters['size']}',
          ),
        )
        .toString();
    return _covers[key] ??= _loadCover(uri, key).then((path) {
      if (path == null) _covers.remove(key);
      return path;
    });
  }

  static Future<String?> icon(IconData icon) =>
      _icons[icon.codePoint] ??= _renderIcon(icon);

  static Future<Directory> _directory() async => _dir ??= await Directory(
    '${(await getTemporaryDirectory()).path}/car_art',
  ).create(recursive: true);

  static Future<String?> _loadCover(Uri uri, String key) async {
    try {
      final file = File('${(await _directory()).path}/$key.img');
      if (!await file.exists() || await file.length() == 0) {
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 4));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          return null;
        }
        await file.writeAsBytes(response.bodyBytes, flush: true);
      }
      return 'file://${file.path}';
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _renderIcon(IconData icon) async {
    try {
      const size = 96.0;
      final file = File(
        '${(await _directory()).path}/icon_${icon.codePoint}.png',
      );
      final recorder = ui.PictureRecorder();
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: 76,
            color: const Color(0xFFFFFFFF),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        Canvas(recorder),
        Offset((size - painter.width) / 2, (size - painter.height) / 2),
      );
      final image = await recorder
          .endRecording()
          .toImage(size.toInt(), size.toInt())
          .timeout(const Duration(seconds: 2));
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return null;
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      return 'file://${file.path}';
    } catch (_) {
      _icons.remove(icon.codePoint);
      return null;
    }
  }
}
