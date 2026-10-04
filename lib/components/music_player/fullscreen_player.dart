/*
  MOBILE ONLY!! (or web)

  since it uses a sheet, looks ass on desktop, and we have enough space to do all this stuff
*/

import 'dart:ui';

import 'package:cosmodrome/components/scrolling_text.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/utils/cover_art/cover_art_provider.dart';
import 'package:cosmodrome/utils/tap_area.dart';
import 'package:cosmodrome/utils/format_duration.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

class FullscreenPlayer extends StatefulWidget {
  final VoidCallback? onQueueOpen;

  const FullscreenPlayer({super.key, this.onQueueOpen});

  @override
  State<FullscreenPlayer> createState() => _FullscreenPlayerState();
}

/// [AnimatedSwitcher] layout/transition shared by the cover art and the song
/// content: children are stacked full-size and cross-faded.
Widget _stackedLayout(Widget? currentChild, List<Widget> previousChildren) {
  return Stack(
    fit: StackFit.expand,
    children: [...previousChildren, ?currentChild],
  );
}

Widget _fadeTransition(Widget child, Animation<double> animation) {
  return FadeTransition(opacity: animation, child: child);
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
      layoutBuilder: _stackedLayout,
      transitionBuilder: _fadeTransition,
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
    final screenWidth = MediaQuery.of(context).size.width;

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
                              if (accent.computeLuminance() < 0.7)
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
                    _buildTopBar(context, player),
                    const SizedBox(height: 16),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        layoutBuilder: _stackedLayout,
                        transitionBuilder: _fadeTransition,
                        child: song == null
                            ? const SizedBox.shrink()
                            : SafeArea(
                                key: ValueKey(song.id),
                                top: false,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildAlbumArt(coverUrl, screenWidth - 64),
                                    const Spacer(),
                                    _buildSongInfo(
                                      context,
                                      song,
                                      accent,
                                      screenWidth - 96,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildSeekBar(context, player, accent),
                                    const SizedBox(height: 24),
                                    _buildControls(player, accent),
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

  /// Back button, title & queue button.
  Widget _buildTopBar(BuildContext context, PlayerProvider player) {
    return Padding(
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
                onTap: widget.onQueueOpen,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(FIcons.listMusic, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(String? coverUrl, double placeholderSize) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: coverUrl != null
                  ? _FadingAlbumArt(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _) =>
                          _coverPlaceholder(placeholderSize),
                    )
                  : _coverPlaceholder(placeholderSize),
            ),
          ),
        ),
      ),
    );
  }

  /// Title, album & star button.
  Widget _buildSongInfo(
    BuildContext context,
    Song song,
    Color accent,
    double titleMaxWidth,
  ) {
    final subtitle = song.album ?? song.artist;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScrollingText(
                  text: song.title,
                  maxWidth: titleMaxWidth,
                  style: context.theme.typography.md.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  duration: 5,
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: context.theme.typography.sm.copyWith(
                      color: Colors.white60,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _isStarred ? Icons.star_rounded : Icons.star_border_rounded,
              color: _isStarred ? accent : Colors.white60,
              size: 28,
            ),
            onPressed: _toggleStar,
          ),
        ],
      ),
    );
  }

  /// Progress slider with position / duration timestamps underneath.
  Widget _buildSeekBar(
    BuildContext context,
    PlayerProvider player,
    Color accent,
  ) {
    final totalMs = player.duration.inMilliseconds.toDouble();
    final posMs = player.position.inMilliseconds.toDouble();
    final sliderValue = _seeking
        ? _seekValue
        : (totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0);
    final timeStyle = context.theme.typography.xs.copyWith(
      color: Colors.white,
      letterSpacing: -0.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbColor: accent,
              activeTrackColor: accent,
              inactiveTrackColor: Colors.white24,
              overlayColor: accent.withValues(alpha: 0.2),
              thumbShape: SliderComponentShape.noThumb,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: sliderValue,
              min: 0.0,
              max: 1.0,
              activeColor: accent,
              inactiveColor: Colors.white24,
              onChangeStart: (v) => setState(() {
                _seeking = true;
                _seekValue = v;
              }),
              onChanged: (v) => setState(() => _seekValue = v),
              onChangeEnd: (v) {
                setState(() => _seeking = false);
                player.seekTo(Duration(milliseconds: (v * totalMs).round()));
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatTrackDuration(player.position.inSeconds),
                style: timeStyle,
              ),
              Text(
                formatTrackDuration(player.duration.inSeconds),
                style: timeStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Shuffle, previous, play/pause, next & repeat.
  Widget _buildControls(PlayerProvider player, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              Icons.shuffle_rounded,
              color: player.shuffle ? accent : Colors.white38,
              size: 26,
            ),
            onPressed: () => player.toggleShuffle(),
          ),
          IconButton(
            iconSize: 40,
            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
            onPressed: () => player.skipPrevious(),
          ),
          TapArea(
            borderRadius: 40,
            onTap: () => player.togglePlay(),
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                begin: player.prevAccentColor ?? accent,
                end: accent,
              ),
              duration: const Duration(milliseconds: 400),
              builder: (context, color, _) {
                return Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (color ?? accent).withValues(alpha: 0.3),
                  ),
                  child: Icon(
                    player.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                );
              },
            ),
          ),
          IconButton(
            iconSize: 40,
            icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
            onPressed: () => player.skipNext(),
          ),
          IconButton(
            icon: Icon(
              player.repeatMode == LoopMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              color: player.repeatMode == LoopMode.off
                  ? Colors.white38
                  : accent,
              size: 26,
            ),
            onPressed: () => player.toggleRepeat(),
          ),
        ],
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
}
