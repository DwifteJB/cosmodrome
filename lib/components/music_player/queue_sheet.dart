/*
  MOBILE ONLY
  QUEUE SHEET

  USE SIDEBAR/SIDE SHEET FOR DESKTOP
*/
import 'dart:math';

import 'package:cosmodrome/components/scrolling_text.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/cover_art_provider.dart';
import 'package:cosmodrome/utils/tap_area.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

class QueueSheet extends StatefulWidget {
  const QueueSheet({super.key});

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
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: context.theme.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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

                  return ReorderableListView.builder(
                    key: const Key('queue_list'),
                    itemCount: queue.length,
                    onReorder: (oldIndex, newIndex) => player.reorderQueue(
                      oldIndex + queueOffset,
                      newIndex + queueOffset,
                    ),
                    itemBuilder: (context, index) {
                      final song = queue[index];
                      final absoluteIndex = queueOffset + index;
                      final coverUrl = _idToCoverUrlCache.putIfAbsent(
                        song.id,
                        () => player.coverArtUrlForSong(song) ?? '',
                      );

                      return TapArea(
                        key: ValueKey('${song.id}_$absoluteIndex'),
                        onTap: null,
                        child: ListTile(
                          leading: ClipRRect(
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
                                    color: context.theme.colors.muted,
                                    child: Icon(
                                      Icons.music_note,
                                      color:
                                          context.theme.colors.mutedForeground,
                                      size: 20,
                                    ),
                                  ),
                            ),
                          ),
                          title: ScrollingText(
                            text: song.title,
                            style: context.theme.typography.sm.copyWith(
                              color: context.theme.colors.foreground,
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
                                    color: context.theme.colors.mutedForeground,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  color: context.theme.colors.mutedForeground,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    player.removeFromQueue(absoluteIndex),
                              ),
                            ],
                          ),
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
