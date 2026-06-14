import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/services/offline_cache_service.dart';
import 'package:cosmodrome/utils/logger/logger.dart';
import 'package:flutter/painting.dart';

void clearCoverArtCache() {
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();
}

extension SubsonicBrowsingApi on Subsonic {
  String get _accountId => '${auth.username}@$baseUrl';

  String cachedCoverArtUrl(String id, {int size = 300}) =>
      coverArtUrl(id, size: size);

  // https://www.subsonic.org/pages/api.jsp#getCoverArt
  String coverArtUrl(String id, {int size = 300}) {
    final query = {
      ...getLoginParams(loginMethod),
      'v': '1.16.1',
      'c': 'cosmodrome',
      'id': id,
      'size': '$size',
    };
    return Uri.http(baseUrl, '/rest/getCoverArt', query).toString();
  }

  // creates a new empty playlist and returns the new playlist id.
  Future<String?> createNewPlaylist(String name) async {
    try {
      final response = await apiRequest(
        'createPlaylist',
        params: {'name': name},
      );
      final playlist = response['playlist'] as Map<String, dynamic>?;

      // created new playlist, so clear anything that gives us playlist
      clearCacheStartingWith("getPlaylists");

      return playlist?['id'] as String?;
    } catch (e) {
      loggerPrint('Error creating playlist: $e');
      return null;
    }
  }

  // https://www.subsonic.org/pages/api.jsp#getAlbum
  Future<AlbumDetail?> getAlbum(String id) async {
    try {
      final response = await apiRequest('getAlbum', params: {'id': id});
      final albumJson = response['album'] as Map<String, dynamic>?;
      if (albumJson == null) return null;
      final album = AlbumDetail.fromJson(albumJson);
      await _saveAlbumDetailCache(album);
      return album;
    } catch (e) {
      loggerPrint('Error fetching album $id: $e');
      return _loadAlbumDetailFallback(id);
    }
  }

  // https://www.subsonic.org/pages/api.jsp#getAlbumList2
  Future<List<Album>> getAlbumList2(
    String type, {
    int size = 20,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    try {
      final response = await apiRequest(
        'getAlbumList2',
        params: {'type': type, 'size': '$size', 'offset': '$offset'},
        forceRefresh: forceRefresh,
      );
      final listJson = response['albumList2'] as Map<String, dynamic>?;
      if (listJson == null) return [];
      final albumsJson = listJson['album'] as List<dynamic>? ?? [];
      return albumsJson
          .map((j) => Album.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      loggerPrint('Error fetching album list ($type): $e');
      return [];
    }
  }

  // https://www.subsonic.org/pages/api.jsp#getArtist
  Future<List<Album>> getArtist(String id) async {
    try {
      final response = await apiRequest('getArtist', params: {'id': id});
      final artist = response['artist'] as Map<String, dynamic>?;
      if (artist == null) return [];
      final albumsJson = artist['album'] as List<dynamic>? ?? [];
      return albumsJson
          .map((j) => Album.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      loggerPrint('Error fetching artist $id: $e');
      return [];
    }
  }

  // https://www.subsonic.org/pages/api.jsp#getArtists
  Future<List<Artist>> getArtists() async {
    try {
      final response = await apiRequest('getArtists');
      final indexes = response['artists']?['index'] as List<dynamic>? ?? [];
      return indexes.expand((index) {
        final artists =
            (index as Map<String, dynamic>)['artist'] as List<dynamic>? ?? [];
        return artists.map((a) => Artist.fromJson(a as Map<String, dynamic>));
      }).toList();
    } catch (e) {
      loggerPrint('Error fetching artists: $e');
      return [];
    }
  }

  /// Gets the list of artists, albums, and songs in the music library.
  /// Can be filtered by music folder and/or by modification date.
  /// [ifModifiedSince] = unix timestamp in ms
  /// [musicFolderId] = id of music folder to filter by (see getMusicFolders)
  Future<List<Index>> getIndexes({
    String musicFolderId = '',
    String ifModifiedSince = '',
  }) async {
    try {
      final response = await apiRequest(
        "getIndexes",
        params: {
          if (musicFolderId.isNotEmpty) 'musicFolderId': musicFolderId,
          if (ifModifiedSince.isNotEmpty) 'ifModifiedSince': ifModifiedSince,
        },
      );

      // get res
      loggerPrint("response: $response");

      final indexesJson =
          (response['indexes'] as Map<String, dynamic>)['index']
              as List<dynamic>;
      return indexesJson
          .map((json) => Index.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      loggerPrint("Error fetching indexes: $e");
      return [];
    }
  }

  // https://www.subsonic.org/pages/inc/api/examples/musicFolders_example_1.xml
  Future<List<MusicFolder>> getMusicFolders() async {
    try {
      final response = await apiRequest("getMusicFolders");

      final musicFoldersJson =
          response['musicFolders']['musicFolder'] as List<dynamic>;

      // log entire response
      loggerPrint("getMusicFolders response: $response");
      return musicFoldersJson
          .map((json) => MusicFolder.fromJson(json))
          .toList();
    } catch (e) {
      loggerPrint("Error fetching music folders: $e");
      return [];
    }
  }

  // https://www.subsonic.org/pages/api.jsp#getPlaylist
  Future<PlaylistDetail?> getPlaylist(String id) async {
    try {
      final response = await apiRequest('getPlaylist', params: {'id': id});
      final json = response['playlist'] as Map<String, dynamic>?;
      if (json == null) return null;
      final playlist = PlaylistDetail.fromJson(json);
      await _savePlaylistDetailCache(playlist);
      return playlist;
    } catch (e) {
      loggerPrint('Error fetching playlist $id: $e');
      return _loadPlaylistDetailFallback(id);
    }
  }

  // https://www.subsonic.org/pages/api.jsp#getPlaylists
  Future<List<Playlist>> getPlaylists() async {
    try {
      final response = await apiRequest('getPlaylists');
      final raw = response['playlists']?['playlist'];
      if (raw == null) return [];
      // Some servers return a single object instead of an array when there's 1
      final list = raw is List ? raw : [raw];
      return list
          .map((p) => Playlist.fromJson(p as Map<String, dynamic>))
          .toList();
    } catch (e) {
      loggerPrint('Error fetching playlists: $e');
      return [];
    }
  }

  Future<AlbumDetail?> getRandomAlbum() async {
    // get a random album by getting 1 random song and then fetching its album
    try {
      final songs = await getRandomSongs(count: 1);
      if (songs.isEmpty) throw Exception('No random songs found');
      final song = songs.first;
      final album = await getAlbum(song.albumId);
      if (album == null) throw Exception('Album not found for random song');
      return album;
    } catch (e) {
      loggerPrint('Error fetching random album: $e');
      return null;
    }
  }

  // https://www.subsonic.org/pages/api.jsp#getRandomSongs
  Future<List<Song>> getRandomSongs({int count = 10}) async {
    try {
      final root = await apiRequest(
        'getRandomSongs',
        params: {'size': '$count'},
        forceRefresh: true, // never want to cache this lol
      );
      final songs = root['randomSongs']?['song'] as List<dynamic>? ?? [];
      return songs
          .map((s) => Song.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      loggerPrint('Error fetching random songs: $e');
      return [];
    }
  }

  Future<Song?> getSong(String id) async {
    try {
      final response = await apiRequest('getSong', params: {'id': id});
      final songJson = response['song'] as Map<String, dynamic>?;
      if (songJson == null) return null;
      return Song.fromJson(songJson);
    } catch (e) {
      loggerPrint('Error fetching song $id: $e');
      return null;
    }
  }

  // replaces all songs with a given list
  Future<void> replacePlaylistSongs(
    String playlistId,
    List<String> songIds,
  ) async {
    try {
      await multiParamRequest(
        'createPlaylist',
        params: {'playlistId': playlistId, 'songId': songIds},
      );
      clearCacheStartingWith("getPlaylist?id=$playlistId");
      clearCacheStartingWith("getPlaylists");
    } catch (e) {
      loggerPrint('Error replacing playlist songs $playlistId: $e');
      rethrow;
    }
  }

  // https://www.subsonic.org/pages/api.jsp#search3
  Future<SearchResult> search3(String query) async {
    // /rest/search3
    try {
      final response = await apiRequest(
        'search3',
        params: {
          'query': query,
          'artistCount': '5',
          'albumCount': '5',
          'songCount': '20',
        },
      );
      return SearchResult.fromJson(response['searchResult3']);
    } catch (e) {
      loggerPrint('Error performing search: $e');
      return SearchResult(songs: [], albums: [], artists: []);
    }
  }

  // https://www.subsonic.org/pages/api.jsp#search3
  Future<List<Song>> searchThreeSongs({
    String q = '',
    int count = 200,
    int offset = 0,
  }) async {
    try {
      final response = await apiRequest(
        'search3',
        params: {
          'query': q,
          'songCount': '$count',
          'songOffset': '$offset',
          'artistCount': '0',
          'albumCount': '0',
        },
      );
      final songs = response['searchResult3']?['song'] as List<dynamic>? ?? [];
      return songs
          .map((s) => Song.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      loggerPrint('Error searching songs: $e');
      return [];
    }
  }

  // https://www.subsonic.org/pages/api.jsp#star
  Future<bool> starAlbum(String albumId) async {
    try {
      await apiRequest('star', params: {'albumId': albumId});

      // since we starred, we gotta clear cache cuz everything will be stale now
      clearCacheStartingWith("getAlbum");
      clearCacheStartingWith("getAlbumList2");

      return true;
    } catch (e) {
      loggerPrint('Error starring album $albumId: $e');
      return false;
    }
  }

  Future<bool> starSong(String id) async {
    try {
      await apiRequest('star', params: {'id': id});
      clearCacheStartingWith("getAlbum");
      return true;
    } catch (e) {
      loggerPrint('Error starring song $id: $e');
      return false;
    }
  }

  // https://www.subsonic.org/pages/api.jsp#unstar
  Future<bool> unstarAlbum(String albumId) async {
    try {
      await apiRequest('unstar', params: {'albumId': albumId});

      // since we starred, we gotta clear cache cuz everything will be stale now
      clearCacheStartingWith("getAlbum");
      clearCacheStartingWith("getAlbumList2");
      return true;
    } catch (e) {
      loggerPrint('Error unstarring album $albumId: $e');
      return false;
    }
  }

  Future<bool> unstarSong(String id) async {
    try {
      await apiRequest('unstar', params: {'id': id});
      clearCacheStartingWith("getAlbum");
      return true;
    } catch (e) {
      loggerPrint('Error unstarring song $id: $e');
      return false;
    }
  }

  // https://www.subsonic.org/pages/api.jsp#updatePlaylist
  Future<void> updatePlaylist({
    required String playlistId,
    String? name,
    String? songIdToAdd,
    int? songIndexToRemove,
  }) async {
    try {
      await apiRequest(
        'updatePlaylist',
        params: {
          'playlistId': playlistId,
          'name': ?name,
          'songIdToAdd': ?songIdToAdd,
          if (songIndexToRemove != null)
            'songIndexToRemove': '$songIndexToRemove',
        },
      );
      clearCacheStartingWith("getPlaylist?id=$playlistId");
      clearCacheStartingWith("getPlaylists");
    } catch (e) {
      loggerPrint('Error updating playlist $playlistId: $e');
      rethrow;
    }
  }

  Future<AlbumDetail?> _loadAlbumDetailFallback(String id) async {
    try {
      return await offlineCacheService.loadAlbumDetail(_accountId, id);
    } catch (_) {
      return null;
    }
  }

  Future<PlaylistDetail?> _loadPlaylistDetailFallback(String id) async {
    try {
      return await offlineCacheService.loadPlaylistDetail(_accountId, id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveAlbumDetailCache(AlbumDetail album) async {
    try {
      await offlineCacheService.saveAlbumDetail(_accountId, album);
    } catch (_) {}
  }

  Future<void> _savePlaylistDetailCache(PlaylistDetail playlist) async {
    try {
      await offlineCacheService.savePlaylistDetail(_accountId, playlist);
    } catch (_) {}
  }

}
