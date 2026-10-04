import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
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

/// Applies a reorder from a visible-queue list (whose first item is the
/// current song, offset by [queueOffset] in the full queue). The current song
/// stays pinned: it can't be dragged and nothing can be dropped above it.
void reorderVisibleQueue(
  PlayerProvider player,
  int oldIndex,
  int newIndex,
  int queueOffset,
) {
  if (oldIndex == 0) return;
  final target = newIndex < 1 ? 1 : newIndex;
  player.reorderQueue(
    oldIndex + queueOffset,
    (target > oldIndex ? target + 1 : target) + queueOffset,
  );
}
