abstract class LocalStorageBackend {
  Future<int> accountStorageBytes(String accountId);

  Future<bool> coverImageExists(String coverRef);
  String coverImageRef(String accountId, String imageId, String extension);
  Future<Uri?> coverImageUri(String coverRef);

  Future<void> deleteAccountCache(String accountId);

  Future<void> deleteCoverImage(String coverRef);
  Future<void> deleteSong(String songRef);
  Future<void> ensureDirs(String accountId);
  Future<void> init();
  String metaRef(String accountId, String key);
  Future<Uri?> playableUri(String songRef);
  Future<String?> readMeta(String metaRef);

  Future<void> releasePlayableUri(Uri uri);
  Future<bool> songExists(String songRef);

  String songRef(String accountId, String songId, String suffix);

  Future<void> writeCoverImageBytes(String coverRef, List<int> bytes);
  Future<void> writeMeta(String metaRef, String content);
  Future<void> writeSongBytes(String songRef, List<int> bytes);
}
