import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/services/local_storage_service.dart';
import 'package:cosmodrome/utils/logger.dart';

const _schemaVersion = 1;
const _offlineTTL = Duration(hours: 24);

class OfflineCacheService {
  static const _albums = 'albums';
  static const _artists = 'artists';
  static const _playlists = 'playlists';
  static const _songs = 'songs';
  static const _recentAlbums = 'recent_albums';
  static const _starredAlbums = 'starred_albums';
  static const _albumDetail = 'album_detail';
  static const _playlistDetail = 'playlist_detail';

  // tracks accounts whose dirs are confirmed to exist this session
  final _initializedAccounts = <String>{};

  Future<void> saveAlbums(String accountId, List<Album> items) =>
      _write(accountId, _albums, items.map((e) => e.toJson()).toList());

  Future<List<Album>?> loadAlbums(String accountId) async {
    final raw = await _read(accountId, _albums);
    return raw?.map((e) => Album.fromJson(e)).toList();
  }

  Future<void> saveArtists(String accountId, List<Artist> items) =>
      _write(accountId, _artists, items.map((e) => e.toJson()).toList());

  Future<List<Artist>?> loadArtists(String accountId) async {
    final raw = await _read(accountId, _artists);
    return raw?.map((e) => Artist.fromJson(e)).toList();
  }

  Future<void> savePlaylists(String accountId, List<Playlist> items) =>
      _write(accountId, _playlists, items.map((e) => e.toJson()).toList());

  Future<List<Playlist>?> loadPlaylists(String accountId) async {
    final raw = await _read(accountId, _playlists);
    return raw?.map((e) => Playlist.fromJson(e)).toList();
  }

  Future<void> saveSongs(String accountId, List<Song> items) =>
      _write(accountId, _songs, items.map((e) => e.toJson()).toList());

  Future<List<Song>?> loadSongs(String accountId) async {
    final raw = await _read(accountId, _songs);
    return raw?.map((e) => Song.fromJson(e)).toList();
  }

  Future<void> saveRecentAlbums(String accountId, List<Album> items) =>
      _write(accountId, _recentAlbums, items.map((e) => e.toJson()).toList());

  Future<List<Album>?> loadRecentAlbums(String accountId) async {
    final raw = await _read(accountId, _recentAlbums);
    return raw?.map((e) => Album.fromJson(e)).toList();
  }

  Future<void> saveStarredAlbums(String accountId, List<Album> items) =>
      _write(accountId, _starredAlbums, items.map((e) => e.toJson()).toList());

  Future<List<Album>?> loadStarredAlbums(String accountId) async {
    final raw = await _read(accountId, _starredAlbums);
    return raw?.map((e) => Album.fromJson(e)).toList();
  }

  Future<void> saveAlbumDetail(String accountId, AlbumDetail album) =>
      _write(accountId, '$_albumDetail:${album.id}', [album.toJson()]);

  Future<AlbumDetail?> loadAlbumDetail(String accountId, String albumId) async {
    final raw = await _read(accountId, '$_albumDetail:$albumId');
    if (raw == null || raw.isEmpty) return null;
    return AlbumDetail.fromJson(raw.first);
  }

  Future<void> savePlaylistDetail(String accountId, PlaylistDetail playlist) =>
      _write(accountId, '$_playlistDetail:${playlist.id}', [playlist.toJson()]);

  Future<PlaylistDetail?> loadPlaylistDetail(
    String accountId,
    String playlistId,
  ) async {
    final raw = await _read(accountId, '$_playlistDetail:$playlistId');
    if (raw == null || raw.isEmpty) return null;
    return PlaylistDetail.fromJson(raw.first);
  }

  Future<void> _write(
    String accountId,
    String key,
    List<Map<String, dynamic>> data,
  ) async {
    try {
      if (!_initializedAccounts.contains(accountId)) {
        await LocalStorageService.ensureDirs(accountId);
        _initializedAccounts.add(accountId);
      }
      final envelope = {
        'version': _schemaVersion,
        'timestamp': DateTime.now().toIso8601String(),
        'data': data,
      };
      await LocalStorageService.writeJsonMeta(accountId, key, envelope);
    } catch (e) {
      loggerPrint('OfflineCache: failed to write $key for $accountId: $e');
    }
  }

  Future<List<Map<String, dynamic>>?> _read(
    String accountId,
    String key,
  ) async {
    try {
      final envelope = await LocalStorageService.readJsonMeta(accountId, key);
      if (envelope == null) return null;

      if ((envelope['version'] as int?) != _schemaVersion) {
        loggerPrint(
          'OfflineCache: stale schema version for $key, discarding cache',
        );
        return null;
      }

      final timestamp = DateTime.tryParse(
        envelope['timestamp'] as String? ?? '',
      );
      if (timestamp == null ||
          DateTime.now().difference(timestamp) > _offlineTTL) {
        loggerPrint('OfflineCache: expired cache for $key, discarding');
        return null;
      }

      return (envelope['data'] as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      loggerPrint('OfflineCache: failed to read $key for $accountId: $e');
      return null;
    }
  }
}

final offlineCacheService = OfflineCacheService();
