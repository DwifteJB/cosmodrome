/*
  MOBILE ONLY!! (or web)

  since it uses a sheet, looks ass on desktop, and we have enough space to do all this stuff
*/

import 'dart:ui';

import 'package:cosmodrome/components/music_player/queue_sheet.dart';
import 'package:cosmodrome/components/scrolling_text.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/utils/cover_art_provider.dart';
import 'package:cosmodrome/utils/tap_area.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

class FullscreenPlayer extends StatefulWidget {
  const FullscreenPlayer({super.key});

  @override
  State<FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FadingAlbumArt extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  const _FadingAlbumArt({
    required this.imageUrl,
    required this.fit,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [...previousChildren, ?currentChild],
        );
      },
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Image(
        image: coverArtProvider(imageUrl),
        key: ValueKey(imageUrl),
        fit: fit,
        errorBuilder: errorBuilder != null
            ? (context, error, stackTrace) => errorBuilder!(context, error)
            : null,
      ),
    );
  }
}

class _FullscreenPlayerState extends State<FullscreenPlayer> {
  bool _seeking = false;
  double _seekValue = 0.0;

  bool _isStarred = false;
  String? _starredSongId;

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final topPadding = view.padding.top / view.devicePixelRatio;
    final bottomPadding = view.padding.bottom / view.devicePixelRatio;

    return Material(
      color: Colors.black,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Consumer<PlayerProvider>(
        builder: (context, player, _) {
          final song = player.currentSong;
          String? coverUrl = player.currentCoverArtUrl;

          final sp = Provider.of<SubsonicProvider>(context, listen: false);
          if (song?.coverArt != null) {
            try {
              coverUrl = sp.subsonic.cachedCoverArtUrl(
                song!.coverArt!,
                size: 1200,
              );
            } catch (_) {}
          }

          if (song != null && _starredSongId != song.id) {
            _starredSongId = song.id;
            _isStarred = song.starred != null;
          }

          final totalMs = player.duration.inMilliseconds.toDouble();
          final posMs = player.position.inMilliseconds.toDouble();
          final sliderValue = _seeking
              ? _seekValue
              : (totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0);

          final accent = player.accentColor ?? Colors.white;

          return Stack(
            children: [
              // blurred album art bg
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: coverUrl != null ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeIn,
                    child: coverUrl == null
                        ? const SizedBox.expand()
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: 100,
                                  sigmaY: 100,
                                  tileMode: TileMode.clamp,
                                ),
                                child: _FadingAlbumArt(
                                  imageUrl: coverUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if ((player.accentColor?.computeLuminance() ?? 0) <
                                  0.15)
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),

              // actual content for the player
              Positioned.fill(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: topPadding + 8),

                    // top bar which has back button, title & queue button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () => player.closeFullscreen(),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Now Playing',
                            style: context.theme.typography.sm.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          // q button
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Material(
                              color: Colors.white12,
                              child: InkWell(
                                onTap: () => showFSheet(
                                  context: context,
                                  side: FLayout.btt,
                                  mainAxisMaxRatio: 0.7,
                                  builder: (_) => const QueueSheet(),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(
                                    FIcons.listMusic,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        layoutBuilder: (currentChild, previousChildren) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [...previousChildren, ?currentChild],
                          );
                        },
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        child: song == null
                            ? const SizedBox.shrink()
                            : SafeArea(
                                key: ValueKey(song.id),
                                top: false,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // art
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                        ),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 500,
                                            maxHeight: 500,
                                          ),
                                          child: AspectRatio(
                                            aspectRatio: 1,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: coverUrl != null
                                                  ? _FadingAlbumArt(
                                                      imageUrl: coverUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (ctx, err) {
                                                        final size =
                                                            MediaQuery.of(
                                                              context,
                                                            ).size.width -
                                                            64;
                                                        return _coverPlaceholder(
                                                          size,
                                                        );
                                                      },
                                                    )
                                                  : _coverPlaceholder(
                                                      MediaQuery.of(
                                                            context,
                                                          ).size.width -
                                                          64,
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const Spacer(),

                                    // title, album & star
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                ScrollingText(
                                                  text: song.title,
                                                  maxWidth:
                                                      MediaQuery.of(
                                                        context,
                                                      ).size.width -
                                                      96,
                                                  style: context
                                                      .theme
                                                      .typography
                                                      .md
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Colors.white,
                                                        height: 1.2,
                                                      ),
                                                  duration: 5,
                                                ),
                                                if ((song.album ??
                                                        song.artist) !=
                                                    null)
                                                  Text(
                                                    song.album ??
                                                        song.artist ??
                                                        '',
                                                    style: context
                                                        .theme
                                                        .typography
                                                        .sm
                                                        .copyWith(
                                                          color: Colors.white60,
                                                        ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              _isStarred
                                                  ? Icons.star_rounded
                                                  : Icons.star_border_rounded,
                                              color: _isStarred
                                                  ? accent
                                                  : Colors.white60,
                                              size: 28,
                                            ),
                                            onPressed: _toggleStar,
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    // progress bar
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: SliderTheme(
                                        data: SliderThemeData(
                                          trackHeight: 3,
                                          thumbColor: accent,
                                          activeTrackColor: accent,
                                          inactiveTrackColor: Colors.white24,
                                          overlayColor: accent.withValues(
                                            alpha: 0.2,
                                          ),
                                          thumbShape:
                                              SliderComponentShape.noThumb,
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                                overlayRadius: 12,
                                              ),
                                          trackShape:
                                              const RoundedRectSliderTrackShape(),
                                        ),
                                        child: Slider(
                                          value: sliderValue,
                                          min: 0.0,
                                          max: 1.0,
                                          activeColor: accent,
                                          inactiveColor: Colors.white24,
                                          onChangeStart: (v) {
                                            if (!mounted) return;
                                            setState(() {
                                              _seeking = true;
                                              _seekValue = v;
                                            });
                                          },
                                          onChanged: (v) {
                                            if (!mounted) return;
                                            setState(() => _seekValue = v);
                                          },
                                          onChangeEnd: (v) {
                                            if (!mounted) return;
                                            setState(() => _seeking = false);
                                            final seekMs = (v * totalMs)
                                                .round();
                                            player.seekTo(
                                              Duration(milliseconds: seekMs),
                                            );
                                          },
                                        ),
                                      ),
                                    ),

                                    // timestamps (dur & pos)
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
                                            style: context.theme.typography.xs
                                                .copyWith(
                                                  color: Colors.white,
                                                  letterSpacing: -0.5,
                                                ),
                                          ),
                                          Text(
                                            _fmt(player.duration),
                                            style: context.theme.typography.xs
                                                .copyWith(
                                                  color: Colors.white,
                                                  letterSpacing: -0.5,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 24),

                                    // controls
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          // shuffle
                                          IconButton(
                                            icon: Icon(
                                              Icons.shuffle_rounded,
                                              color: player.shuffle
                                                  ? accent
                                                  : Colors.white38,
                                              size: 26,
                                            ),
                                            onPressed: () =>
                                                player.toggleShuffle(),
                                          ),
                                          // prev
                                          IconButton(
                                            iconSize: 40,
                                            icon: const Icon(
                                              Icons.skip_previous_rounded,
                                              color: Colors.white,
                                            ),
                                            onPressed: () =>
                                                player.skipPrevious(),
                                          ),
                                          // play or pause
                                          TapArea(
                                            borderRadius: 40,
                                            onTap: () => player.togglePlay(),
                                            child: TweenAnimationBuilder<Color?>(
                                              tween: ColorTween(
                                                begin:
                                                    player.prevAccentColor ?? accent,
                                                end: accent,
                                              ),
                                              duration: const Duration(
                                                milliseconds: 400,
                                              ),
                                              builder: (context, color, _) {
                                                return Container(
                                                  width: 72,
                                                  height: 72,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: (color ?? accent)
                                                        .withValues(alpha: 0.3),
                                                  ),
                                                  child: Icon(
                                                    player.isPlaying
                                                        ? Icons.pause_rounded
                                                        : Icons
                                                              .play_arrow_rounded,
                                                    color: Colors.white,
                                                    size: 40,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          // skip
                                          IconButton(
                                            iconSize: 40,
                                            icon: const Icon(
                                              Icons.skip_next_rounded,
                                              color: Colors.white,
                                            ),
                                            onPressed: () => player.skipNext(),
                                          ),
                                          // repeat
                                          IconButton(
                                            icon: Icon(
                                              player.repeatMode == LoopMode.one
                                                  ? Icons.repeat_one_rounded
                                                  : Icons.repeat_rounded,
                                              color:
                                                  player.repeatMode ==
                                                      LoopMode.off
                                                  ? Colors.white38
                                                  : accent,
                                              size: 26,
                                            ),
                                            onPressed: () =>
                                                player.toggleRepeat(),
                                          ),
                                        ],
                                      ),
                                    ),

                                    SizedBox(height: bottomPadding + 16),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final player = Provider.of<PlayerProvider>(context, listen: false);
    final song = player.currentSong;
    if (song != null) {
      _isStarred = song.starred != null;
      _starredSongId = song.id;
    }
  }

  Widget _coverPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[800],
      child: Icon(Icons.album, color: Colors.white38, size: size * 0.4),
    );
  }

  Future<void> _toggleStar() async {
    final sp = Provider.of<SubsonicProvider>(context, listen: false);
    final player = Provider.of<PlayerProvider>(context, listen: false);
    final song = player.currentSong;
    if (song == null) return;
    final next = !_isStarred;
    setState(() => _isStarred = next);
    final ok = next
        ? await sp.subsonic.starSong(song.id)
        : await sp.subsonic.unstarSong(song.id);
    if (!ok && mounted) setState(() => _isStarred = !next);
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
