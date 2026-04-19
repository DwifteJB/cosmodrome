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
    final dir = Directory('$_base/$accountId/songs');
    if (!await dir.exists()) return 0;

    var total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
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
  }

  @override
  Future<void> init() async {
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
  String songRef(String accountId, String songId, String suffix) =>
      '$_base/$accountId/songs/$songId.$suffix';

  @override
  Future<bool> songExists(String songRef) => File(songRef).exists();

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
