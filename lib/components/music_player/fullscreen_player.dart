/*
  MOBILE ONLY!! (probably)

  since it uses a sheet, looks ass on desktop, and we have enough space to do all this stuff
*/

import 'package:cosmodrome/components/music_player/queue_sheet.dart';
import 'package:cosmodrome/components/scrolling_text.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

class FullscreenPlayer extends StatefulWidget {
  const FullscreenPlayer({super.key});

  @override
  State<FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<FullscreenPlayer> {
  bool _seeking = false;
  double _seekValue = 0.0;

  Color? _accentColor;
  Color? _prevAccentColor;
  String? _cacheId;

  @override
  Widget build(BuildContext context) {
    // Read directly from the FlutterView so the sheet's MediaQuery override
    // (useSafeArea: false zeros out padding.top) doesn't affect us.
    final view = View.of(context);
    final topPadding = view.padding.top / view.devicePixelRatio;
    final screenHeight = MediaQuery.of(context).size.height;

    return Material(
      color: AppColors.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.7,
            child: IgnorePointer(
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(begin: _prevAccentColor, end: _accentColor),
                duration: _prevAccentColor != null
                    ? const Duration(milliseconds: 700)
                    : Duration.zero,
                curve: Curves.easeIn,
                builder: (context, color, _) {
                  if (color == null) return const SizedBox.expand();
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.55),
                          color.withValues(alpha: 0.30),
                          AppColors.background.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.15, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // content column
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: topPadding + 16),
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
                const SizedBox(height: 24),

                Expanded(
                  child: SafeArea(
                    top: false,
                    child: Consumer<PlayerProvider>(
                      builder: (context, player, _) {
                        final song = player.currentSong;
                        if (song == null) return const SizedBox.shrink();

                        final coverUrl = player.currentCoverArtUrl;

                        final totalMs = player.duration.inMilliseconds
                            .toDouble();
                        final posMs = player.position.inMilliseconds.toDouble();
                        final sliderValue = _seeking
                            ? _seekValue
                            : (totalMs > 0
                                  ? (posMs / totalMs).clamp(0.0, 1.0)
                                  : 0.0);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // padding above album art
                            const SizedBox(height: 12),
                            // cover art — square constrained by width, no Expanded
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: coverUrl != null
                                      ? Image.network(
                                          coverUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) {
                                            final size =
                                                MediaQuery.of(
                                                  context,
                                                ).size.width -
                                                64;
                                            return _coverPlaceholder(size);
                                          },
                                        )
                                      : _coverPlaceholder(
                                          MediaQuery.of(context).size.width -
                                              64,
                                        ),
                                ),
                              ),
                            ),
                            // padding above text
                            const SizedBox(height: 32),
                            // title + artist
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ScrollingText(
                                    text: song.title,
                                    maxWidth:
                                        MediaQuery.of(context).size.width - 48,
                                    style: context.theme.typography.lg.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1.2,
                                    ),
                                    duration: 5,
                                  ),
                                  if (song.artist != null &&
                                      song.artist!.isNotEmpty)
                                    Text(
                                      song.artist!,
                                      style: context.theme.typography.sm
                                          .copyWith(color: Colors.white60),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Spacer(),
                            // progress slider
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Theme(
                                data: context.theme
                                    .toApproximateMaterialTheme()
                                    .copyWith(
                                      sliderTheme: SliderThemeData(
                                        thumbColor: Colors.white,
                                        activeTrackColor: Colors.white,
                                        inactiveTrackColor: Colors.white24,
                                        overlayColor: Colors.white24,
                                        thumbShape:
                                            SliderComponentShape.noThumb,
                                        overlayShape: RoundSliderOverlayShape(
                                          overlayRadius: 12,
                                        ),
                                      ),
                                    ),
                                child: Slider(
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
                                  onChanged: (v) =>
                                      setState(() => _seekValue = v),
                                  onChangeEnd: (v) {
                                    setState(() => _seeking = false);
                                    final seekMs = (v * totalMs).round();
                                    player.seekTo(
                                      Duration(milliseconds: seekMs),
                                    );
                                  },
                                ),
                              ),
                            ),
                            // timestamps
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _fmt(player.position),
                                    style: context.theme.typography.xs.copyWith(
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    _fmt(player.duration),
                                    style: context.theme.typography.xs.copyWith(
                                      color: Colors.white,
                                      letterSpacing: -0.5,
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
                            const Spacer(),
                            // queue button
                            Center(
                              child: IconButton(
                                icon: const Icon(
                                  FIcons.listMusic,
                                  color: Colors.white70,
                                ),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final player = Provider.of<PlayerProvider>(context);
    _extractAccentColor(player.currentSong ?? Song(id: '', title: ''));
  }

  @override
  void initState() {
    // if current song changes then we want to extract the accent color from the new song's cover art, so we listen to the player provider for changes and update the accent color accordingly
    super.initState();
    final player = Provider.of<PlayerProvider>(context, listen: false);
    _extractAccentColor(player.currentSong ?? Song(id: '', title: ''));
  }

  Widget _coverPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[800],
      child: Icon(Icons.album, color: Colors.white38, size: size * 0.4),
    );
  }

  Future<Color?> _extractAccentColor(Song song) async {
    final sp = Provider.of<SubsonicProvider>(context, listen: false);
    if (_accentColor != null && _cacheId == song.id) return _accentColor!;

    if (song.coverArt == null) return AppColors.background;
    final saveCoverArtURL = sp.subsonic.cachedCoverArtUrl(song.coverArt!, size: 300);
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(saveCoverArtURL),
        size: const Size(200, 200),
      );

      // Prefer vibrant/light swatches; dark-only art still gets a visible tint.
      final raw =
          generator.vibrantColor?.color ??
          generator.lightVibrantColor?.color ??
          generator.mutedColor?.color ??
          generator.lightMutedColor?.color ??
          generator.dominantColor?.color;

      Color? color;
      if (raw != null) {
        final hsl = HSLColor.fromColor(raw);
        color = hsl.lightness < 0.25 ? hsl.withLightness(0.35).toColor() : raw;
      }

      if (mounted) {
        final prev = _accentColor;
        setState(() {
          _prevAccentColor = prev;
          _accentColor = color;
          _cacheId = song.id;
        });
      }

      return color;
    } catch (_) {}

    return AppColors.background;
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
