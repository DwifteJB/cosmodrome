import 'dart:convert';

import 'package:cosmodrome/services/local_storage_backend.dart';
import 'package:cosmodrome/services/local_storage_backend_factory.dart';
import 'package:cosmodrome/utils/logger.dart';

class LocalStorageService {
  static final LocalStorageBackend _backend = createLocalStorageBackend();

  static Future<int> accountStorageBytes(String accountId) =>
      _backend.accountStorageBytes(accountId);

  static Future<bool> coverImageExists(String coverRef) =>
      _backend.coverImageExists(coverRef);

  static String coverImagePath(
    String accountId,
    String imageId,
    String extension,
  ) => _backend.coverImageRef(accountId, imageId, extension);

  static Future<Uri?> coverImageUriForRef(String coverRef) =>
      _backend.coverImageUri(coverRef);

  static Future<void> deleteCoverImage(String coverRef) =>
      _backend.deleteCoverImage(coverRef);

  static Future<void> deleteSong(String songRef) =>
      _backend.deleteSong(songRef);

  static Future<void> ensureDirs(String accountId) =>
      _backend.ensureDirs(accountId);

  static Future<void> init() async {
    await _backend.init();
  }

  static String metaPath(String accountId, String key) =>
      _backend.metaRef(accountId, key);

  static Future<Uri?> playableUriForSongRef(String songRef) =>
      _backend.playableUri(songRef);

  static Future<Map<String, dynamic>?> readJsonMeta(
    String accountId,
    String key,
  ) async {
    final raw = await _backend.readMeta(metaPath(accountId, key));
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> releasePlayableUri(Uri uri) =>
      _backend.releasePlayableUri(uri);

  static Future<bool> songExists(String songRef) =>
      _backend.songExists(songRef);

  static String songPath(String accountId, String songId, String suffix) =>
      _backend.songRef(accountId, songId, suffix);

  static Future<void> writeCoverImageBytes(String coverRef, List<int> bytes) =>
      _backend.writeCoverImageBytes(coverRef, bytes);

  static Future<void> writeJsonMeta(
    String accountId,
    String key,
    Map<String, dynamic> data,
  ) => _backend.writeMeta(metaPath(accountId, key), jsonEncode(data));

  static Future<void> writeSongBytes(String songRef, List<int> bytes) =>
      _backend.writeSongBytes(songRef, bytes);
}
