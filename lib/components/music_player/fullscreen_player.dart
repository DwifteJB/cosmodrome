/*
  MOBILE ONLY!! (probably)

  since it uses a sheet, looks ass on desktop, and we have enough space to do all this stuff
*/

import 'package:cosmodrome/components/music_player/queue_sheet.dart';
import 'package:cosmodrome/components/scrolling_text.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

class FullscreenPlayer extends StatefulWidget {
  const FullscreenPlayer({super.key});

  @override
  State<FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<FullscreenPlayer> {
  bool _seeking = false;
  double _seekValue = 0.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Consumer<PlayerProvider>(
          builder: (context, player, _) {
            final song = player.currentSong;
            if (song == null) return const SizedBox.shrink();

            final coverUrl = player.currentCoverArtUrl;

            final totalMs = player.duration.inMilliseconds.toDouble();
            final posMs = player.position.inMilliseconds.toDouble();
            final sliderValue = _seeking
                ? _seekValue
                : (totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // handle bar
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // cover art
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = constraints.maxWidth < constraints.maxHeight
                            ? constraints.maxWidth
                            : constraints.maxHeight;
                        return Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox.square(
                              dimension: size,
                              child: coverUrl != null
                                  ? Image.network(
                                      coverUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) =>
                                          _coverPlaceholder(size),
                                    )
                                  : _coverPlaceholder(size),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // title + artist
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ScrollingText(text: song.title, maxWidth: 400, style: context.theme.typography.md.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 0
                      )),
                     
                      if (song.artist != null && song.artist!.isNotEmpty)
                        Text(
                          song.artist!,
                          style: context.theme.typography.md.copyWith(
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // progress slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Theme(data: context.theme.toApproximateMaterialTheme().copyWith(
                    sliderTheme: SliderThemeData(
                      thumbColor: Colors.white,
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      overlayColor: Colors.white24,
                      thumbShape: SliderComponentShape.noThumb
                    ),
                  ), child: Slider(
                    value: sliderValue,
                    min: 0.0,
                    max: 1.0,
                    
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                    onChangeStart: (v) {
                      setState(() {
                        _seeking = true;
                        _seekValue = v;
                      });
                    },
                    onChanged: (v) => setState(() => _seekValue = v),
                    onChangeEnd: (v) {
                      setState(() => _seeking = false);
                      final seekMs = (v * totalMs).round();
                      player.seekTo(Duration(milliseconds: seekMs));
                    },
                  ),)
                ),
                // timestamps
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmt(player.position),
                        style: context.theme.typography.xs.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                      Text(
                        _fmt(player.duration),
                        style: context.theme.typography.xs.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // playback controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 60,
                      icon: const Icon(
                        Icons.fast_rewind_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => player.skipPrevious(),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      child: Material(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => player.togglePlay(),
                          child: Icon(
                            player.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 60,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      iconSize: 60,
                      icon: const Icon(
                        Icons.fast_forward_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => player.skipNext(),
                    ),
                  ],
                ),
                // queue button
                Center(
                  child: IconButton(
                    icon: const Icon(FIcons.listMusic, color: Colors.white70),
                    onPressed: () => showFSheet(
                      context: context,
                      side: FLayout.btt,
                      mainAxisMaxRatio: 0.7,
                      builder: (_) => const QueueSheet(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
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
