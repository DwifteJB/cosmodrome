/*
  MOBILE ONLY!! (or web)

  since it uses a sheet, looks ass on desktop, and we have enough space to do all this stuff
*/
import 'dart:ui';

import 'package:cosmodrome/components/music_player/lyrics_view.dart';
import 'package:cosmodrome/components/music_player/mobile_queue_list.dart';
import 'package:cosmodrome/components/scrolling_text.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/main.dart' show router;
import 'package:cosmodrome/providers/lyrics_provider.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/utils/cover_art/cover_art_provider.dart';
import 'package:cosmodrome/utils/navigation.dart';
import 'package:cosmodrome/utils/tap_area.dart';
import 'package:cosmodrome/utils/format_duration.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

enum _PlayerMode { art, lyrics, queue }

class FullscreenPlayer extends StatefulWidget {
  const FullscreenPlayer({super.key});

  @override
  State<FullscreenPlayer> createState() => _FullscreenPlayerState();
}

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
    // url carries a fresh auth salt every build, the provider compares by cache key
    final provider = coverArtProvider(imageUrl);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: _stackedLayout,
      transitionBuilder: _fadeTransition,
      child: Image(
        image: provider,
        key: ValueKey(provider),
        fit: fit,
        errorBuilder: errorBuilder != null
            ? (context, error, stackTrace) => errorBuilder!(context, error)
            : null,
      ),
    );
  }
}

class _SongLinksSheet extends StatelessWidget {
  final Song song;
  final String? coverUrl;
  final double bottomPadding;
  final VoidCallback? onAlbum;
  final VoidCallback? onArtist;

  const _SongLinksSheet({
    required this.song,
    required this.coverUrl,
    required this.bottomPadding,
    required this.onAlbum,
    required this.onArtist,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final placeholder = Container(
      width: 48,
      height: 48,
      color: colors.muted,
      child: Icon(Icons.music_note, color: colors.mutedForeground, size: 24),
    );

    return Material(
      color: const Color(0xFF111111),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: coverUrl != null
                      ? Image(
                          image: coverArtProvider(coverUrl!),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => placeholder,
                        )
                      : placeholder,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: TextStyle(
                          color: colors.foreground,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (song.artist != null)
                        Text(
                          song.artist!,
                          style: TextStyle(
                            color: colors.mutedForeground,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          if (onAlbum != null)
            ListTile(
              leading: Icon(Icons.album_outlined, color: colors.foreground),
              title: Text(
                'Go to album',
                style: TextStyle(color: colors.foreground),
              ),
              onTap: onAlbum,
            ),
          if (onArtist != null)
            ListTile(
              leading: Icon(Icons.person_outline, color: colors.foreground),
              title: Text(
                'Go to artist',
                style: TextStyle(color: colors.foreground),
              ),
              onTap: onArtist,
            ),
          SizedBox(height: bottomPadding + 8),
        ],
      ),
    );
  }
}

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _TopBarButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Material(
        color: Colors.white12,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}

class _LyricsLoading extends StatelessWidget {
  const _LyricsLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Finding lyrics…',
            style: context.theme.typography.sm.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _LyricsEmpty extends StatelessWidget {
  const _LyricsEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lyrics_outlined, size: 32, color: Colors.white54),
          const SizedBox(height: 12),
          Text(
            'No lyrics for this song',
            textAlign: TextAlign.center,
            style: context.theme.typography.sm.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _TranslateToggle extends StatelessWidget {
  final bool active;
  final Color accent;
  final VoidCallback onPressed;

  const _TranslateToggle({
    required this.active,
    required this.accent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Material(
        color: Colors.white12,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              FIcons.languages,
              size: 18,
              color: active ? accent : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenPlayerState extends State<FullscreenPlayer> {
  bool _seeking = false;
  double _seekValue = 0.0;

  bool _isStarred = false;
  String? _starredSongId;

  _PlayerMode _mode = _PlayerMode.art;
  bool _linksOpen = false;

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
          final lyricsProvider = context.watch<LyricsProvider>();
          if (!player.isFullscreenOpen) _linksOpen = false;

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
                              AnimatedOpacity(
                                opacity: _mode == _PlayerMode.art ? 0.0 : 1.0,
                                duration: const Duration(milliseconds: 350),
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                  ),
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
                    _buildTopBar(context, player, accent, lyricsProvider),
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
                            : switch (_mode) {
                                _PlayerMode.lyrics => SafeArea(
                                  key: const ValueKey('lyrics'),
                                  top: false,
                                  child: _buildLyricsLayout(
                                    context,
                                    player,
                                    lyricsProvider,
                                    song,
                                    coverUrl,
                                    accent,
                                    screenWidth,
                                    bottomPadding,
                                  ),
                                ),
                                _PlayerMode.queue => SafeArea(
                                  key: const ValueKey('queue'),
                                  top: false,
                                  child: _buildQueueLayout(
                                    context,
                                    player,
                                    song,
                                    coverUrl,
                                    accent,
                                    screenWidth,
                                    bottomPadding,
                                  ),
                                ),
                                _PlayerMode.art => SafeArea(
                                  key: ValueKey(song.id),
                                  top: false,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildAlbumArt(
                                        coverUrl,
                                        screenWidth - 64,
                                      ),
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
                              },
                      ),
                    ),
                  ],
                ),
              ),

              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_linksOpen,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _linksOpen = false),
                    child: AnimatedOpacity(
                      opacity: _linksOpen ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      child: ColoredBox(color: context.theme.colors.barrier),
                    ),
                  ),
                ),
              ),
              if (song != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: !_linksOpen,
                    child: AnimatedSlide(
                      offset: _linksOpen ? Offset.zero : const Offset(0, 1),
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: _SongLinksSheet(
                        song: song,
                        coverUrl: coverUrl,
                        bottomPadding: bottomPadding,
                        onAlbum: song.albumId.isNotEmpty
                            ? () => _goToAlbum(player, song)
                            : null,
                        onArtist: songHasArtist(song)
                            ? () => _goToArtist(player, song)
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    PlayerProvider player,
    Color accent,
    LyricsProvider lyricsProvider,
  ) {
    final lyricsColor = _mode == _PlayerMode.lyrics
        ? accent
        : lyricsProvider.hasLyrics
        ? Colors.white
        : Colors.white38;
    final queueColor = _mode == _PlayerMode.queue ? accent : Colors.white;

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
          _TopBarButton(
            icon: Icons.lyrics_rounded,
            color: lyricsColor,
            onTap: () => _toggleMode(_PlayerMode.lyrics),
          ),
          const SizedBox(width: 8),
          _TopBarButton(
            icon: FIcons.listMusic,
            color: queueColor,
            onTap: () => _toggleMode(_PlayerMode.queue),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildLyricsLayout(
    BuildContext context,
    PlayerProvider player,
    LyricsProvider lyricsProvider,
    Song song,
    String? coverUrl,
    Color accent,
    double screenWidth,
    double bottomPadding,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildNowPlayingRow(context, song, coverUrl, accent, screenWidth - 164),
        const SizedBox(height: 8),
        Expanded(child: _buildLyricsBody(context, lyricsProvider, accent)),
        const SizedBox(height: 8),
        _buildSeekBar(context, player, accent),
        const SizedBox(height: 16),
        _buildControls(player, accent),
        SizedBox(height: bottomPadding + 16),
      ],
    );
  }

  Widget _buildQueueLayout(
    BuildContext context,
    PlayerProvider player,
    Song song,
    String? coverUrl,
    Color accent,
    double screenWidth,
    double bottomPadding,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildNowPlayingRow(context, song, coverUrl, accent, screenWidth - 164),
        const SizedBox(height: 8),
        Expanded(child: MobileQueueList(accent: accent)),
        const SizedBox(height: 8),
        _buildSeekBar(context, player, accent),
        const SizedBox(height: 16),
        _buildControls(player, accent),
        SizedBox(height: bottomPadding + 16),
      ],
    );
  }

  Widget _buildNowPlayingRow(
    BuildContext context,
    Song song,
    String? coverUrl,
    Color accent,
    double titleMaxWidth,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: coverUrl != null
                  ? _FadingAlbumArt(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _) => _coverPlaceholder(56),
                    )
                  : _coverPlaceholder(56),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openLinks(song),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScrollingText(
                    text: song.title,
                    maxWidth: titleMaxWidth,
                    style: context.theme.typography.md.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    duration: 5,
                  ),
                  if (song.artist != null)
                    Text(
                      song.artist!,
                      style: context.theme.typography.sm.copyWith(
                        color: Colors.white60,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
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

  Widget _buildLyricsBody(
    BuildContext context,
    LyricsProvider provider,
    Color accent,
  ) {
    final lyrics = provider.lyrics;
    final typography = context.theme.typography;

    Widget body;
    if (provider.isLoading) {
      body = const _LyricsLoading(key: ValueKey('loading'));
    } else if (lyrics == null || !lyrics.hasLyrics) {
      body = const _LyricsEmpty(key: ValueKey('empty'));
    } else {
      body = ShaderMask(
        key: const ValueKey('lyrics'),
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0, 0.08, 0.9, 1],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: LyricsView(
          lyrics: lyrics,
          mainStyle: typography.xl2.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: Colors.white,
          ),
          secondaryStyle: typography.sm.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white60,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          showTranslation: provider.showTranslation,
          showPronunciation: provider.showPronunciation,
          accentColor: accent,
          enableHover: false,
          topSpacer: 24,
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            layoutBuilder: _stackedLayout,
            transitionBuilder: _fadeTransition,
            child: body,
          ),
        ),
        if (provider.hasSecondaryLayers)
          Positioned(
            right: 24,
            bottom: 8,
            child: _TranslateToggle(
              active: provider.secondaryLayersVisible,
              accent: accent,
              onPressed: provider.toggleSecondaryLayers,
            ),
          ),
      ],
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openLinks(song),
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

  void _goToAlbum(PlayerProvider player, Song song) {
    setState(() => _linksOpen = false);
    player.closeFullscreen();
    openAlbum(router, song.albumId);
  }

  void _goToArtist(PlayerProvider player, Song song) {
    final subsonic = context.read<SubsonicProvider>().subsonic;
    setState(() => _linksOpen = false);
    player.closeFullscreen();
    openArtist(
      router,
      subsonic,
      artistId: song.artistId,
      artistName: song.artist,
    );
  }

  void _openLinks(Song song) {
    if (song.albumId.isEmpty && !songHasArtist(song)) return;
    setState(() => _linksOpen = true);
  }

  void _toggleMode(_PlayerMode mode) {
    setState(() => _mode = _mode == mode ? _PlayerMode.art : mode);
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
