import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

class DesktopPlayerBar extends StatefulWidget {
  final VoidCallback? onQueueToggle;

  const DesktopPlayerBar({super.key, this.onQueueToggle});

  @override
  State<DesktopPlayerBar> createState() => _DesktopPlayerBarState();
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _CtrlBtn({required this.icon, this.active = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return IconButton(
      icon: Icon(
        icon,
        size: 20,
        color: active ? colors.primary : colors.mutedForeground,
      ),
      onPressed: onTap,
      splashRadius: 16,
    );
  }
}

class _DesktopPlayerBarState extends State<DesktopPlayerBar> {
  bool _seeking = false;
  double _seekValue = 0.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;

    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        final hasSong = song != null;

        final totalMs = player.duration.inMilliseconds.toDouble();
        final posMs = player.position.inMilliseconds.toDouble();
        final sliderValue = _seeking
            ? _seekValue
            : (totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0);

        return Container(
          decoration: BoxDecoration(color: AppColors.background),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress bar with timestamps
              Padding(
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 8,
                  bottom: 8,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        hasSong ? _fmt(player.position) : '0:00',
                        style: context.theme.typography.xs.copyWith(
                          color: colors.mutedForeground,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      child: Theme(
                        data: context.theme
                            .toApproximateMaterialTheme()
                            .copyWith(
                              sliderTheme: SliderThemeData(
                                thumbColor: Colors.white,
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white24,
                                overlayColor: Colors.white12,
                                thumbShape: SliderComponentShape.noThumb,
                                trackHeight: 2,
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 10,
                                ),
                              ),
                            ),
                        child: SizedBox(
                          height: 20,
                          child: Slider(
                            value: sliderValue,
                            min: 0.0,
                            max: 1.0,
                            onChangeStart: hasSong
                                ? (v) => setState(() {
                                    _seeking = true;
                                    _seekValue = v;
                                  })
                                : null,
                            onChanged: hasSong
                                ? (v) => setState(() => _seekValue = v)
                                : null,
                            onChangeEnd: hasSong
                                ? (v) {
                                    setState(() => _seeking = false);
                                    player.seekTo(
                                      Duration(
                                        milliseconds: (v * totalMs).round(),
                                      ),
                                    );
                                  }
                                : null,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        hasSong ? _fmt(player.duration) : '0:00',
                        style: context.theme.typography.xs.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Controls row
              SizedBox(
                height: 60,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // LEFT: playback controls
                    SizedBox(
                      width: 220,
                      child: Opacity(
                        opacity: hasSong ? 1.0 : 0.4,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _CtrlBtn(
                              icon: Icons.shuffle_rounded,
                              active: player.shuffle,
                              onTap: hasSong ? player.toggleShuffle : null,
                            ),
                            _CtrlBtn(
                              icon: Icons.skip_previous_rounded,
                              onTap: hasSong ? player.skipPrevious : null,
                            ),
                            _PlayPauseBtn(
                              isPlaying: player.isPlaying,
                              onTap: hasSong ? player.togglePlay : null,
                            ),
                            _CtrlBtn(
                              icon: Icons.skip_next_rounded,
                              onTap: hasSong ? player.skipNext : null,
                            ),
                            _CtrlBtn(
                              icon: Icons.repeat_rounded,
                              active: player.repeat,
                              onTap: hasSong ? player.toggleRepeat : null,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // center - song details
                    Expanded(
                      child: hasSong
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: player.currentCoverArtUrl != null
                                      ? Image.network(
                                          player.currentCoverArtUrl!,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) =>
                                              _coverPlaceholder(40),
                                        )
                                      : _coverPlaceholder(40),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    // song title
                                    children: [
                                      Text(
                                        song.title,
                                        style: context.theme.typography.xs
                                            .copyWith(
                                              fontWeight: FontWeight.w400,
                                              color: Colors.white,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        [
                                          if (song.artist != null &&
                                              song.artist!.isNotEmpty)
                                            song.artist!,
                                          if (song.album != null &&
                                              song.album!.isNotEmpty)
                                            song.album!,
                                        ].join(' · '),
                                        style: context.theme.typography.xs
                                            .copyWith(
                                              color: colors.mutedForeground,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),

                    // timestamps and volume
                    SizedBox(
                      width: 220,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            if (widget.onQueueToggle != null)
                              _CtrlBtn(
                                icon: FIcons.listMusic,
                                onTap: widget.onQueueToggle,
                              ),
                            Icon(
                              Icons.volume_up_rounded,
                              size: 16,
                              color: colors.mutedForeground,
                            ),
                            Expanded(
                              child: Theme(
                                data: context.theme
                                    .toApproximateMaterialTheme()
                                    .copyWith(
                                      sliderTheme: const SliderThemeData(
                                        thumbColor: Colors.white,
                                        activeTrackColor: Colors.white,
                                        inactiveTrackColor: Colors.white24,
                                        overlayColor: Colors.white12,
                                        thumbShape: RoundSliderThumbShape(
                                          enabledThumbRadius: 5,
                                        ),
                                        trackHeight: 2,
                                        overlayShape: RoundSliderOverlayShape(
                                          overlayRadius: 10,
                                        ),
                                      ),
                                    ),
                                child: Slider(
                                  value: player.volume,
                                  min: 0.0,
                                  max: 1.0,
                                  onChanged: (v) => player.setVolume(v),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _coverPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[800],
      child: Icon(Icons.album, color: Colors.white38, size: size * 0.4),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _PlayPauseBtn extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback? onTap;

  const _PlayPauseBtn({required this.isPlaying, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: 34,
        height: 34,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
