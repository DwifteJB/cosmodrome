import 'dart:io';
import 'dart:typed_data';

import 'package:cosmodrome/services/local_storage_backend.dart';
import 'package:path_provider/path_provider.dart';

class IoLocalStorageBackend implements LocalStorageBackend {
  String? _basePath;
  String? _downloadsPath;
  String? _musicPath;

  String get _base {
    assert(_basePath != null, 'LocalStorageService.init() not called');
    return _basePath!;
  }

  String get _downloads => _downloadsPath!;
  String get _music => _musicPath!;

  static const _accountSubdirs = ['cached-images', 'cache'];
  static const _downloadsFolder = 'Downloaded';

  @override
  String? get downloadsDirectory => _downloadsPath;

  @override
  String? get localMusicDirectory => _musicPath;

  @override
  Future<int> accountStorageBytes(String accountId) async {
    var total = 0;
    final dirs = [
      for (final subdir in _accountSubdirs) '$_base/$accountId/$subdir',
      _accountDownloads(accountId),
    ];
    for (final path in dirs) {
      final dir = Directory(path);
      if (!await dir.exists()) continue;

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) total += await entity.length();
      }
    }
    return total;
  }

  String _accountDownloads(String accountId) => '$_downloads/$accountId';

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
  Future<void> deleteAccountCache(String accountId) async {
    final downloads = Directory(_accountDownloads(accountId));
    if (await downloads.exists()) await downloads.delete(recursive: true);

    final dir = Directory('$_base/$accountId');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      return;
    }

    await dir.create(recursive: true);
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
    await Directory(_accountDownloads(accountId)).create(recursive: true);
  }


  @override
  Future<void> init() async {
    final docs = (await getApplicationDocumentsDirectory()).path;
    final legacyBase = Platform.isLinux
        ? '${Directory.current.path}/cache'
        : '$docs/cosmodrome';

    if (Platform.isIOS) {
      final support = await getApplicationSupportDirectory();
      _basePath = '${support.path}/cosmodrome';
      _downloadsPath = '$docs/$_downloadsFolder';
      _musicPath = docs;
    } else if (Platform.isLinux) {
      _basePath = legacyBase;
      _downloadsPath = '$legacyBase/$_downloadsFolder';
      _musicPath = '$docs/cosmodrome/Music';
    } else if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      _basePath = legacyBase;
      _downloadsPath = '${external?.path ?? legacyBase}/$_downloadsFolder';
      _musicPath = '${external?.path ?? legacyBase}/Music';
    } else {
      _basePath = legacyBase;
      _downloadsPath = '$legacyBase/$_downloadsFolder';
      _musicPath = '$legacyBase/Music';
    }

    await Directory(_base).create(recursive: true);
    await Directory(_downloads).create(recursive: true);
    await Directory(_music).create(recursive: true);

    try {
      await _migrate(legacyBase);
    } catch (_) {}
  }

  Future<void> _migrate(String legacyBase) async {
    final legacy = Directory(legacyBase);
    if (!await legacy.exists()) return;

    final skip = {_downloadsFolder, 'Music'};
    await for (final entity in legacy.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final accountId = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (skip.contains(accountId)) continue;

      final songs = Directory('${entity.path}/songs');
      if (await songs.exists()) {
        final target = Directory(_accountDownloads(accountId));
        await target.create(recursive: true);
        await for (final file in songs.list(followLinks: false)) {
          if (file is! File) continue;
          final name = file.uri.pathSegments.last;
          await _move(file, '${target.path}/$name');
        }
        await songs.delete(recursive: true);
      }

      if (legacyBase != _base) {
        final target = Directory('$_base/$accountId');
        if (!await target.exists()) {
          await _moveDir(entity, target.path);
        } else {
          await entity.delete(recursive: true);
        }
      }
    }

    if (legacyBase != _base && await legacy.list().isEmpty) {
      await legacy.delete();
    }
  }

  Future<void> _move(File file, String to) async {
    try {
      await file.rename(to);
    } on FileSystemException {
      await file.copy(to);
      await file.delete();
    }
  }

  Future<void> _moveDir(Directory dir, String to) async {
    try {
      await dir.rename(to);
    } on FileSystemException {
      await Directory(to).create(recursive: true);
      await for (final entity in dir.list(recursive: true)) {
        final relative = entity.path.substring(dir.path.length);
        if (entity is Directory) {
          await Directory('$to$relative').create(recursive: true);
        } else if (entity is File) {
          await entity.copy('$to$relative');
        }
      }
      await dir.delete(recursive: true);
    }
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
      '${_accountDownloads(accountId)}/$songId.$suffix';

  @override
  Future<void> writeCoverImageBytes(String coverRef, List<int> bytes) =>
      File(coverRef).writeAsBytes(bytes, flush: true);

  @override
  Future<void> writeMeta(String metaRef, String content) async {
    await File(metaRef).parent.create(recursive: true);
    await File(metaRef).writeAsString(content);
  }

  @override
  Future<void> writeSongBytes(String songRef, List<int> bytes) =>
      File(songRef).writeAsBytes(bytes, flush: true);

  @override
  Future<List<LocalMusicFile>> listLocalMusic() async {
    final root = Directory(_music);
    if (!await root.exists()) return [];

    final excluded = [
      for (final e in [_downloads, if (!_music.startsWith(_base)) _base]) ...[
        '$e/',
        '$e\\',
      ],
    ];
    final files = <LocalMusicFile>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (excluded.any(path.startsWith)) continue;

      final name = path.substring(_music.length + 1).replaceAll('\\', '/');
      if (name.split('/').any((part) => part.startsWith('.'))) continue;
      if (!isLocalMusicName(name)) continue;

      try {
        final stat = await entity.stat();
        files.add(
          LocalMusicFile(
            ref: path,
            name: name,
            size: stat.size,
            modified: stat.modified.millisecondsSinceEpoch,
          ),
        );
      } catch (_) {}
    }
    return files;
  }

  @override
  Future<String?> importLocalMusic(
    String name, {
    String? sourcePath,
    Uint8List? bytes,
  }) async {
    await Directory(_music).create(recursive: true);
    final target = await _freePath(name);
    if (sourcePath != null) {
      await File(sourcePath).copy(target);
    } else if (bytes != null) {
      await File(target).writeAsBytes(bytes, flush: true);
    } else {
      return null;
    }
    return target;
  }

  Future<String> _freePath(String name) async {
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    var candidate = '$_music/$name';
    var i = 1;
    while (await File(candidate).exists()) {
      candidate = '$_music/$stem ($i)$ext';
      i++;
    }
    return candidate;
  }

  @override
  Future<void> deleteLocalMusic(String ref) => _deleteIfExists(ref);

  @override
  Future<void> saveToDevice(String ref, String fileName) async {}
}
