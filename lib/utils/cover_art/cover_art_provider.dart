import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cosmodrome/services/local_storage_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

ImageProvider<Object> coverArtProvider(String url) => CoverArtImage(url);

@immutable
class CoverArtImage extends ImageProvider<String> {
  const CoverArtImage(this.url);

  final String url;

  @override
  Future<String> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<String>(_cacheKey(url));

  @override
  ImageStreamCompleter loadImage(String key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: _loadCodec(key, decode),
        scale: 1.0,
        debugLabel: key,
      );

  Future<ui.Codec> _loadCodec(String key, ImageDecoderCallback decode) async {
    final bytes = await _loadBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  Future<Uint8List> _loadBytes() async {
    final uri = Uri.tryParse(url);
    final id = uri?.queryParameters['id'];
    if (uri == null || id == null) return _download();

    final accountId = '${uri.queryParameters['u'] ?? ''}@${uri.authority}';
    final hash = md5.convert(utf8.encode(_cacheKey(url))).toString();
    final ref = LocalStorageService.coverImagePath(accountId, hash, 'img');

    final cached = await _readDisk(ref);
    if (cached != null) return cached;

    final bytes = await _download();
    unawaited(_writeDisk(accountId, ref, bytes));
    return bytes;
  }

  Future<Uint8List> _download() async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw NetworkImageLoadException(
        statusCode: response.statusCode,
        uri: Uri.parse(url),
      );
    }
    return response.bodyBytes;
  }

  Future<Uint8List?> _readDisk(String ref) async {
    try {
      final bytes = await LocalStorageService.readCoverImageBytes(ref);
      if (bytes == null || bytes.isEmpty) return null;
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDisk(String accountId, String ref, Uint8List bytes) async {
    try {
      await LocalStorageService.ensureDirs(accountId);
      await LocalStorageService.writeCoverImageBytes(ref, bytes);
    } catch (_) {}
  }

  @override
  bool operator ==(Object other) =>
      other is CoverArtImage && _cacheKey(other.url) == _cacheKey(url);

  @override
  int get hashCode => _cacheKey(url).hashCode;
}

String _cacheKey(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final id = uri.queryParameters['id'] ?? '';
  final size = uri.queryParameters['size'] ?? '';
  final user = uri.queryParameters['u'] ?? '';
  return '$user@${uri.authority}|$id|$size';
}
