import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:go_router/go_router.dart';

bool songHasArtist(Song song) =>
    song.artistId?.isNotEmpty == true || song.artist?.isNotEmpty == true;

void openAlbum(GoRouter router, String albumId) {
  if (albumId.isEmpty) return;
  _pushOnce(router, '/library/album/$albumId');
}

Future<void> openArtist(
  GoRouter router,
  Subsonic subsonic, {
  String? artistId,
  String? artistName,
}) async {
  var id = artistId;
  if (id == null || id.isEmpty) {
    final name = artistName?.trim() ?? '';
    if (name.isEmpty) return;
    final result = await subsonic.search3(
      name,
      artistCount: 10,
      albumCount: 0,
      songCount: 0,
    );
    id = result.artists
        .where((a) => a.name.trim().toLowerCase() == name.toLowerCase())
        .firstOrNull
        ?.id;
  }
  if (id == null || id.isEmpty) return;
  _pushOnce(router, '/library/artist/$id');
}

void _pushOnce(GoRouter router, String location) {
  if (router.state.uri.path == location) return;
  router.push(location);
}
