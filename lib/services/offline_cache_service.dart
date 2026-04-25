import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/services/local_storage_service.dart';
import 'package:cosmodrome/utils/logger.dart';
import 'package:flutter/material.dart';

const _offlineTTL = Duration(hours: 24);
const _schemaVersion = 1;

final offlineCacheService = OfflineCacheService();

class OfflineCacheService {
  static const _albums = 'albums';
  static const _artists = 'artists';
  static const _playlists = 'playlists';
  static const _songs = 'songs';
  static const _recentAlbums = 'recent_albums';
  static const _starredAlbums = 'starred_albums';
  static const _albumDetail = 'album_detail';
  static const _playlistDetail = 'playlist_detail';

  static const _recentSearches = 'recent_searches';
  static const _spotlightItems = 'spotlight_items';

  // tracks accounts whose dirs are confirmed to exist this session
  final _initializedAccounts = <String>{};

  Future<void> clearCacheForAccount(String accountId) async {
    try {
      await LocalStorageService.clearAccountCache(accountId);
      _initializedAccounts.remove(accountId);
      // reset art
      clearCoverArtCache();
      // delete paintbinding cache to avoid showing stale images after logout
      PaintingBinding.instance.imageCache.clear();
      loggerPrint('OfflineCache: cleared cache for account $accountId');
    } catch (e) {
      loggerPrint('OfflineCache: failed to clear cache for $accountId: $e');
    }
  }

  Future<AlbumDetail?> loadAlbumDetail(String accountId, String albumId) async {
    final raw = await _read(accountId, '$_albumDetail:$albumId');
    if (raw == null || raw.isEmpty) return null;
    return AlbumDetail.fromJson(raw.first);
  }

  Future<List<Album>?> loadAlbums(String accountId) async {
    final raw = await _read(accountId, _albums);
    return raw?.map((e) => Album.fromJson(e)).toList();
  }

  Future<List<Artist>?> loadArtists(String accountId) async {
    final raw = await _read(accountId, _artists);
    return raw?.map((e) => Artist.fromJson(e)).toList();
  }

  Future<PlaylistDetail?> loadPlaylistDetail(
    String accountId,
    String playlistId,
  ) async {
    final raw = await _read(accountId, '$_playlistDetail:$playlistId');
    if (raw == null || raw.isEmpty) return null;
    return PlaylistDetail.fromJson(raw.first);
  }

  Future<List<Playlist>?> loadPlaylists(String accountId) async {
    final raw = await _read(accountId, _playlists);
    return raw?.map((e) => Playlist.fromJson(e)).toList();
  }

  Future<List<Album>?> loadRecentAlbums(String accountId) async {
    final raw = await _read(accountId, _recentAlbums);
    return raw?.map((e) => Album.fromJson(e)).toList();
  }

  Future<List<RecentSearch>?> loadRecentSearches(String accountId) async {
    final raw = await _read(accountId, _recentSearches);
    return raw?.map((e) => RecentSearch.fromJson(e)).toList();
  }

  Future<List<Song>?> loadSongs(String accountId) async {
    final raw = await _read(accountId, _songs);
    return raw?.map((e) => Song.fromJson(e)).toList();
  }

  Future<List<SpotlightItem>?> loadSpotlightItems(String accountId) async {
    final raw = await _read(accountId, _spotlightItems);
    return raw?.map((e) => SpotlightItem.fromJson(e)).toList();
  }

  Future<List<Album>?> loadStarredAlbums(String accountId) async {
    final raw = await _read(accountId, _starredAlbums);
    return raw?.map((e) => Album.fromJson(e)).toList();
  }

  Future<void> saveAlbumDetail(String accountId, AlbumDetail album) =>
      _write(accountId, '$_albumDetail:${album.id}', [album.toJson()]);

  Future<void> saveAlbums(String accountId, List<Album> items) =>
      _write(accountId, _albums, items.map((e) => e.toJson()).toList());

  Future<void> saveArtists(String accountId, List<Artist> items) =>
      _write(accountId, _artists, items.map((e) => e.toJson()).toList());

  Future<void> savePlaylistDetail(String accountId, PlaylistDetail playlist) =>
      _write(accountId, '$_playlistDetail:${playlist.id}', [playlist.toJson()]);

  Future<void> savePlaylists(String accountId, List<Playlist> items) =>
      _write(accountId, _playlists, items.map((e) => e.toJson()).toList());

  Future<void> saveRecentAlbums(String accountId, List<Album> items) =>
      _write(accountId, _recentAlbums, items.map((e) => e.toJson()).toList());

  Future<void> saveSongs(String accountId, List<Song> items) =>
      _write(accountId, _songs, items.map((e) => e.toJson()).toList());

  Future<void> saveSpotlightItems(
    String accountId,
    List<SpotlightItem> items,
  ) =>
      _write(accountId, _spotlightItems, items.map((e) => e.toJson()).toList());

  Future<void> saveStarredAlbums(String accountId, List<Album> items) =>
      _write(accountId, _starredAlbums, items.map((e) => e.toJson()).toList());

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
}

/// recent search is a class for stuff users have searched before
/// it is formatted as such:
/// [id] id of the item searched for (playlist, song, album, artist, etc.)
/// [title] title of the item searched for (e.g. song name, album name, artist name, etc.)
/// [subtitle] subtitle of the item searched for (e.g. artist name for a song, album name for a song, etc.)
/// [artId] id of the art for the item searched for (e.g. album art id for a song, artist art id for an artist, etc.) or art id for song
/// [type] can be a Song, Playlist, Album or Artist
class RecentSearch {
  final String id;
  final String title;
  final String subtitle;
  final String artId;
  final RecentSearchEnum type;

  RecentSearch({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.artId,
    required this.type,
  });

  factory RecentSearch.fromJson(Map<String, dynamic> json) => RecentSearch(
    id: json['id'] as String,
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    artId: json['artId'] as String,
    type: RecentSearchEnum.values.firstWhere(
      (e) => e.toString() == json['type'],
    ),
  );

  /// pass through a [subsonic] instance to get the cached cover art url for this search, if it exists
  /// ensure you are on the RIGHT account for this.
  String? getAlbumImagePath(Subsonic subsonic, {int size = 80}) {
    if (artId.isEmpty) return null;
    return subsonic.cachedCoverArtUrl(artId, size: size);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'artId': artId,
    'type': type.toString(),
  };
}

enum RecentSearchEnum { song, album, artist, playlist }

class SpotlightItem {
  final String albumId;
  final String albumName;
  final String artistName;
  final String? artistId;
  final String? coverArt;
  final String? description;
  final int? accentColorValue;

  const SpotlightItem({
    required this.albumId,
    required this.albumName,
    required this.artistName,
    required this.artistId,
    required this.coverArt,
    required this.description,
    required this.accentColorValue,
  });

  factory SpotlightItem.fromJson(Map<String, dynamic> json) => SpotlightItem(
    albumId: json['albumId'] as String,
    albumName: json['albumName'] as String,
    artistName: json['artistName'] as String,
    artistId: json['artistId'] as String?,
    coverArt: json['coverArt'] as String?,
    description: json['description'] as String?,
    accentColorValue: json['accentColorValue'] as int?,
  );

  Color? get accentColor =>
      accentColorValue != null ? Color(accentColorValue!) : null;

  Map<String, dynamic> toJson() => {
    'albumId': albumId,
    'albumName': albumName,
    'artistName': artistName,
    'artistId': artistId,
    'coverArt': coverArt,
    'description': description,
    'accentColorValue': accentColorValue,
  };
}
