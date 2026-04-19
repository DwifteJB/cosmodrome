// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:cosmodrome/services/local_storage_backend.dart';
import 'package:idb_shim/idb_browser.dart';

class WebLocalStorageBackend implements LocalStorageBackend {
  static const _dbName = 'cosmodrome_storage';
  static const _songsStore = 'songs';
  static const _metaStore = 'meta';

  late final Future<Database> _dbFuture;

  @override
  Future<int> accountStorageBytes(String accountId) async {
    final db = await _dbFuture;
    final txn = db.transaction(_songsStore, idbModeReadOnly);
    final store = txn.objectStore(_songsStore);
    final prefixes = ['$accountId/songs/', '$accountId/cached-images/'];

    var total = 0;
    await for (final cursor
        in store.openCursor(autoAdvance: true).asBroadcastStream()) {
      final key = cursor.key.toString();
      if (!prefixes.any(key.startsWith)) continue;
      final value = cursor.value;
      if (value is Uint8List) {
        total += value.length;
      } else if (value is List<int>) {
        total += value.length;
      }
    }
    await txn.completed;
    return total;
  }

  @override
  Future<bool> coverImageExists(String coverRef) async {
    final db = await _dbFuture;
    final txn = db.transaction(_songsStore, idbModeReadOnly);
    final value = await txn.objectStore(_songsStore).getObject(coverRef);
    await txn.completed;
    return value != null;
  }

  @override
  String coverImageRef(String accountId, String imageId, String extension) =>
      '$accountId/cached-images/$imageId.$extension';

  @override
  Future<Uri?> coverImageUri(String coverRef) async {
    final db = await _dbFuture;
    final txn = db.transaction(_songsStore, idbModeReadOnly);
    final value = await txn.objectStore(_songsStore).getObject(coverRef);
    await txn.completed;

    if (value == null) return null;
    final bytes = value is Uint8List
        ? value
        : Uint8List.fromList((value as List).cast<int>());
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    return Uri.parse(url);
  }

  @override
  Future<void> deleteCoverImage(String coverRef) async {
    final db = await _dbFuture;
    final txn = db.transaction(_songsStore, idbModeReadWrite);
    await txn.objectStore(_songsStore).delete(coverRef);
    await txn.completed;
  }

  @override
  Future<void> deleteSong(String songRef) async {
    final db = await _dbFuture;
    final txn = db.transaction(_songsStore, idbModeReadWrite);
    await txn.objectStore(_songsStore).delete(songRef);
    await txn.completed;
  }

  @override
  Future<void> ensureDirs(String accountId) async {
    // no need, due to no dirs
  }

  @override
  Future<void> init() async {
    _dbFuture = idbFactoryBrowser.open(
      _dbName,
      version: 1,
      onUpgradeNeeded: (event) {
        final db = event.database;
        if (!db.objectStoreNames.contains(_songsStore)) {
          db.createObjectStore(_songsStore);
        }
        if (!db.objectStoreNames.contains(_metaStore)) {
          db.createObjectStore(_metaStore);
        }
      },
    );
    await _dbFuture;
  }

  @override
  String metaRef(String accountId, String key) => '$accountId/cache/$key.json';

  @override
  Future<Uri?> playableUri(String songRef) async {
    final db = await _dbFuture;
    final txn = db.transaction(_songsStore, idbModeReadOnly);
    final value = await txn.objectStore(_songsStore).getObject(songRef);
    await txn.completed;

    if (value == null) return null;
    final bytes = value is Uint8List
        ? value
        : Uint8List.fromList((value as List).cast<int>());
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    return Uri.parse(url);
  }

  @override
  Future<String?> readMeta(String metaRef) async {
    final db = await _dbFuture;
    final txn = db.transaction(_metaStore, idbModeReadOnly);
    final value = await txn.objectStore(_metaStore).getObject(metaRef);
    await txn.completed;
    return value as String?;
  }

  @override
  Future<void> releasePlayableUri(Uri uri) async {
    if (uri.scheme == 'blob') {
      html.Url.revokeObjectUrl(uri.toString());
    }
  }

  @override
  Future<bool> songExists(String songRef) async {
    final db = await _dbFuture;
    final txn = db.transaction(_songsStore, idbModeReadOnly);
    final value = await txn.objectStore(_songsStore).getObject(songRef);
    await txn.completed;
    return value != null;
  }

  @override
  String songRef(String accountId, String songId, String suffix) =>
      '$accountId/songs/$songId.$suffix';

  @override
  Future<void> writeCoverImageBytes(String coverRef, List<int> bytes) async {
    final db = await _dbFuture;
    final txn = db.transaction(_songsStore, idbModeReadWrite);
    await txn.objectStore(_songsStore).put(Uint8List.fromList(bytes), coverRef);
    await txn.completed;
  }

  @override
  Future<void> writeMeta(String metaRef, String content) async {
    final db = await _dbFuture;
    final txn = db.transaction(_metaStore, idbModeReadWrite);
    await txn.objectStore(_metaStore).put(content, metaRef);
    await txn.completed;
  }

  @override
  Future<void> writeSongBytes(String songRef, List<int> bytes) async {
    final db = await _dbFuture;
    final txn = db.transaction(_songsStore, idbModeReadWrite);
    await txn.objectStore(_songsStore).put(Uint8List.fromList(bytes), songRef);
    await txn.completed;
  }
}
