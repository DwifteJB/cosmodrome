import 'dart:typed_data';

abstract class LocalStorageBackend {
  Future<int> accountStorageBytes(String accountId);

  Future<bool> coverImageExists(String coverRef);
  String coverImageRef(String accountId, String imageId, String extension);
  Future<List<int>?> readCoverImageBytes(String coverRef);

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

  String? get downloadsDirectory;
  String? get localMusicDirectory;

  Future<List<LocalMusicFile>> listLocalMusic();
  Future<String?> importLocalMusic(
    String name, {
    String? sourcePath,
    Uint8List? bytes,
  });
  Future<void> deleteLocalMusic(String ref);

  Future<void> saveToDevice(String ref, String fileName);
}

class LocalMusicFile {
  final String ref;
  final String name;
  final int size;
  final int modified;

  const LocalMusicFile({
    required this.ref,
    required this.name,
    required this.size,
    required this.modified,
  });
}

const localMusicExtensions = {
  'mp3',
  'flac',
  'm4a',
  'mp4',
  'aac',
  'alac',
  'ogg',
  'oga',
  'opus',
  'wav',
  'aif',
  'aiff',
  'wma',
};

bool isLocalMusicName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return false;
  return localMusicExtensions.contains(name.substring(dot + 1).toLowerCase());
}
