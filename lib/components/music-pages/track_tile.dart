import 'package:cosmodrome/components/song_context_sheet.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/utils/colors.dart';
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
  final String? albumArtist;
  final Color? accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const MusicPageDesktopTrackTile({
    super.key,
    required this.song,
    required this.trackNumber,
    this.albumArtist,
    this.accentColor,
    this.onTap,
    this.onRemove,
  });

  @override
  State<MusicPageDesktopTrackTile> createState() =>
      _MusicPageDesktopTrackTileState();
}

class _MusicPageDesktopTrackTileState
    extends State<MusicPageDesktopTrackTile> {
  bool _isHovered = false;

  bool get isPlaying {
    final player = context.watch<PlayerProvider>();
    return player.currentSong?.id == widget.song.id;
  }

  void _openContextMenu() {
    showSongContextSheet(
      context,
      widget.song,
      onRemoveFromPlaylist: widget.onRemove,
    );
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

    return GestureDetector(
      onTap: widget.onTap ?? () => context.read<PlayerProvider>().playNow(song),
      onSecondaryTap: _openContextMenu,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          color: _isHovered ? hoverBg : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    trackLabel,
                    style: context.theme.typography.xs.copyWith(
                      color: AppColors.trackNumber,
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
                          color: isPlaying
                              ? widget.accentColor
                              : context.theme.colors.foreground,
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
                            color: AppColors.trackNumber,
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
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                const SizedBox(width: 8),
                AnimatedOpacity(
                  opacity: _isHovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: IconButton(
                    icon: Icon(
                      Icons.more_horiz,
                      size: 16,
                      color: context.theme.colors.mutedForeground,
                    ),
                    onPressed: _openContextMenu,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MusicPageMobileTrackTile extends StatefulWidget {
  final Song song;
  final int trackNumber;
  final Color accentColor;
  final String? albumArtist;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool showDragHandle;
  final int? reorderIndex;

  const MusicPageMobileTrackTile({
    super.key,
    required this.song,
    required this.trackNumber,
    required this.accentColor,
    this.albumArtist,
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

    return InkWell(
      onTap: widget.onTap ?? () => context.read<PlayerProvider>().playNow(song),
      onLongPress: () => showSongContextSheet(
        context,
        song,
        onRemoveFromPlaylist: widget.onRemove,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                trackLabel,
                style: context.theme.typography.xs.copyWith(
                  color: AppColors.trackNumber,
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
                      color: isPlaying
                          ? widget.accentColor
                          : context.theme.colors.foreground,
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
                        color: AppColors.trackNumber,
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
    );
  }
}
