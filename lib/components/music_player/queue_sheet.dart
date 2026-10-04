/*
  MOBILE ONLY
  QUEUE SHEET

  USE SIDEBAR/SIDE SHEET FOR DESKTOP
*/
import 'dart:math';

import 'package:cosmodrome/components/music_player/queue_keys.dart';
import 'package:cosmodrome/components/scrolling_text.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/cover_art/cover_art_provider.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

class QueueSheet extends StatefulWidget {
  final VoidCallback? onClose;

  const QueueSheet({super.key, this.onClose});

  @override
  State<QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends State<QueueSheet> {
  final Map<String, String> _idToCoverUrlCache = {};

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              child: SizedBox(
                height: 20,
                child: Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.theme.colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Queue',
                  style: context.theme.typography.xl.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.theme.colors.foreground,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Selector<PlayerProvider, (int, int)>(
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
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                    );
                  }

                  final keys = queueItemKeys(queue);
                  return ReorderableListView.builder(
                    key: const Key('queue_list'),
                    buildDefaultDragHandles: false,
                    itemCount: queue.length,
                    onReorderItem: (oldIndex, newIndex) {
                      if (oldIndex == 0) return;
                      final target = newIndex < 1 ? 1 : newIndex;
                      player.reorderQueue(
                        oldIndex + queueOffset,
                        (target > oldIndex ? target + 1 : target) + queueOffset,
                      );
                    },
                    itemBuilder: (context, index) {
                      final song = queue[index];
                      final absoluteIndex = queueOffset + index;
                      final coverUrl = _idToCoverUrlCache.putIfAbsent(
                        song.id,
                        () => player.coverArtUrlForSong(song) ?? '',
                      );
                      final colors = context.theme.colors;

                      return Dismissible(
                        key: keys[index],
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          color: colors.destructive,
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (_) =>
                            player.removeFromQueue(absoluteIndex),
                        child: ListTile(
                          contentPadding: const EdgeInsets.only(
                            left: 4,
                            right: 16,
                          ),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              index == 0
                                  ? const SizedBox(width: 40)
                                  : ReorderableDragStartListener(
                                      index: index,
                                      child: SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: Icon(
                                          Icons.drag_indicator_rounded,
                                          color: colors.mutedForeground,
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
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: 40,
                                        height: 40,
                                        color: colors.muted,
                                        child: Icon(
                                          Icons.music_note,
                                          color: colors.mutedForeground,
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
                              color: index == 0
                                  ? colors.primary
                                  : colors.foreground,
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
                                    color: colors.mutedForeground,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final player = Provider.of<PlayerProvider>(context, listen: false);
    _getAllCoverUrls(player.queue, player);
  }

  @override
  void initState() {
    super.initState();
    final player = Provider.of<PlayerProvider>(context, listen: false);
    _getAllCoverUrls(player.queue, player);
  }

  void _getAllCoverUrls(List<Song> songs, PlayerProvider player) {
    for (final song in songs) {
      if (!_idToCoverUrlCache.containsKey(song.id)) {
        _idToCoverUrlCache[song.id] = player.coverArtUrlForSong(song) ?? '';
      }
    }
  }
}
