import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/cover_art/cover_art_provider.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

class DesktopPlayerBar extends StatefulWidget {
  final VoidCallback? onQueueToggle;

  const DesktopPlayerBar({super.key, this.onQueueToggle});

  @override
  State<DesktopPlayerBar> createState() => _DesktopPlayerBarState();
}

class _DesktopPlayerBarState extends State<DesktopPlayerBar> {
  double _volumeBeforeMute = 1.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final song = context.select<PlayerProvider, Song?>((p) => p.currentSong);
    final coverUrl = context.select<PlayerProvider, String?>(
      (p) => p.currentCoverArtUrl,
    );
    final isPlaying = context.select<PlayerProvider, bool>((p) => p.isPlaying);
    final shuffle = context.select<PlayerProvider, bool>((p) => p.shuffle);
    final repeatMode = context.select<PlayerProvider, LoopMode>(
      (p) => p.repeatMode,
    );
    final volume = context.select<PlayerProvider, double>((p) => p.volume);
    final player = context.read<PlayerProvider>();
    final hasSong = song != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SizedBox(
        height: 76,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: hasSong
                    ? _NowPlaying(song: song, coverUrl: coverUrl)
                    : const SizedBox.shrink(),
              ),
              Expanded(
                flex: 4,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _BarIconButton(
                              icon: Icons.shuffle_rounded,
                              size: 18,
                              active: shuffle,
                              onTap: hasSong ? player.toggleShuffle : null,
                            ),
                            const SizedBox(width: 14),
                            _BarIconButton(
                              icon: Icons.fast_rewind_rounded,
                              size: 26,
                              onTap: hasSong ? player.skipPrevious : null,
                            ),
                            const SizedBox(width: 10),
                            _BarIconButton(
                              icon: isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 36,
                              emphasised: true,
                              onTap: hasSong ? player.togglePlay : null,
                            ),
                            const SizedBox(width: 10),
                            _BarIconButton(
                              icon: Icons.fast_forward_rounded,
                              size: 26,
                              onTap: hasSong ? player.skipNext : null,
                            ),
                            const SizedBox(width: 14),
                            _BarIconButton(
                              icon: repeatMode == LoopMode.one
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              size: 18,
                              active: repeatMode != LoopMode.off,
                              onTap: hasSong ? player.toggleRepeat : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        _SeekRow(enabled: hasSong),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.onQueueToggle != null) ...[
                      _BarIconButton(
                        icon: Icons.format_list_bulleted_rounded,
                        size: 18,
                        onTap: widget.onQueueToggle,
                      ),
                      const SizedBox(width: 12),
                    ],
                    _BarIconButton(
                      icon: _volumeIcon(volume),
                      size: 18,
                      onTap: () => _toggleMute(player, volume),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 100,
                      child: _ThinSlider(
                        value: volume,
                        onChanged: player.setVolume,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleMute(PlayerProvider player, double volume) {
    if (volume > 0) {
      _volumeBeforeMute = volume;
      player.setVolume(0);
    } else {
      player.setVolume(_volumeBeforeMute > 0 ? _volumeBeforeMute : 1.0);
    }
  }

  static IconData _volumeIcon(double volume) {
    if (volume <= 0) return Icons.volume_off_rounded;
    if (volume < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }
}

class _NowPlaying extends StatelessWidget {
  final Song song;
  final String? coverUrl;

  const _NowPlaying({required this.song, required this.coverUrl});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final placeholder = Container(
      width: 52,
      height: 52,
      color: colors.muted,
      child: Icon(Icons.album, color: colors.mutedForeground, size: 22),
    );
    final subtitle = [
      if (song.artist?.isNotEmpty == true) song.artist!,
      if (song.album?.isNotEmpty == true) song.album!,
    ].join(' — ');

    return Row(
      children: [
        DecoratedBox(
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
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => placeholder,
                  )
                : placeholder,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                style: context.theme.typography.sm.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colors.foreground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: context.theme.typography.xs.copyWith(
                    color: colors.mutedForeground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SeekRow extends StatefulWidget {
  final bool enabled;

  const _SeekRow({required this.enabled});

  @override
  State<_SeekRow> createState() => _SeekRowState();
}

class _SeekRowState extends State<_SeekRow> {
  bool _seeking = false;
  double _seekValue = 0.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final timeStyle = context.theme.typography.xs.copyWith(
      color: colors.mutedForeground,
      fontSize: 11,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final totalMs = player.duration.inMilliseconds.toDouble();
        final posMs = player.position.inMilliseconds.toDouble();
        final value = _seeking
            ? _seekValue
            : (totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0);
        final shownPosition = _seeking
            ? Duration(milliseconds: (_seekValue * totalMs).round())
            : player.position;

        return Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                widget.enabled ? _fmt(shownPosition) : '0:00',
                style: timeStyle,
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _ThinSlider(
                value: value,
                onChangeStart: widget.enabled
                    ? (v) => setState(() {
                        _seeking = true;
                        _seekValue = v;
                      })
                    : null,
                onChanged: widget.enabled
                    ? (v) => setState(() => _seekValue = v)
                    : null,
                onChangeEnd: widget.enabled
                    ? (v) {
                        setState(() => _seeking = false);
                        player.seekTo(
                          Duration(milliseconds: (v * totalMs).round()),
                        );
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 40,
              child: Text(
                widget.enabled ? _fmt(player.duration) : '0:00',
                style: timeStyle,
              ),
            ),
          ],
        );
      },
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _ThinSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;

  const _ThinSlider({
    required this.value,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
  });

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
            onChangeStart: widget.onChangeStart,
            onChangeEnd: widget.onChangeEnd,
          ),
        ),
      ),
    );
  }
}

class _BarIconButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final bool active;
  final bool emphasised;
  final VoidCallback? onTap;

  const _BarIconButton({
    required this.icon,
    required this.size,
    this.active = false,
    this.emphasised = false,
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
    } else if (widget.active) {
      color = colors.primary;
    } else if (widget.emphasised || _hovered) {
      color = colors.foreground;
    } else {
      color = colors.mutedForeground;
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
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    widget.icon,
                    key: ValueKey(widget.icon),
                    size: widget.size,
                    color: color,
                  ),
                ),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.active ? colors.primary : Colors.transparent,
                    shape: BoxShape.circle,
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
