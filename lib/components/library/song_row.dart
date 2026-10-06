import 'dart:async';

import 'package:cosmodrome/components/desktop/desktop_song_popover.dart';
import 'package:cosmodrome/components/library/song_grid_item.dart';
import 'package:cosmodrome/components/mobile/song_context_sheet.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

class SongRow extends StatelessWidget {
  final Song song;
  final Subsonic subsonic;
  final String? subtitle;
  final Color? playingColor;
  final VoidCallback? onPlay;

  const SongRow({
    super.key,
    required this.song,
    required this.subsonic,
    this.subtitle,
    this.playingColor,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle =
        this.subtitle ??
        [
          if (song.artist?.isNotEmpty == true) song.artist!,
          if (song.album?.isNotEmpty == true) song.album!,
        ].join(' · ');
    final mobile = isMobileView(context);
    final playing =
        playingColor != null &&
        context.select<PlayerProvider, bool>(
          (p) => p.currentSong?.id == song.id,
        );

    return SongGridItem(
      title: song.title,
      subtitle: subtitle,
      titleColor: playing ? playingColor : null,
      imageUrl: song.coverArt != null
          ? subsonic.cachedCoverArtUrl(song.coverArt!, size: 120)
          : null,
      onPlay: onPlay ?? () => context.read<PlayerProvider>().playNow(song),
      onLongPress: mobile ? () => showSongContextSheet(context, song) : null,
      onContextMenu: mobile
          ? null
          : (pos) => showSongContextMenuAt(context, song, pos),
      trailingBuilder: mobile
          ? null
          : (context, hovered) =>
                _SongRowMenuButton(song: song, hovered: hovered),
    );
  }
}

// the ... button, popover only mounted while hovered or open to keep rows cheap
class _SongRowMenuButton extends StatefulWidget {
  final Song song;
  final bool hovered;

  const _SongRowMenuButton({required this.song, required this.hovered});

  @override
  State<_SongRowMenuButton> createState() => _SongRowMenuButtonState();
}

class _SongRowMenuButtonState extends State<_SongRowMenuButton> {
  bool _mounted = false;
  bool _open = false;
  Timer? _unmountTimer;

  @override
  Widget build(BuildContext context) {
    if (!_mounted) return const SizedBox.square(dimension: 28);
    final colors = context.theme.colors;

    return DesktopSongPopover(
      song: widget.song,
      onGoToAlbum: goToAlbumAction(context, widget.song),
      onShownChanged: _onShownChanged,
      builder: (context, controller) => AnimatedOpacity(
        opacity: widget.hovered || _open ? 1 : 0,
        duration: const Duration(milliseconds: 150),
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
  void didUpdateWidget(_SongRowMenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hovered && !_mounted) {
      _unmountTimer?.cancel();
      _mounted = true;
    } else if (!widget.hovered && oldWidget.hovered) {
      _scheduleUnmount();
    }
  }

  @override
  void dispose() {
    _unmountTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _mounted = widget.hovered;
  }

  bool get _visible => ModalRoute.isCurrentOf(context) ?? true;

  void _onShownChanged(bool shown) {
    if (!mounted) return;
    if (_visible) {
      setState(() => _open = shown);
    } else {
      _open = shown;
    }
    if (!shown) _scheduleUnmount();
  }

  void _scheduleUnmount() {
    _unmountTimer?.cancel();
    _unmountTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || widget.hovered || _open || !_mounted) return;
      if (!_visible) return;
      setState(() => _mounted = false);
    });
  }
}
