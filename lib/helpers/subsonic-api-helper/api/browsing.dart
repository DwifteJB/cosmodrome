import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/utils/logger.dart';

// app wide cache for coverUrls, since they are deterministic based on token
// not good, sicne lot of redraws
final _coverArtUrlCache = <String, String>{};

/// Call this when the active account changes so stale tokens are cleared.
void clearCoverArtCache() => _coverArtUrlCache.clear();

extension SubsonicBrowsingApi on Subsonic {
  // https://www.subsonic.org/pages/api.jsp#getIndexes
  /// Builds a cover art URL without making an HTTP request.
  /// NOT Safe to use directly in Image.network()!!! MAKE SURE TO CACHE!!!
  String coverArtUrl(String id, {int size = 300}) {
    final tok = auth.generateToken();
    final query = {
      'u': auth.username,
      't': tok.token,
      's': tok.salt,
      'v': '1.16.1',
      'c': 'cosmodrome',
      'id': id,
      'size': '$size',
    };
    return Uri.http(baseUrl, '/rest/getCoverArt', query).toString();
  }

  /// Returns a cached version of [coverArtUrl]. Safe to use in Image.network() since the URL will never change for a given id and size, but must be cleared when the active account changes.
  String cachedCoverArtUrl(String id, {int size = 300}) {
    final key = '$baseUrl|$id|$size';
    return _coverArtUrlCache.putIfAbsent(
      key,
      () => coverArtUrl(id, size: size),
    );
  }

  // https://www.subsonic.org/pages/api.jsp#getAlbum
  Future<AlbumDetail?> getAlbum(String id) async {
    try {
      final response = await apiRequest('getAlbum', params: {'id': id});
      final albumJson = response['album'] as Map<String, dynamic>?;
      if (albumJson == null) return null;
      return AlbumDetail.fromJson(albumJson);
    } catch (e) {
      loggerPrint('Error fetching album $id: $e');
      return null;
    }
  }

  // https://www.subsonic.org/pages/api.jsp#getAlbumList2
  Future<List<Album>> getAlbumList2(
    String type, {
    int size = 20,
    int offset = 0,
  }) async {
    try {
      final response = await apiRequest(
        'getAlbumList2',
        params: {'type': type, 'size': '$size', 'offset': '$offset'},
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

  // https://www.subsonic.org/pages/api.jsp#getPlaylist
  Future<PlaylistDetail?> getPlaylist(String id) async {
    try {
      final response = await apiRequest('getPlaylist', params: {'id': id});
      final json = response['playlist'] as Map<String, dynamic>?;
      if (json == null) return null;
      return PlaylistDetail.fromJson(json);
    } catch (e) {
      loggerPrint('Error fetching playlist $id: $e');
      return null;
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
      await apiRequest('updatePlaylist', params: {
        'playlistId': playlistId,
        'name': ?name,
        'songIdToAdd': ?songIdToAdd,
        if (songIndexToRemove != null)
          'songIndexToRemove': '$songIndexToRemove',
      });
    } catch (e) {
      loggerPrint('Error updating playlist $playlistId: $e');
      rethrow;
    }
  }

  // creates a new empty playlist and returns the new playlist id.
  Future<String?> createNewPlaylist(String name) async {
    try {
      final response = await apiRequest(
        'createPlaylist',
        params: {'name': name},
      );
      final playlist = response['playlist'] as Map<String, dynamic>?;
      return playlist?['id'] as String?;
    } catch (e) {
      loggerPrint('Error creating playlist: $e');
      return null;
    }
  }

  // replaces all songs with a given list
  Future<void> replacePlaylistSongs(
    String playlistId,
    List<String> songIds,
  ) async {
    try {
      await multiParamRequest('createPlaylist', params: {
        'playlistId': playlistId,
        'songId': songIds,
      });
    } catch (e) {
      loggerPrint('Error replacing playlist songs $playlistId: $e');
      rethrow;
    }
  }

  // https://www.subsonic.org/pages/api.jsp#getRandomSongs
  Future<List<Song>> getRandomSongs({int count = 10}) async {
    try {
      final root = await apiRequest(
        'getRandomSongs',
        params: {'size': '$count'},
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
}
