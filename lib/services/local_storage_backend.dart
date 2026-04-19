abstract class LocalStorageBackend {
  Future<void> init();

  String songRef(String accountId, String songId, String suffix);
  String metaRef(String accountId, String key);

  Future<void> ensureDirs(String accountId);
  Future<void> writeSongBytes(String songRef, List<int> bytes);
  Future<bool> songExists(String songRef);
  Future<void> deleteSong(String songRef);

  Future<String?> readMeta(String metaRef);
  Future<void> writeMeta(String metaRef, String content);

  Future<int> accountStorageBytes(String accountId);

  Future<Uri?> playableUri(String songRef);
  Future<void> releasePlayableUri(Uri uri);
}
