import 'package:cosmodrome/components/music-pages/music_page_cover_header.dart';
import 'package:cosmodrome/components/music-pages/track_tile.dart';
import 'package:cosmodrome/components/scrolling_text.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/utils/accent_notifier.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:cosmodrome/utils/is_colour_too_dark.dart';
import 'package:cosmodrome/utils/layout_notifier.dart';
import 'package:cosmodrome/utils/layout_page_mixin.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

class AlbumPage extends StatefulWidget {
  final String albumId;

  const AlbumPage({super.key, required this.albumId});

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumHeader extends StatelessWidget {
  final AlbumDetail album;

  const _AlbumHeader({required this.album});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (album.year != null) album.year.toString(),
      '${album.songCount} track${album.songCount == 1 ? '' : 's'}',
      formatPageDuration(album.duration),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ScrollingText(
            text: album.name,
            maxWidth: 600,
            style: context.theme.typography.xl4.copyWith(
              fontWeight: FontWeight.w500,
              color: context.theme.colors.foreground,
              letterSpacing: 1,
              height: 0,
            ),
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
            parts.join(' • '),
            style: context.theme.typography.md.copyWith(
              color: context.theme.colors.mutedForeground,
              height: 0,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: FButton(
                  onPress: () =>
                      context.read<PlayerProvider>().playAlbum(album.songs),
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
                  onPress: () => context.read<PlayerProvider>().playAlbum(
                    album.songs,
                    shuffle: true,
                  ),
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
          ),
        ],
      ),
    );
  }
}

class _AlbumPageState extends State<AlbumPage> with LayoutPageMixin {
  AlbumDetail? _album;
  String? _coverUrl;
  bool _loading = true;
  String? _error;
  bool _starred = false;

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

  void _pushPageButtons() {
    final cur = layoutConfig.value;
    layoutConfig.value = LayoutConfig(
      title: cur.title,
      buttons: pageButtons,
      topBarBuilder: cur.topBarBuilder,
      mainPillBuilder: cur.mainPillBuilder,
      searchPillBuilder: cur.searchPillBuilder,
      hidePill: cur.hidePill,
      isScrollable: cur.isScrollable,
    );
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
    }
  }

  @override
  Widget build(BuildContext context) {

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
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchAlbum();
  }

  void onClickSong(Song song) async {
    PlayerProvider pp = context.read<PlayerProvider>();
    await pp.resetQueue();
    await pp.playNow(song);
    final index = _album!.songs.indexOf(song);
    if (index != -1 && index < _album!.songs.length - 1) {
      final nextSongs = _album!.songs.sublist(index + 1);
      pp.addBulkToQueue(nextSongs.toList());
    }
  }

  Widget _compactHeader(AlbumDetail album, String? coverUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: coverUrl != null
                ? Image.network(
                    coverUrl,
                    width: 220,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 220,
                      height: 220,
                      color: context.theme.colors.muted,
                      child: Icon(
                        Icons.album,
                        color: context.theme.colors.mutedForeground,
                        size: 88,
                      ),
                    ),
                  )
                : Container(
                    width: 220,
                    height: 220,
                    color: context.theme.colors.muted,
                    child: Icon(
                      Icons.album,
                      color: context.theme.colors.mutedForeground,
                      size: 88,
                    ),
                  ),
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
                style: context.theme.typography.xl2.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                album.artist,
                textAlign: TextAlign.center,
                style: context.theme.typography.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (album.year != null) album.year.toString(),
                  '${album.songCount} track${album.songCount == 1 ? '' : 's'}',
                  formatPageDuration(album.duration),
                ].join(' • '),
                textAlign: TextAlign.center,
                style: context.theme.typography.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FButton(
                      onPress: () =>
                          context.read<PlayerProvider>().playAlbum(album.songs),
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
                      onPress: () => context.read<PlayerProvider>().playAlbum(
                        album.songs,
                        shuffle: true,
                      ),
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coverPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: context.theme.colors.muted,
      child: Icon(
        Icons.album,
        color: context.theme.colors.mutedForeground,
        size: size * 0.4,
      ),
    );
  }

  Widget _desktopLayout() {
    final album = _album!;
    final coverUrl = _coverUrl;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompact)
                _compactHeader(album, coverUrl)
              else
                _wideHeader(album, coverUrl),
              const SizedBox(height: 20),
              ...album.songs.map(
                (s) => MusicPageDesktopTrackTile(
                  song: s,
                  trackNumber: s.track ?? 0,
                  albumArtist: album.artist,
                  accentColor: accentColorNotifier.value ?? _localCoverColor,
                  onTap: () => onClickSong(s),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _wideHeader(AlbumDetail album, String? coverUrl) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: coverUrl != null
                ? Image.network(
                    coverUrl,
                    width: 280,
                    height: 280,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 280,
                      height: 280,
                      color: context.theme.colors.muted,
                      child: Icon(
                        Icons.album,
                        color: context.theme.colors.mutedForeground,
                        size: 80,
                      ),
                    ),
                  )
                : Container(
                    width: 280,
                    height: 280,
                    color: context.theme.colors.muted,
                    child: Icon(
                      Icons.album,
                      color: context.theme.colors.mutedForeground,
                      size: 80,
                    ),
                  ),
          ),
          Expanded(child: _AlbumHeader(album: album)),
        ],
      ),
    );
  }

  void _extractAccentColor() async {
    if (_coverUrl == null) return;
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(_coverUrl!),
        size: const Size(200, 200),
      );
      final color =
          generator.vibrantColor?.color ?? generator.dominantColor?.color;
      // figure out if its too dark
      final tooDark = isColourTooDark(color ?? AppColors.auraColor);

      if (tooDark) {
        if (mounted) accentColorNotifier.value = AppColors.auraColor;
        setState(() {
          _localCoverColor = AppColors.auraColor;
        });
        return;
      }

      if (mounted) accentColorNotifier.value = color;
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
      if (mounted) {
        final coverUrl = album?.coverArt != null
            ? provider.subsonic.cachedCoverArtUrl(album!.coverArt!, size: 600)
            : null;
        if (coverUrl != null) {
          await precacheImage(NetworkImage(coverUrl), context).catchError((_) {});
        }
        if (!mounted) return;
        setState(() {
          _album = album;
          _starred = album?.starred != null;
          _coverUrl = coverUrl;
          _error = album == null ? 'Album not found' : null;
          _loading = false;
        });
        _pushPageButtons();
        _extractAccentColor();
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

  Widget _mobileLayout() {
    final album = _album!;
    final coverUrl = _coverUrl;

    final metaParts = <String>[
      if (album.genre != null) album.genre!,
      if (album.year != null) '${album.year}',
      '${album.songCount} track${album.songCount == 1 ? '' : 's'}',
    ];

    final additionalDetails = <Widget>[
      Row(
        children: [
          const Icon(Icons.access_time, size: 16, color: AppColors.trackNumber),
          const SizedBox(width: 4),
          Text(
            formatPageDuration(album.duration),
            style: context.theme.typography.xs.copyWith(
              color: AppColors.trackNumber,
            ),
          ),
        ],
      ),
    ];

    var cardWidth = MediaQuery.of(context).size.width * 0.8;
    if (cardWidth > 400) cardWidth = 400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: coverUrl != null
                ? Image.network(
                    coverUrl,
                    width: cardWidth,
                    height: cardWidth,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => _coverPlaceholder(200),
                  )
                : _coverPlaceholder(200),
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
        if (metaParts.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            metaParts.join(' • '),
            textAlign: TextAlign.center,
            style: context.theme.typography.xs.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ],
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: FButton(
                  onPress: () =>
                      context.read<PlayerProvider>().playAlbum(album.songs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
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
                  onPress: () => context.read<PlayerProvider>().playAlbum(
                    album.songs,
                    shuffle: true,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.shuffle_rounded, size: 20),
                      SizedBox(width: 6),
                      Text('Shuffle'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ...album.songs.map(
          (s) => MusicPageMobileTrackTile(
            song: s,
            trackNumber: s.track ?? 0,
            albumArtist: album.artist,
            accentColor: accentColorNotifier.value ?? AppColors.auraColor,
            onTap: () => onClickSong(s),
          ),
        ),

        if (additionalDetails.isNotEmpty) ...[
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: additionalDetails
                .map(
                  (w) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: w,
                  ),
                )
                .toList(),
          ),
        ],

        const SizedBox(height: 32),
      ],
    );
  }
}
