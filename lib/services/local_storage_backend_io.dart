import 'dart:io';

import 'package:cosmodrome/services/local_storage_backend.dart';
import 'package:path_provider/path_provider.dart';

class IoLocalStorageBackend implements LocalStorageBackend {
  String? _basePath;

  String get _base {
    assert(_basePath != null, 'LocalStorageService.init() not called');
    return _basePath!;
  }

  @override
  Future<int> accountStorageBytes(String accountId) async {
    var total = 0;
    final roots = [
      Directory('$_base/$accountId/songs'),
      Directory('$_base/$accountId/cached-images'),
    ];
    for (final dir in roots) {
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) total += await entity.length();
      }
    }
    return total;
  }

  @override
  Future<bool> coverImageExists(String coverRef) => File(coverRef).exists();

  @override
  String coverImageRef(String accountId, String imageId, String extension) =>
      '$_base/$accountId/cached-images/$imageId.$extension';

  @override
  Future<Uri?> coverImageUri(String coverRef) async {
    if (!await coverImageExists(coverRef)) return null;
    return Uri.file(coverRef);
  }

  @override
  Future<void> deleteCoverImage(String coverRef) async {
    final file = File(coverRef);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> deleteSong(String songRef) async {
    final file = File(songRef);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> ensureDirs(String accountId) async {
    await Directory('$_base/$accountId/songs').create(recursive: true);
    await Directory('$_base/$accountId/cache').create(recursive: true);
    await Directory('$_base/$accountId/cached-images').create(recursive: true);
  }

  @override
  Future<void> init() async {

    // if linux use ~/.local/share/me.rmfosho.me (APP INSTALL) instead of documents directory
    if (Platform.isLinux) {
      // find current install path
      // this is fine if cache gets cleared every update (something we want acc)
      final installDir = Directory.current;
      _basePath = '${installDir.path}/cache';
      return;
    }


    final dir = await getApplicationDocumentsDirectory();
    _basePath = '${dir.path}/cosmodrome';
  }

  @override
  String metaRef(String accountId, String key) =>
      '$_base/$accountId/cache/$key.json';

  @override
  Future<Uri?> playableUri(String songRef) async {
    if (!await songExists(songRef)) return null;
    return Uri.file(songRef);
  }

  @override
  Future<String?> readMeta(String metaRef) async {
    final file = File(metaRef);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> releasePlayableUri(Uri uri) async {}

  @override
  Future<bool> songExists(String songRef) => File(songRef).exists();

  @override
  String songRef(String accountId, String songId, String suffix) =>
      '$_base/$accountId/songs/$songId.$suffix';

  @override
  Future<void> writeCoverImageBytes(String coverRef, List<int> bytes) async {
    final file = File(coverRef);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> writeMeta(String metaRef, String content) async {
    final file = File(metaRef);
    await file.writeAsString(content);
  }

  @override
  Future<void> writeSongBytes(String songRef, List<int> bytes) async {
    final file = File(songRef);
    await file.writeAsBytes(bytes, flush: true);
  }
}
