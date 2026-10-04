import 'dart:async';

import 'package:cosmodrome/components/desktop/desktop_song_popover.dart';
import 'package:cosmodrome/components/mobile/song_context_sheet.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/tap_area.dart';
import 'package:cosmodrome/utils/format_duration.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

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

class MusicPageMobileTrackTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isPlaying = context.select<PlayerProvider, bool>(
      (p) => p.currentSong?.id == song.id,
    );
    final theme = context.theme;
    final colors = theme.colors;
    final trackLabel = trackNumber > 0 ? '$trackNumber' : '—';
    final artistText = song.artist?.isNotEmpty == true
        ? song.artist
        : albumArtist;

    return RepaintBoundary(
      child: Dismissible(
        key: ValueKey(
          'mobile-track-${song.id}-$trackNumber-${reorderIndex ?? 'na'}',
        ),
        direction: enabled
            ? DismissDirection.endToStart
            : DismissDirection.none,
        background: const SizedBox.shrink(),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          color: colors.secondary,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.queue_music, color: colors.foreground),
              const SizedBox(width: 8),
              Text(
                'Add to queue',
                style: theme.typography.sm.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        confirmDismiss: (_) async {
          await context.read<PlayerProvider>().addToQueue(song);
          if (!context.mounted) return false;

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
          onTap: enabled
              ? (onTap ?? () => context.read<PlayerProvider>().playNow(song))
              : null,
          onLongTap: enabled
              ? () => showSongContextSheet(
                  context,
                  song,
                  onRemoveFromPlaylist: onRemove,
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
                    style: theme.typography.xs.copyWith(
                      color: enabled
                          ? AppColors.trackNumber
                          : colors.mutedForeground,
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
                        style: theme.typography.sm.copyWith(
                          color: !enabled
                              ? colors.mutedForeground
                              : (isPlaying ? accentColor : colors.foreground),
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (artistText != null && artistText.isNotEmpty)
                        Text(
                          artistText,
                          style: theme.typography.xs.copyWith(
                            color: enabled
                                ? AppColors.trackNumber
                                : colors.mutedForeground,
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
                      style: theme.typography.sm.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                  ),
                if (showDragHandle) ...[
                  const SizedBox(width: 8),
                  ReorderableDragStartListener(
                    index: reorderIndex!,
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
      ),
    );
  }
}

class _MusicPageDesktopTrackTileState extends State<MusicPageDesktopTrackTile> {
  bool _isHovered = false;

  bool _menuMounted = false;
  bool _menuOpen = false;
  Timer? _menuUnmountTimer;

  @override
  void dispose() {
    _menuUnmountTimer?.cancel();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    if (!widget.enabled) return;
    setState(() {
      _isHovered = hovered;
      if (hovered) _menuMounted = true;
    });
    if (!hovered) _scheduleMenuUnmount();
  }

  void _onMenuShownChanged(bool shown) {
    _menuOpen = shown;
    if (!shown) _scheduleMenuUnmount();
  }

  void _scheduleMenuUnmount() {
    _menuUnmountTimer?.cancel();
    _menuUnmountTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || _isHovered || _menuOpen || !_menuMounted) return;
      setState(() => _menuMounted = false);
    });
  }

  /// "More" button that opens the song popover. The popover is only mounted
  /// while the row is hovered (or its menu is open) to keep long lists cheap.
  Widget _buildMenuButton(FColors colors) {
    if (!_menuMounted) return const SizedBox.square(dimension: 28);

    return DesktopSongPopover(
      song: widget.song,
      onRemoveFromPlaylist: widget.onRemove,
      onShownChanged: _onMenuShownChanged,
      builder: (context, controller) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: _isHovered ? 1 : 0),
        duration: const Duration(milliseconds: 150),
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child: IconButton(
          icon: Icon(Icons.more_horiz, size: 16, color: colors.mutedForeground),
          onPressed: controller.toggle,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;

    final isPlaying = context.select<PlayerProvider, bool>(
      (p) => p.currentSong?.id == song.id,
    );
    final theme = context.theme;
    final colors = theme.colors;
    final trackLabel = widget.trackNumber > 0 ? '${widget.trackNumber}' : '—';
    final showArtist =
        song.artist != null &&
        song.artist!.isNotEmpty &&
        song.artist != widget.albumArtist;
    final hoverBg = colors.secondary.withValues(alpha: 0.2);
    final isOdd = (widget.index ?? widget.trackNumber) % 2 != 0;
    final rowBg = isOdd ? const Color(0x0DFFFFFF) : Colors.transparent;

    final disabledText = colors.mutedForeground.withValues(
      alpha: colors.mutedForeground.a * 0.45,
    );

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.enabled
            ? (widget.onTap ??
                  () => context.read<PlayerProvider>().playNow(song))
            : null,
        child: MouseRegion(
          cursor: widget.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          child: ColoredBox(
            color: widget.enabled && _isHovered ? hoverBg : rowBg,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      trackLabel,
                      style: theme.typography.xs.copyWith(
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
                          style: theme.typography.sm.copyWith(
                            color: !widget.enabled
                                ? disabledText
                                : (isPlaying
                                      ? widget.accentColor
                                      : colors.foreground),
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.05,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (showArtist)
                          Text(
                            song.artist!,
                            style: theme.typography.xs.copyWith(
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
                      style: theme.typography.sm.copyWith(
                        color: widget.enabled
                            ? colors.mutedForeground
                            : disabledText,
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (widget.enabled) _buildMenuButton(colors),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
