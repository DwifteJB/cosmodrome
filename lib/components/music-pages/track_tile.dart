import 'package:cosmodrome/components/desktop_song_popover.dart';
import 'package:cosmodrome/components/song_context_sheet.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/tap_area.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

String formatTrackDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

class MusicPageDesktopTrackTile extends StatefulWidget {
  final Song song;
  final int trackNumber;
  final int? index;
  final String? albumArtist;
  final Color? accentColor;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const MusicPageDesktopTrackTile({
    super.key,
    required this.song,
    required this.trackNumber,
    this.index,
    this.albumArtist,
    this.accentColor,
    this.enabled = true,
    this.onTap,
    this.onRemove,
  });

  @override
  State<MusicPageDesktopTrackTile> createState() =>
      _MusicPageDesktopTrackTileState();
}

class MusicPageMobileTrackTile extends StatefulWidget {
  final Song song;
  final int trackNumber;
  final int? index;
  final Color accentColor;
  final String? albumArtist;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool showDragHandle;
  final int? reorderIndex;

  const MusicPageMobileTrackTile({
    super.key,
    required this.song,
    required this.trackNumber,
    required this.accentColor,
    this.index,
    this.albumArtist,
    this.enabled = true,
    this.onTap,
    this.onRemove,
    this.showDragHandle = false,
    this.reorderIndex,
  }) : assert(
         !showDragHandle || reorderIndex != null,
         'reorderIndex must be provided when showDragHandle is true',
       );

  @override
  State<MusicPageMobileTrackTile> createState() =>
      _MusicPageMobileTrackTileState();
}

class _MusicPageDesktopTrackTileState extends State<MusicPageDesktopTrackTile> {
  bool _isHovered = false;

  bool get isPlaying {
    final player = context.watch<PlayerProvider>();
    return player.currentSong?.id == widget.song.id;
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final trackLabel = widget.trackNumber > 0 ? '${widget.trackNumber}' : '—';
    final showArtist =
        song.artist != null &&
        song.artist!.isNotEmpty &&
        song.artist != widget.albumArtist;
    final hoverBg = context.theme.colors.secondary.withValues(alpha: 0.2);
    final isOdd = (widget.index ?? widget.trackNumber) % 2 != 0;
    final rowBg = isOdd ? const Color(0x0DFFFFFF) : Colors.transparent;
    final disabledText = context.theme.colors.mutedForeground;

    return GestureDetector(
      onTap: widget.enabled
          ? (widget.onTap ?? () => context.read<PlayerProvider>().playNow(song))
          : null,
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) {
          if (widget.enabled) setState(() => _isHovered = true);
        },
        onExit: (_) {
          if (widget.enabled) setState(() => _isHovered = false);
        },
        child: Container(
          color: widget.enabled && _isHovered ? hoverBg : rowBg,
          child: Opacity(
            opacity: widget.enabled ? 1.0 : 0.45,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    trackLabel,
                    style: context.theme.typography.xs.copyWith(
                        color: widget.enabled
                            ? AppColors.trackNumber
                            : disabledText,
                      letterSpacing: -0.5,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: context.theme.typography.sm.copyWith(
                            color: !widget.enabled
                                ? disabledText
                                : (isPlaying
                                      ? widget.accentColor
                                      : context.theme.colors.foreground),
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showArtist)
                        Text(
                          song.artist!,
                          style: context.theme.typography.xs.copyWith(
                              color: widget.enabled
                                  ? AppColors.trackNumber
                                  : disabledText,
                            letterSpacing: -0.05,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (song.duration != null)
                  Text(
                    formatTrackDuration(song.duration!),
                    style: context.theme.typography.sm.copyWith(
                        color: widget.enabled
                            ? context.theme.colors.mutedForeground
                            : disabledText,
                    ),
                  ),
                const SizedBox(width: 8),
                  if (widget.enabled)
                    DesktopSongPopover(
                      song: song,
                      onRemoveFromPlaylist: widget.onRemove,
                      builder: (context, controller) => AnimatedOpacity(
                        opacity: _isHovered ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 150),
                        child: IconButton(
                          icon: Icon(
                            Icons.more_horiz,
                            size: 16,
                            color: context.theme.colors.mutedForeground,
                          ),
                          onPressed: controller.toggle,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

class _MusicPageMobileTrackTileState extends State<MusicPageMobileTrackTile> {
  bool get isPlaying {
    final player = context.watch<PlayerProvider>();
    return player.currentSong?.id == widget.song.id;
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final trackLabel = widget.trackNumber > 0 ? '${widget.trackNumber}' : '—';
    final artistText = song.artist?.isNotEmpty == true
        ? song.artist
        : widget.albumArtist;

    return Dismissible(
      key: ValueKey(
        'mobile-track-${song.id}-${widget.trackNumber}-${widget.reorderIndex ?? 'na'}',
      ),
      direction: widget.enabled
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: context.theme.colors.secondary,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music, color: context.theme.colors.foreground),
            const SizedBox(width: 8),
            Text(
              'Add to queue',
              style: context.theme.typography.sm.copyWith(
                color: context.theme.colors.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (!widget.enabled) return false;
        if (direction != DismissDirection.endToStart) {
          return false;
        }

        await context.read<PlayerProvider>().addToQueue(song);
        if (!mounted) return false;

        // ignore: use_build_context_synchronously
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Added to queue'),
            duration: Duration(milliseconds: 1100),
          ),
        );

        // keep the item in the list after queuing.
        return false;
      },
      child: TapArea(
        onTap: widget.enabled
            ? (widget.onTap ??
                  () => context.read<PlayerProvider>().playNow(song))
            : null,
        onLongTap: widget.enabled
            ? () => showSongContextSheet(
                context,
                song,
                onRemoveFromPlaylist: widget.onRemove,
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  trackLabel,
                  style: context.theme.typography.xs.copyWith(
                    color: widget.enabled
                        ? AppColors.trackNumber
                        : context.theme.colors.mutedForeground,
                    letterSpacing: -0.5,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: context.theme.typography.sm.copyWith(
                        color: !widget.enabled
                            ? context.theme.colors.mutedForeground
                            : (isPlaying
                                  ? widget.accentColor
                                  : context.theme.colors.foreground),
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.05,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (artistText != null && artistText.isNotEmpty)
                      Text(
                        artistText,
                        style: context.theme.typography.xs.copyWith(
                          color: widget.enabled
                              ? AppColors.trackNumber
                              : context.theme.colors.mutedForeground,
                          letterSpacing: -0.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (song.duration != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    formatTrackDuration(song.duration!),
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ),
              if (widget.showDragHandle) ...[
                const SizedBox(width: 8),
                ReorderableDragStartListener(
                  index: widget.reorderIndex!,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.drag_handle,
                      size: 20,
                      color: AppColors.trackNumber,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
