import 'dart:io';

import 'package:cosmodrome/services/local_storage_backend.dart';
import 'package:path_provider/path_provider.dart';

class IoLocalStorageBackend implements LocalStorageBackend {
  String? _basePath;

  String get _base {
    assert(_basePath != null, 'LocalStorageService.init() not called');
    return _basePath!;
  }

  static const _accountSubdirs = ['songs', 'cached-images', 'cache'];

  @override
  Future<int> accountStorageBytes(String accountId) async {
    var total = 0;
    for (final subdir in _accountSubdirs) {
      final dir = Directory('$_base/$accountId/$subdir');
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
  Future<List<int>?> readCoverImageBytes(String coverRef) async {
    final file = File(coverRef);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> deleteAccountCache(String accountId) {
    // just delete the whole cache dir, it's simpler and should be fast enough
    final dir = Directory('$_base/$accountId');
    if (dir.existsSync()) {
      return dir.delete(recursive: true);
    }

    // create empty dir to avoid issues with other methods assuming it exists
    return dir.create(recursive: true);
  }

  @override
  Future<void> deleteCoverImage(String coverRef) => _deleteIfExists(coverRef);

  @override
  Future<void> deleteSong(String songRef) => _deleteIfExists(songRef);

  Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> ensureDirs(String accountId) async {
    for (final subdir in _accountSubdirs) {
      await Directory('$_base/$accountId/$subdir').create(recursive: true);
    }
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
  Future<void> writeCoverImageBytes(String coverRef, List<int> bytes) =>
      File(coverRef).writeAsBytes(bytes, flush: true);

  @override
  Future<void> writeMeta(String metaRef, String content) =>
      File(metaRef).writeAsString(content);

  @override
  Future<void> writeSongBytes(String songRef, List<int> bytes) =>
      File(songRef).writeAsBytes(bytes, flush: true);
}
