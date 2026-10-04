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

  Future<Object?> _get(String storeName, String key) async {
    final db = await _dbFuture;
    final txn = db.transaction(storeName, idbModeReadOnly);
    final value = await txn.objectStore(storeName).getObject(key);
    await txn.completed;
    return value;
  }

  Future<void> _put(String storeName, String key, Object value) async {
    final db = await _dbFuture;
    final txn = db.transaction(storeName, idbModeReadWrite);
    await txn.objectStore(storeName).put(value, key);
    await txn.completed;
  }

  Future<void> _delete(String storeName, String key) async {
    final db = await _dbFuture;
    final txn = db.transaction(storeName, idbModeReadWrite);
    await txn.objectStore(storeName).delete(key);
    await txn.completed;
  }

  @override
  Future<int> accountStorageBytes(String accountId) async {
    final db = await _dbFuture;
    final txn = db.transaction(_songsStore, idbModeReadOnly);
    final store = txn.objectStore(_songsStore);
    final prefixes = [
      '$accountId/songs/',
      '$accountId/cached-images/',
      '$accountId/cache/',
    ];

    var total = 0;
    await for (final cursor
        in store.openCursor(autoAdvance: true).asBroadcastStream()) {
      final key = cursor.key.toString();
      if (!prefixes.any(key.startsWith)) continue;
      final value = cursor.value;
      if (value is List<int>) total += value.length;
    }
    await txn.completed;
    return total;
  }

  @override
  Future<bool> coverImageExists(String coverRef) async =>
      await _get(_songsStore, coverRef) != null;

  @override
  String coverImageRef(String accountId, String imageId, String extension) =>
      '$accountId/cached-images/$imageId.$extension';

  @override
  Future<List<int>?> readCoverImageBytes(String coverRef) async {
    final value = await _get(_songsStore, coverRef);
    return value is List<int> ? value : null;
  }

  @override
  Future<void> deleteAccountCache(String accountId) async {
    final db = await _dbFuture;
    final txn = db.transaction([_songsStore, _metaStore], idbModeReadWrite);
    final songsStore = txn.objectStore(_songsStore);
    final metaStore = txn.objectStore(_metaStore);

    final songPrefixes = ['$accountId/songs/', '$accountId/cached-images/'];
    await for (final cursor
        in songsStore.openCursor(autoAdvance: true).asBroadcastStream()) {
      final key = cursor.key.toString();
      if (!songPrefixes.any(key.startsWith)) continue;
      await cursor.delete();
    }

    final metaPrefix = '$accountId/cache/';
    await for (final cursor
        in metaStore.openCursor(autoAdvance: true).asBroadcastStream()) {
      final key = cursor.key.toString();
      if (!key.startsWith(metaPrefix)) continue;
      await cursor.delete();
    }

    await txn.completed;
  }

  @override
  Future<void> deleteCoverImage(String coverRef) =>
      _delete(_songsStore, coverRef);

  @override
  Future<void> deleteSong(String songRef) => _delete(_songsStore, songRef);

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
    final value = await _get(_songsStore, songRef);
    if (value == null) return null;
    final bytes = value is Uint8List
        ? value
        : Uint8List.fromList((value as List).cast<int>());
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    return Uri.parse(url);
  }

  @override
  Future<String?> readMeta(String metaRef) async =>
      await _get(_metaStore, metaRef) as String?;

  @override
  Future<void> releasePlayableUri(Uri uri) async {
    if (uri.scheme == 'blob') {
      html.Url.revokeObjectUrl(uri.toString());
    }
  }

  @override
  Future<bool> songExists(String songRef) async =>
      await _get(_songsStore, songRef) != null;

  @override
  String songRef(String accountId, String songId, String suffix) =>
      '$accountId/songs/$songId.$suffix';

  @override
  Future<void> writeCoverImageBytes(String coverRef, List<int> bytes) =>
      _put(_songsStore, coverRef, Uint8List.fromList(bytes));

  @override
  Future<void> writeMeta(String metaRef, String content) =>
      _put(_metaStore, metaRef, content);

  @override
  Future<void> writeSongBytes(String songRef, List<int> bytes) =>
      _put(_songsStore, songRef, Uint8List.fromList(bytes));
}
