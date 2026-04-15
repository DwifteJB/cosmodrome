import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';

extension SubsonicBrowsingApi on Subsonic {
  // https://www.subsonic.org/pages/api.jsp#getIndexes
  /// Gets the list of artists, albums, and songs in the music library.
  /// Can be filtered by music folder and/or by modification date.
  /// ifModifiedSince = unix timestamp in ms
  /// musicFolderId = id of music folder to filter by (see getMusicFolders)
  Future<List<IndexesResponse>> getIndexes({
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

      final indexesJson = response['indexes']['index'] as List<dynamic>;
      return indexesJson.map((json) => IndexesResponse.fromJson(json)).toList();
    } catch (e) {
      print("Error fetching indexes: $e");
      return [];
    }
  }

  // https://www.subsonic.org/pages/inc/api/examples/musicFolders_example_1.xml
  Future<List<MusicFolder>> getMusicFolders() async {
    try {
      final response = await apiRequest("getMusicFolders");

      final musicFoldersJson =
          response['musicFolders']['musicFolder'] as List<dynamic>;
      return musicFoldersJson
          .map((json) => MusicFolder.fromJson(json))
          .toList();
    } catch (e) {
      print("Error fetching music folders: $e");
      return [];
    }
  }
}
