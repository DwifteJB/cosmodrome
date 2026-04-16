import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/utils/logger.dart';

extension SubsonicBrowsingApi on Subsonic {
  // https://www.subsonic.org/pages/api.jsp#getIndexes
  /// Gets the list of artists, albums, and songs in the music library.
  /// Can be filtered by music folder and/or by modification date.
  /// ifModifiedSince = unix timestamp in ms
  /// musicFolderId = id of music folder to filter by (see getMusicFolders)
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

  /// Builds a cover art URL without making an HTTP request.
  /// Safe to use directly in Image.network().
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
}
