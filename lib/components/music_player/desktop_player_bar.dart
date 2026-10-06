import 'dart:async';
import 'dart:ui';

import 'package:cosmodrome/components/desktop/desktop_song_popover.dart';
import 'package:cosmodrome/components/music_player/desktop_side_panel.dart';
import 'package:cosmodrome/components/scrolling_text.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/lyrics_provider.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/utils/cover_art/cover_art_provider.dart';
import 'package:cosmodrome/utils/format_duration.dart';
import 'package:cosmodrome/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

const Duration _kAccentDuration = Duration(milliseconds: 400);
const double _kBarHeight = 64;
const double _kBarRadius = 32;
const double _kCoverSize = 44;
const double _kVolumeSliderWidth = 110;

class DesktopPlayerBar extends StatefulWidget {
  final DesktopSidePanelMode? panelMode;
  final VoidCallback onToggleLyrics;
  final VoidCallback onToggleQueue;

  const DesktopPlayerBar({
    super.key,
    required this.panelMode,
    required this.onToggleLyrics,
    required this.onToggleQueue,
  });

  @override
  State<DesktopPlayerBar> createState() => _DesktopPlayerBarState();
}

class _BarIconButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final bool active;
  final bool emphasised;
  final bool dimmed;
  final Color accent;
  final VoidCallback? onTap;

  const _BarIconButton({
    required this.icon,
    required this.size,
    required this.accent,
    this.active = false,
    this.emphasised = false,
    this.dimmed = false,
    this.onTap,
  });

  @override
  State<_BarIconButton> createState() => _BarIconButtonState();
}

class _BarIconButtonState extends State<_BarIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final enabled = widget.onTap != null;

    final Color color;
    if (!enabled) {
      color = colors.mutedForeground.withValues(alpha: 0.4);
    } else if (_pressed || widget.active) {
      color = widget.accent;
    } else if (widget.dimmed) {
      color = colors.mutedForeground.withValues(alpha: _hovered ? 0.8 : 0.5);
    } else if (widget.emphasised || _hovered) {
      color = colors.foreground;
    } else {
      color = colors.mutedForeground;
    }

    final Color background;
    if (enabled && widget.active) {
      background = widget.accent.withValues(alpha: _hovered ? 0.24 : 0.16);
    } else if (enabled && _hovered) {
      background = colors.foreground.withValues(alpha: 0.07);
    } else {
      background = Colors.transparent;
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Icon(
                widget.icon,
                key: ValueKey(widget.icon),
                size: widget.size,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final String? coverUrl;

  const _Cover({required this.coverUrl});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final placeholder = Container(
      width: _kCoverSize,
      height: _kCoverSize,
      color: colors.muted,
      child: Icon(Icons.album, color: colors.mutedForeground, size: 20),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: coverUrl != null
            ? Image(
                image: coverArtProvider(coverUrl!),
                width: _kCoverSize,
                height: _kCoverSize,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => placeholder,
              )
            : placeholder,
      ),
    );
  }
}

class _DesktopPlayerBarState extends State<DesktopPlayerBar>
    with SingleTickerProviderStateMixin {
  // buttons fade out first, then the slider expands into their space
  late final AnimationController _volumeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Animation<double> _buttonsFade = CurvedAnimation(
    parent: _volumeController,
    curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    reverseCurve: const Interval(0.0, 0.4, curve: Curves.easeOut),
  );
  late final Animation<double> _sliderExpand = CurvedAnimation(
    parent: _volumeController,
    curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
    reverseCurve: const Interval(0.4, 1.0, curve: Curves.easeInCubic),
  );

  late final Animation<double> _buttonsSize = ReverseAnimation(_sliderExpand);

  Timer? _collapseTimer;

  bool get _volumeOpen =>
      _volumeController.status == AnimationStatus.forward ||
      _volumeController.status == AnimationStatus.completed;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final song = context.select<PlayerProvider, Song?>((p) => p.currentSong);
    final isPlaying = context.select<PlayerProvider, bool>((p) => p.isPlaying);
    final shuffle = context.select<PlayerProvider, bool>((p) => p.shuffle);
    final repeatMode = context.select<PlayerProvider, LoopMode>(
      (p) => p.repeatMode,
    );
    final volume = context.select<PlayerProvider, double>((p) => p.volume);
    final accentColor = context.select<PlayerProvider, Color?>(
      (p) => p.accentColor,
    );
    final prevAccentColor = context.select<PlayerProvider, Color?>(
      (p) => p.prevAccentColor,
    );
    final hasLyrics = context.select<LyricsProvider, bool>((p) => p.hasLyrics);
    final player = context.read<PlayerProvider>();
    final hasSong = song != null;
    final accent = accentColor ?? colors.primary;

    return MouseRegion(
      onEnter: (_) => _collapseTimer?.cancel(),
      onExit: (_) => _scheduleVolumeCollapse(),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kBarRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_kBarRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.background.withValues(alpha: 0.6),
                border: Border.all(color: colors.border, width: 1),
                borderRadius: BorderRadius.circular(_kBarRadius),
              ),
              child: SizedBox(
                height: _kBarHeight,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    begin: prevAccentColor ?? accent,
                    end: accent,
                  ),
                  duration: _kAccentDuration,
                  builder: (context, animatedAccent, _) {
                    final tint = animatedAccent ?? accent;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          _buildTransport(
                            player: player,
                            hasSong: hasSong,
                            isPlaying: isPlaying,
                            shuffle: shuffle,
                            repeatMode: repeatMode,
                            accent: tint,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: hasSong
                                ? _NowPlaying(song: song, accent: tint)
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(width: 12),
                          _buildRightGroup(
                            player: player,
                            volume: volume,
                            hasLyrics: hasLyrics,
                            accent: tint,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _volumeController.dispose();
    super.dispose();
  }

  Widget _buildRightGroup({
    required PlayerProvider player,
    required double volume,
    required bool hasLyrics,
    required Color accent,
  }) {
    final panelButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BarIconButton(
          icon: FIcons.messageSquareQuote,
          size: 18,
          active: widget.panelMode == DesktopSidePanelMode.lyrics,
          dimmed: !hasLyrics,
          accent: accent,
          onTap: widget.onToggleLyrics,
        ),
        const SizedBox(width: 2),
        _BarIconButton(
          icon: FIcons.listMusic,
          size: 18,
          active: widget.panelMode == DesktopSidePanelMode.queue,
          accent: accent,
          onTap: widget.onToggleQueue,
        ),
        const SizedBox(width: 2),
      ],
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _volumeController,
          child: panelButtons,
          builder: (context, child) {
            final fade = _buttonsFade.value;
            return SizeTransition(
              axis: Axis.horizontal,
              alignment: Alignment.centerRight,
              sizeFactor: _buttonsSize,
              child: IgnorePointer(
                ignoring: fade > 0.5,
                child: Opacity(
                  opacity: 1 - fade,
                  child: Transform.translate(
                    offset: Offset(-16 * fade, 0),
                    child: child,
                  ),
                ),
              ),
            );
          },
        ),
        SizeTransition(
          axis: Axis.horizontal,
          alignment: Alignment.centerRight,
          sizeFactor: _sliderExpand,
          child: FadeTransition(
            opacity: _sliderExpand,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: SizedBox(
                width: _kVolumeSliderWidth,
                child: _ThinSlider(value: volume, onChanged: player.setVolume),
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _volumeController,
          builder: (context, _) => _BarIconButton(
            icon: _volumeIcon(volume),
            size: 20,
            active: _volumeOpen,
            accent: accent,
            onTap: _toggleVolume,
          ),
        ),
      ],
    );
  }

  Widget _buildTransport({
    required PlayerProvider player,
    required bool hasSong,
    required bool isPlaying,
    required bool shuffle,
    required LoopMode repeatMode,
    required Color accent,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BarIconButton(
          icon: Icons.shuffle_rounded,
          size: 18,
          active: shuffle,
          accent: accent,
          onTap: hasSong ? player.toggleShuffle : null,
        ),
        const SizedBox(width: 2),
        _BarIconButton(
          icon: Icons.fast_rewind_rounded,
          size: 24,
          accent: accent,
          onTap: hasSong ? player.skipPrevious : null,
        ),
        const SizedBox(width: 2),
        _BarIconButton(
          icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 30,
          emphasised: true,
          accent: accent,
          onTap: hasSong ? player.togglePlay : null,
        ),
        const SizedBox(width: 2),
        _BarIconButton(
          icon: Icons.fast_forward_rounded,
          size: 24,
          accent: accent,
          onTap: hasSong ? player.skipNext : null,
        ),
        const SizedBox(width: 2),
        _BarIconButton(
          icon: repeatMode == LoopMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          size: 18,
          active: repeatMode != LoopMode.off,
          accent: accent,
          onTap: hasSong ? player.toggleRepeat : null,
        ),
      ],
    );
  }

  void _scheduleVolumeCollapse() {
    _collapseTimer?.cancel();
    if (!_volumeOpen) return;
    _collapseTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (_volumeOpen) _volumeController.reverse();
    });
  }

  void _toggleVolume() {
    _collapseTimer?.cancel();
    if (_volumeOpen) {
      _volumeController.reverse();
    } else {
      _volumeController.forward();
    }
  }

  static IconData _volumeIcon(double volume) {
    if (volume <= 0) return Icons.volume_off_rounded;
    if (volume < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }
}

class _NowPlaying extends StatefulWidget {
  final Song song;
  final Color accent;

  const _NowPlaying({required this.song, required this.accent});

  @override
  State<_NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends State<_NowPlaying> {
  static const double _seekRegionHeight = 16;
  static const double _seekBottomGap = 6;
  static const double _topGap = 8;
  static const Duration _hoverDuration = Duration(milliseconds: 180);

  bool _hovered = false;
  bool _seeking = false;
  double _seekValue = 0.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final song = widget.song;
    final coverUrl = context.select<PlayerProvider, String?>(
      (p) => p.currentCoverArtUrl,
    );
    final position = context.select<PlayerProvider, Duration>(
      (p) => p.position,
    );
    final duration = context.select<PlayerProvider, Duration>(
      (p) => p.duration,
    );

    final totalMs = duration.inMilliseconds.toDouble();
    final fraction = _seeking
        ? _seekValue
        : (totalMs > 0
              ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0)
              : 0.0);
    final shownPosition = _seeking
        ? Duration(milliseconds: (_seekValue * totalMs).round())
        : position;
    final showOverlay = _hovered || _seeking;
    final timeStyle = context.theme.typography.xs.copyWith(
      color: colors.foreground,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final showMore = width >= 150;
        final textWidth =
            width - _kCoverSize - 10 - (showMore ? 32 : 0) - (showMore ? 4 : 0);
        final showText = textWidth >= 24;

        final info = Row(
          children: [
            // cover art
            _Cover(coverUrl: coverUrl),
            const SizedBox(width: 10),
            // song title / artist / album
            if (showText)
              SizedBox(
                width: textWidth,
                child: _SongLinks(
                  song: song,
                  child: _SongText(song: song, maxWidth: textWidth),
                ),
              )
            else
              const Spacer(),
            if (showMore) ...[
              const SizedBox(width: 4),
              DesktopSongPopover(
                song: song,
                onGoToAlbum: goToAlbumAction(context, song),
                builder: (context, controller) => _BarIconButton(
                  icon: Icons.more_horiz_rounded,
                  size: 20,
                  accent: widget.accent,
                  onTap: controller.toggle,
                ),
              ),
            ],
          ],
        );

        return Padding(
          padding: const EdgeInsets.only(top: _topGap),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: showOverlay ? 1.0 : 0.0),
                      duration: _hoverDuration,
                      curve: Curves.easeOut,
                      child: info,
                      builder: (context, t, child) => Opacity(
                        opacity: 1 - 0.55 * t,
                        child: ImageFiltered(
                          enabled: t > 0,
                          imageFilter: ImageFilter.blur(
                            sigmaX: 6 * t,
                            sigmaY: 6 * t,
                          ),
                          child: child,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: showOverlay ? 1.0 : 0.0,
                          duration: _hoverDuration,
                          child: Row(
                            children: [
                              Text(
                                formatTrackDuration(shownPosition.inSeconds),
                                style: timeStyle,
                              ),
                              const Spacer(),
                              Text(
                                formatTrackDuration(duration.inSeconds),
                                style: timeStyle,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hovered = true),
                onExit: (_) => setState(() => _hovered = false),
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) =>
                      _beginSeek(e.localPosition.dx, width, totalMs),
                  onPointerMove: (e) => _updateSeek(e.localPosition.dx, width),
                  onPointerUp: (_) => _endSeek(totalMs),
                  onPointerCancel: (_) => _endSeek(totalMs),
                  child: SizedBox(
                    height: _seekRegionHeight,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: _seekBottomGap),
                        child: AnimatedContainer(
                          duration: _hoverDuration,
                          curve: Curves.easeOut,
                          height: showOverlay ? 6 : 2,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: colors.foreground.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: fraction,
                              child: AnimatedContainer(
                                duration: _hoverDuration,
                                decoration: BoxDecoration(
                                  color: showOverlay
                                      ? colors.foreground
                                      : colors.mutedForeground,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _beginSeek(double dx, double width, double totalMs) {
    if (totalMs <= 0) return;
    setState(() {
      _seeking = true;
      _seekValue = _fractionFor(dx, width);
    });
  }

  void _endSeek(double totalMs) {
    if (!_seeking) return;
    final target = Duration(milliseconds: (_seekValue * totalMs).round());
    setState(() => _seeking = false);
    context.read<PlayerProvider>().seekTo(target);
  }

  void _updateSeek(double dx, double width) {
    if (!_seeking) return;
    setState(() => _seekValue = _fractionFor(dx, width));
  }

  static double _fractionFor(double dx, double width) =>
      width <= 0 ? 0.0 : (dx / width).clamp(0.0, 1.0);
}

class _SongLinks extends StatelessWidget {
  final Song song;
  final Widget child;

  const _SongLinks({required this.song, required this.child});

  @override
  Widget build(BuildContext context) {
    final hasAlbum = song.albumId.isNotEmpty;
    final hasArtist = songHasArtist(song);
    if (!hasAlbum && !hasArtist) return child;

    return FPopover(
      popoverAnchor: Alignment.bottomLeft,
      childAnchor: Alignment.topLeft,
      popoverBuilder: (context, controller) => Padding(
        padding: const EdgeInsets.all(4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
          child: FItemGroup(
            children: [
              if (hasAlbum)
                FItem(
                  prefix: const Icon(Icons.album_outlined, size: 16),
                  title: const Text('Go to album'),
                  onPress: () {
                    final router = GoRouter.of(context);
                    controller.hide();
                    openAlbum(router, song.albumId);
                  },
                ),
              if (hasArtist)
                FItem(
                  prefix: const Icon(Icons.person_outline, size: 16),
                  title: const Text('Go to artist'),
                  onPress: () {
                    final goToArtist = goToArtistAction(context, song);
                    controller.hide();
                    goToArtist?.call();
                  },
                ),
            ],
          ),
        ),
      ),
      builder: (context, controller, _) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: controller.toggle,
          child: child,
        ),
      ),
    );
  }
}

class _SongText extends StatelessWidget {
  final Song song;
  final double maxWidth;

  const _SongText({required this.song, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final subtitle = [
      if (song.artist?.isNotEmpty == true) song.artist!,
      if (song.album?.isNotEmpty == true) song.album!,
    ].join(' — ');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScrollingText(
          text: song.title,
          maxWidth: maxWidth,
          style: typography.sm.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.foreground,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 1),
          ScrollingText(
            text: subtitle,
            maxWidth: maxWidth,
            style: typography.xs.copyWith(color: colors.mutedForeground),
          ),
        ],
      ],
    );
  }
}

class _ThinSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double>? onChanged;

  const _ThinSlider({required this.value, this.onChanged});

  @override
  State<_ThinSlider> createState() => _ThinSliderState();
}

class _ThinSliderState extends State<_ThinSlider> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final active = _hovered ? colors.foreground : colors.mutedForeground;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: 3,
          activeTrackColor: active,
          inactiveTrackColor: colors.foreground.withValues(alpha: 0.12),
          disabledActiveTrackColor: colors.mutedForeground.withValues(
            alpha: 0.4,
          ),
          disabledInactiveTrackColor: colors.foreground.withValues(alpha: 0.08),
          thumbColor: colors.foreground,
          overlayColor: Colors.transparent,
          thumbShape: _hovered
              ? const RoundSliderThumbShape(
                  enabledThumbRadius: 5,
                  elevation: 0,
                  pressedElevation: 0,
                )
              : SliderComponentShape.noThumb,
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
          trackShape: const RoundedRectSliderTrackShape(),
        ),
        child: SizedBox(
          height: 18,
          child: Slider(
            value: widget.value.clamp(0.0, 1.0),
            onChanged: widget.onChanged,
          ),
        ),
      ),
    );
  }
}
