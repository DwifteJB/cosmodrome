import 'dart:io';

import 'package:cosmodrome/components/desktop_titlebar.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

class DesktopQueuePanel extends StatelessWidget {
  final VoidCallback onClose;

  const DesktopQueuePanel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final isMacOS = !kIsWeb && Platform.isMacOS;

    return Material(
      color: AppColors.sidebar,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: colors.border, width: 1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Spacer(),
                  // close button on left for macOS, right for others
                  IconButton(
                    icon: Icon(FIcons.x, size: 14, color: colors.mutedForeground),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  // window controls if open
                  if (!isMacOS) ...[
                    DesktopWindowButton(
                      icon: FIcons.minus,
                      iconSize: 16,
                      onPressed: () {},
                      hoverColor: colors.secondary,
                    ),
                    DesktopWindowButton(
                      icon: FIcons.square,
                      iconSize: 14,
                      onPressed: () {},
                      hoverColor: colors.secondary,
                    ),
                    DesktopWindowButton(
                      icon: FIcons.x,
                      iconSize: 16,
                      onPressed: () {},
                      hoverColor: colors.destructive,
                      hoverIconColor: Colors.white,
                    ),
                  ],
                ],
              ),
            ),
            // queue list
            Expanded(
              child: Selector<PlayerProvider, (List<Song>, String?)>(
                selector: (_, p) => (p.queue, p.currentSong?.id),
                shouldRebuild: (prev, next) =>
                    prev.$2 != next.$2 || prev.$1.length != next.$1.length,
                builder: (context, data, _) {
                  final player = context.read<PlayerProvider>();
                  final queue = data.$1;
                  if (queue.isEmpty) {
                    return Center(
                      child: Text(
                        'Queue is empty',
                        style: context.theme.typography.sm.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: queue.length,
                    itemBuilder: (context, index) {
                      final song = queue[index];
                      return _QueueItem(
                        key: ValueKey(song.id),
                        index: index,
                        player: player,
                        onRemove: () => player.removeFromQueue(index),
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
}

class _QueueItem extends StatefulWidget {
  final int index;
  final PlayerProvider player;
  final VoidCallback onRemove;

  const _QueueItem({
    super.key,
    required this.index,
    required this.player,
    required this.onRemove,
  });

  @override
  State<_QueueItem> createState() => _QueueItemState();
}

class _QueueItemState extends State<_QueueItem> {
  bool _isHovered = false;
  String? _coverUrl;

  @override
  void initState() {
    super.initState();
    _coverUrl = widget.player.coverArtUrlForSong(
      widget.player.queue[widget.index],
    );
  }

  @override
  void didUpdateWidget(_QueueItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final song = widget.player.queue[widget.index];
    final oldSong = oldWidget.player.queue[oldWidget.index];
    if (song.id != oldSong.id) {
      _coverUrl = widget.player.coverArtUrlForSong(song);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final song = widget.player.queue[widget.index];
    final isCurrent = widget.player.currentSong?.id == song.id;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        color: isCurrent
            ? AppColors.sidebarSelected
            : (_isHovered ? colors.secondary.withValues(alpha: 0.3) : Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              // Cover art or track number
              SizedBox(
                width: 32,
                height: 32,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: _coverUrl != null
                      ? Image.network(
                          _coverUrl!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: context.theme.typography.xs.copyWith(
                        color: isCurrent ? colors.primary : colors.foreground,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (song.artist != null && song.artist!.isNotEmpty)
                      Text(
                        song.artist!,
                        style: context.theme.typography.xs.copyWith(
                          color: colors.mutedForeground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (_isHovered)
                IconButton(
                  icon: Icon(FIcons.x, size: 12, color: colors.mutedForeground),
                  onPressed: widget.onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 32,
      height: 32,
      color: Colors.grey[800],
      child: const Icon(Icons.music_note, color: Colors.white38, size: 16),
    );
  }
}
