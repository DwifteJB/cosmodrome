import 'dart:math';

import 'package:cosmodrome/components/music-pages/music_page_cover_header.dart';
import 'package:cosmodrome/components/music-pages/track_tile.dart';
import 'package:cosmodrome/components/scrolling_text.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/download_provider.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/cover_art/cover_art_provider.dart';
import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:cosmodrome/utils/layout_page_mixin.dart';
import 'package:cosmodrome/utils/notifiers/accent_notifier.dart';
import 'package:cosmodrome/utils/notifiers/layout_notifier.dart';
import 'package:cosmodrome/utils/notifiers/sidebar_notifier.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

String _albumMetaText(AlbumDetail album) => [
  if (album.year != null) album.year.toString(),
  '${album.songCount} track${album.songCount == 1 ? '' : 's'}',
  formatPageDuration(album.duration),
].join(' • ');

class AlbumPage extends StatefulWidget {
  final String albumId;

  const AlbumPage({super.key, required this.albumId});

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumHeader extends StatelessWidget {
  final AlbumDetail album;
  final bool isStarred;
  final void Function()? onStarToggle;

  const _AlbumHeader({
    required this.album,
    this.onStarToggle,
    required this.isStarred,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ScrollingText(
                  text: album.name,
                  maxWidth: 600,
                  style: context.theme.typography.xl4.copyWith(
                    fontWeight: FontWeight.w500,
                    color: context.theme.colors.foreground,
                    letterSpacing: 1,
                    height: 0,
                  ),
                ),
              ),
              FButton(
                onPress: onStarToggle,
                variant: FButtonVariant.ghost,
                child: Icon(
                  Icons.star,
                  color: isStarred
                      ? Colors.yellow[700]
                      : context.theme.colors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            album.artist,
            style: context.theme.typography.xl.copyWith(
              color: Colors.white,
              height: 0,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _albumMetaText(album),
            style: context.theme.typography.md.copyWith(
              color: context.theme.colors.mutedForeground,
              height: 0,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          _PlayShuffleButtons(songs: album.songs),
        ],
      ),
    );
  }
}

class _AlbumPageState extends State<AlbumPage> with LayoutPageMixin {
  static const int _initialTrackRevealCount = 3;
  static const int _trackRevealBatchSize = 8;
  AlbumDetail? _album;
  String? _coverUrl;
  bool _loading = true;
  String? _error;
  bool _starred = false;
  int _revealedTrackCount = 0;

  bool _trackRevealScheduled = false;
  Color _localCoverColor = AppColors.auraColor;

  // mobile topbarbutton
  @override
  List<TopbarButton> get pageButtons => [
    TopbarButton(
      onPressed: _starAlbum,
      icon: Icons.star,
      color: _starred ? Colors.yellow[700] : Colors.white,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    context.watch<SubsonicProvider>().isOffline;
    context.watch<DownloadProvider>();

    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (_error != null || _album == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: Text(
            _error ?? 'Album not found',
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ),
      );
    }

    return isMobileView(context) ? _mobileLayout() : _desktopLayout();
  }

  @override
  void dispose() {
    accentColorNotifier.value = null;
    coverUrlNotifier.value = null;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchAlbum();
  }

  void onClickSong(Song song) async {
    if (!_isSongPlayable(song)) return;
    PlayerProvider pp = context.read<PlayerProvider>();
    await pp.resetQueue();
    await pp.playNow(song);
    final index = _album!.songs.indexOf(song);
    if (index != -1 && index < _album!.songs.length - 1) {
      pp.addBulkToQueue(_album!.songs.sublist(index + 1));
    }
  }

  Widget _compactHeader(AlbumDetail album, String? coverUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: _cover(
            coverUrl,
            size: 220,
            radius: 12,
            placeholder: _coverPlaceholder(220),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              Text(
                album.name,
                textAlign: TextAlign.center,
                style: context.theme.typography.xl4.copyWith(
                  fontWeight: FontWeight.w500,
                  color: context.theme.colors.foreground,
                  letterSpacing: 1,
                  height: 0,
                ),
              ),
              Text(
                album.artist,
                style: context.theme.typography.xl.copyWith(
                  color: Colors.white,
                  height: 0,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _albumMetaText(album),
                textAlign: TextAlign.center,
                style: context.theme.typography.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _PlayShuffleButtons(songs: album.songs)),
                  const SizedBox(width: 12),
                  FButton(
                    onPress: _starAlbum,
                    variant: FButtonVariant.secondary,

                    child: Icon(
                      Icons.star,
                      color: _starred ? Colors.yellow[700] : Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cover(
    String? coverUrl, {
    required double size,
    required double radius,
    required Widget placeholder,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: coverUrl != null
          ? Image(
              image: coverArtProvider(coverUrl),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            )
          : placeholder,
    );
  }

  Widget _coverPlaceholder(double size, {double? iconSize}) {
    return Container(
      width: size,
      height: size,
      color: context.theme.colors.muted,
      child: Icon(
        Icons.album,
        color: context.theme.colors.mutedForeground,
        size: iconSize ?? size * 0.4,
      ),
    );
  }

  Widget _desktopLayout() {
    final album = _album!;
    final coverUrl = _coverUrl;
    final visibleTrackCount = _visibleTrackCount(album.songs.length);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 700
                ? _compactHeader(album, coverUrl)
                : _wideHeader(album, coverUrl),
          ),
          const SizedBox(height: 20),
          ..._trackList(
            album,
            visibleTrackCount,
            (song, index) => MusicPageDesktopTrackTile(
              isPlaylist: false,
              song: song,
              trackNumber: song.track ?? 0,
              index: index,
              albumArtist: album.artist,
              enabled: _isSongPlayable(song),
              accentColor: accentColorNotifier.value ?? _localCoverColor,
              onTap: () => onClickSong(song),
            ),
          ),
        ],
      ),
    );
  }

  void _extractAccentColor() async {
    if (_coverUrl == null) return;
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        coverArtProvider(_coverUrl!),
        size: const Size(200, 200),
      );
      final color =
          generator.vibrantColor?.color ?? generator.dominantColor?.color;
      // figure out if its too dark

      if (!mounted) return;
      accentColorNotifier.value = color;
      setState(() {
        _localCoverColor = color ?? AppColors.auraColor;
      });
    } catch (_) {}
  }

  Future<void> _fetchAlbum() async {
    final provider = context.read<SubsonicProvider>();
    if (provider.activeAccount == null) {
      setState(() {
        _error = 'No active account';
        _loading = false;
      });
      return;
    }

    try {
      final album = await provider.subsonic.getAlbum(widget.albumId);
      if (album != null) _orderByDisc(album.songs);
      if (mounted) {
        final coverUrl = album?.coverArt != null
            ? provider.subsonic.cachedCoverArtUrl(album!.coverArt!, size: 600)
            : null;
        if (coverUrl != null) {
          await precacheImage(
            coverArtProvider(coverUrl),
            context,
          ).catchError((_) {});
        }
        if (!mounted) return;
        setState(() {
          _album = album;
          _starred = album?.starred != null;
          _coverUrl = coverUrl;
          _error = album == null ? 'Album not found' : null;
          _loading = false;
        });
        coverUrlNotifier.value = coverUrl;
        _pushPageButtons();
        _extractAccentColor();
        if (_revealedTrackCount == 0 && album != null) {
          _revealedTrackCount = min(
            album.songs.length,
            _initialTrackRevealCount,
          );
          _scheduleTrackReveal();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  bool _isSongPlayable(Song song) {
    final subsonic = context.read<SubsonicProvider>();
    if (!subsonic.isOffline) return true;
    return context.read<DownloadProvider>().isSongDownloaded(song.id);
  }

  Widget _mobileLayout() {
    final album = _album!;
    final coverUrl = _coverUrl;
    final visibleTrackCount = _visibleTrackCount(album.songs.length);

    final metaParts = <String>[
      if (album.genre != null) album.genre!,
      if (album.year != null) '${album.year}',
      '${album.songCount} track${album.songCount == 1 ? '' : 's'}',
    ];

    final cardWidth = min(MediaQuery.of(context).size.width * 0.8, 400.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        Center(
          child: _cover(
            coverUrl,
            size: cardWidth,
            radius: 16,
            placeholder: _coverPlaceholder(200),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          album.name,
          textAlign: TextAlign.center,
          style: context.theme.typography.xl2.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.06,
            height: 0,
          ),
        ),
        Text(
          album.artist,
          textAlign: TextAlign.center,
          style: context.theme.typography.sm.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.05,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          metaParts.join(' • '),
          textAlign: TextAlign.center,
          style: context.theme.typography.xs.copyWith(
            color: context.theme.colors.mutedForeground,
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _PlayShuffleButtons(songs: album.songs),
        ),
        const SizedBox(height: 24),
        ..._trackList(
          album,
          visibleTrackCount,
          (song, index) => MusicPageMobileTrackTile(
            isPlaylist: false,
            song: song,
            trackNumber: song.track ?? 0,
            index: index,
            enabled: _isSongPlayable(song),
            albumArtist: album.artist,
            accentColor: accentColorNotifier.value ?? AppColors.auraColor,
            onTap: () => onClickSong(song),
          ),
        ),

        const Divider(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppColors.trackNumber,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formatPageDuration(album.duration),
                    style: context.theme.typography.xs.copyWith(
                      color: AppColors.trackNumber,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  void _pushPageButtons() {
    final cur = layoutConfig.value;
    layoutConfig.value = LayoutConfig(
      title: cur.title,
      buttons: pageButtons,
      mainPillBuilder: cur.mainPillBuilder,
      searchPillBuilder: cur.searchPillBuilder,
      hidePill: cur.hidePill,
      isScrollable: cur.isScrollable,
    );
  }

  void _scheduleTrackReveal() {
    if (!mounted || _trackRevealScheduled || _album == null) return;
    final totalTracks = _album!.songs.length;
    if (_revealedTrackCount >= totalTracks) return;

    _trackRevealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackRevealScheduled = false;
      if (!mounted || _album == null) return;

      final clampedCount = min(
        _revealedTrackCount + _trackRevealBatchSize,
        _album!.songs.length,
      );
      if (clampedCount == _revealedTrackCount) return;

      setState(() {
        _revealedTrackCount = clampedCount;
      });

      if (_revealedTrackCount < _album!.songs.length) {
        _scheduleTrackReveal();
      }
    });
  }

  Future<void> _starAlbum() async {
    if (_album == null) return;
    final provider = context.read<SubsonicProvider>();
    final nowStarred = !_starred;
    setState(() => _starred = nowStarred);
    _pushPageButtons();
    final ok = nowStarred
        ? await provider.subsonic.starAlbum(_album!.id)
        : await provider.subsonic.unstarAlbum(_album!.id);
    if (!ok && mounted) {
      setState(() => _starred = !nowStarred);
      _pushPageButtons();
    } else if (ok) {
      notifyStarredChanged();
    }
  }

  List<Widget> _trackList(
    AlbumDetail album,
    int visibleCount,
    Widget Function(Song song, int index) tile,
  ) {
    final multiDisc = _hasMultipleDiscs(album.songs);
    final widgets = <Widget>[];
    int? lastDisc;
    for (var i = 0; i < visibleCount; i++) {
      final song = album.songs[i];
      final disc = song.discNumber ?? 1;
      if (multiDisc && disc != lastDisc) {
        widgets.add(
          _DiscHeader(
            key: ValueKey('disc-$disc'),
            disc: disc,
            title: album.discTitles[disc],
          ),
        );
        lastDisc = disc;
      }
      widgets.add(tile(song, i));
    }
    return widgets;
  }

  int _visibleTrackCount(int totalTracks) =>
      min(_revealedTrackCount, totalTracks);

  Widget _wideHeader(AlbumDetail album, String? coverUrl) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cover(
            coverUrl,
            size: 280,
            radius: 12,
            placeholder: _coverPlaceholder(280, iconSize: 80),
          ),
          Expanded(
            child: _AlbumHeader(
              album: album,
              isStarred: _starred,
              onStarToggle: _starAlbum,
            ),
          ),
        ],
      ),
    );
  }

  static bool _hasMultipleDiscs(List<Song> songs) =>
      songs.map((s) => s.discNumber ?? 1).toSet().length > 1;

  static void _orderByDisc(List<Song> songs) {
    final indexed = songs.indexed.toList(growable: false);
    indexed.sort((a, b) {
      final disc = (a.$2.discNumber ?? 0).compareTo(b.$2.discNumber ?? 0);
      if (disc != 0) return disc;
      final track = (a.$2.track ?? 0).compareTo(b.$2.track ?? 0);
      return track != 0 ? track : a.$1.compareTo(b.$1);
    });
    for (var i = 0; i < indexed.length; i++) {
      songs[i] = indexed[i].$2;
    }
  }
}

class _DiscHeader extends StatelessWidget {
  final int disc;
  final String? title;

  const _DiscHeader({super.key, required this.disc, this.title});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final label = title == null || title!.isEmpty
        ? 'Disc $disc'
        : 'Disc $disc · $title';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Row(
        children: [
          Icon(Icons.album, size: 14, color: theme.colors.mutedForeground),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.typography.xs.copyWith(
              color: theme.colors.mutedForeground,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayShuffleButtons extends StatelessWidget {
  final List<Song> songs;

  const _PlayShuffleButtons({required this.songs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FButton(
            onPress: () => context.read<PlayerProvider>().playAlbum(songs),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, size: 20),
                SizedBox(width: 6),
                Text('Play'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FButton(
            variant: FButtonVariant.outline,
            onPress: () =>
                context.read<PlayerProvider>().playAlbum(songs, shuffle: true),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shuffle_rounded, size: 20),
                SizedBox(width: 6),
                Text('Shuffle'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
