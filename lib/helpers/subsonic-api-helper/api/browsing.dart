import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';

extension SubsonicBrowsingApi on Subsonic {
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
