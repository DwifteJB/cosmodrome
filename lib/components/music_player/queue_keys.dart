import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:flutter/foundation.dart';

List<Key> queueItemKeys(List<Song> queue) {
  final seen = <String, int>{};
  return [
    for (final song in queue)
      ValueKey(
        '${song.id}#${seen.update(song.id, (n) => n + 1, ifAbsent: () => 0)}',
      ),
  ];
}
