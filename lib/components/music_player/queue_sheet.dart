/*
  MOBILE ONLY 
  QUEUE SHEET

  USE SIDEBAR/SIDE SHEET FOR DESKTOP
*/
import 'dart:math';

import 'package:cosmodrome/components/scrolling_text.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Consumer<PlayerProvider>(
          builder: (context, player, _) {
            final queue = player.queue;

            return Column(
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
                  child: ReorderableListView.builder(
                    itemCount: queue.length,
                    onReorder: player.reorderQueue,
                    itemBuilder: (context, index) {
                      final song = queue[index];
                      return ListTile(
                        key: ValueKey('${song.id}_$index'),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            player.currentCoverArtUrl ?? '',
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) =>
                                Container(color: Colors.white24),
                          ),
                        ),
                        title: ScrollingText(
                          text: song.title,
                          style: context.theme.typography.sm.copyWith(
                            color: context.theme.colors.foreground,
                            fontWeight: FontWeight.w500,
                            height: 0
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
                              onPressed: () => player.removeFromQueue(index),
                            ),
                           
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
