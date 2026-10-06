import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';

void orderSongsByDisc(List<Song> songs) {
  final indexed = songs.indexed.toList(growable: false);
  indexed.sort((a, b) {
    final disc = (a.$2.discNumber ?? 0).compareTo(b.$2.discNumber ?? 0);
    if (disc != 0) return disc;
    final track = (a.$2.track ?? 0).compareTo(b.$2.track ?? 0);
    return track != 0 ? track : a.$1.compareTo(b.$1);
  });
  for (var i = 0; i < indexed.length; i++) {
    songs[i] = indexed[i].$2;
  }
}

bool hasMultipleDiscs(List<Song> songs) =>
    songs.map((s) => s.discNumber ?? 1).toSet().length > 1;
