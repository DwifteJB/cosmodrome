import 'dart:math';

import 'package:cosmodrome/components/music_player/queue_keys.dart';
import 'package:cosmodrome/components/scrolling_text.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/utils/cover_art/cover_art_provider.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

class MobileQueueList extends StatefulWidget {
  final Color accent;

  const MobileQueueList({super.key, required this.accent});

  @override
  State<MobileQueueList> createState() => _MobileQueueListState();
}

class _MobileQueueListState extends State<MobileQueueList> {
  final Map<String, String> _idToCoverUrlCache = {};

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerProvider, (int, int)>(
      selector: (_, p) => (p.queueVersion, p.currentIndex),
      builder: (context, _, _) {
        final player = context.read<PlayerProvider>();
        final queue = player.visibleQueue;
        final queueOffset = player.visibleQueueStartIndex;

        if (queue.isEmpty) {
          return Center(
            child: Text(
              'Queue is empty',
              style: context.theme.typography.sm.copyWith(
                color: Colors.white70,
              ),
            ),
          );
        }

        final keys = queueItemKeys(queue);
        return ReorderableListView.builder(
          key: const Key('queue_list'),
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: queue.length,
          onReorderItem: (oldIndex, newIndex) =>
              reorderVisibleQueue(player, oldIndex, newIndex, queueOffset),
          itemBuilder: (context, index) {
            final song = queue[index];
            final absoluteIndex = queueOffset + index;
            final coverUrl = _idToCoverUrlCache.putIfAbsent(
              song.id,
              () => player.coverArtUrlForSong(song) ?? '',
            );

            return Dismissible(
              key: keys[index],
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                color: context.theme.colors.destructive,
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white,
                ),
              ),
              onDismissed: (_) => player.removeFromQueue(absoluteIndex),
              child: ListTile(
                contentPadding: const EdgeInsets.only(left: 4, right: 16),
                dense: true,
                visualDensity: const VisualDensity(vertical: -2),
                minVerticalPadding: 4,
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    index == 0
                        ? const SizedBox(width: 40)
                        : ReorderableDragStartListener(
                            index: index,
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.drag_indicator_rounded,
                                color: Colors.white54,
                                size: 20,
                              ),
                            ),
                          ),
                    ClipRRect(
                      key: ValueKey('cover_${song.id}'),
                      borderRadius: BorderRadius.circular(4),
                      child: Image(
                        image: coverArtProvider(coverUrl),
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 40,
                          height: 40,
                          color: Colors.white12,
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white54,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                title: ScrollingText(
                  text: song.title,
                  style: context.theme.typography.sm.copyWith(
                    color: index == 0 ? widget.accent : Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 0,
                  ),
                  duration: max(5, (song.title.length / 10).ceil()),
                  maxWidth: 100,
                ),
                subtitle: song.artist != null
                    ? Text(
                        song.artist!,
                        style: context.theme.typography.xs.copyWith(
                          color: Colors.white60,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final player = Provider.of<PlayerProvider>(context, listen: false);
    _getAllCoverUrls(player.queue, player);
  }

  void _getAllCoverUrls(List<Song> songs, PlayerProvider player) {
    for (final song in songs) {
      _idToCoverUrlCache.putIfAbsent(
        song.id,
        () => player.coverArtUrlForSong(song) ?? '',
      );
    }
  }
}
