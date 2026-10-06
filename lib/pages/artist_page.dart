import 'dart:async';
import 'dart:math';

import 'package:cosmodrome/components/album_card.dart';
import 'package:cosmodrome/components/desktop/desktop_layout.dart';
import 'package:cosmodrome/components/library/song_row.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/services/artist_about_service.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/cover_art/cover_art_provider.dart';
import 'package:cosmodrome/utils/disc_order.dart';
import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:cosmodrome/utils/layout_page_mixin.dart';
import 'package:cosmodrome/utils/tap_area.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

const _sheetColor = Color(0xFF111111);

String _albumMeta(Album album) => album.year != null && album.year! > 0
    ? '${album.year}'
    : _songCount(album.songCount);

Widget _dragScroll({required Widget child}) => ScrollConfiguration(
  behavior: const ScrollBehavior().copyWith(
    dragDevices: {
      PointerDeviceKind.mouse,
      PointerDeviceKind.touch,
      PointerDeviceKind.trackpad,
    },
  ),
  child: child,
);

String? _plainBio(String? html) {
  if (html == null) return null;
  final text = html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\s*Read more on Last\.fm\.?\s*$'), '')
      .trim();
  return text.isEmpty ? null : text;
}

String _songCount(int count) => '$count song${count == 1 ? '' : 's'}';

class ArtistPage extends StatefulWidget {
  final String artistId;

  const ArtistPage({super.key, required this.artistId});

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _AboutBody extends StatelessWidget {
  final ArtistAbout? about;
  final String? bio;
  final Color linkColor;
  final bool wide;

  const _AboutBody({
    required this.about,
    required this.bio,
    required this.linkColor,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final about = this.about;
    final tagline = about?.tagline;
    final facts = <(String, String)>[
      if (about?.begin != null) (about!.beginLabel, about.begin!),
      if (about?.end != null) (about!.endLabel, about.end!),
      if (about?.origin != null) ('From', about!.origin!),
      if (about != null && about.genres.isNotEmpty)
        ('Genre', about.genres.join(', ')),
    ];
    final links = <(String, String)>[
      if (about?.wikipediaUrl != null) ('Wikipedia', about!.wikipediaUrl!),
      if (about?.musicBrainzUrl != null)
        ('MusicBrainz', about!.musicBrainzUrl!),
    ];

    final story = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tagline != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${tagline[0].toUpperCase()}${tagline.substring(1)}',
              style: theme.typography.sm.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colors.foreground,
              ),
            ),
          ),
        if (bio != null)
          Text(
            bio!,
            style: theme.typography.sm.copyWith(
              color: const Color(0xCCFFFFFF),
              height: 1.6,
            ),
          ),
        if (links.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(
              top: tagline != null || bio != null ? 16 : 0,
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final (label, url) in links)
                  _LinkText(label: label, url: url, color: linkColor),
              ],
            ),
          ),
      ],
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, (label, value)) in facts.indexed)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: theme.typography.xs.copyWith(
                    color: theme.colors.mutedForeground,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.typography.sm.copyWith(
                    color: theme.colors.foreground,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (facts.isEmpty) return story;

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: story),
          const SizedBox(width: 40),
          SizedBox(width: 220, child: details),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [story, const SizedBox(height: 24), details],
    );
  }
}

class _AboutSheet extends StatelessWidget {
  final String name;
  final Widget child;

  const _AboutSheet({required this.name, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;

    return Material(
      color: _sheetColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Text(
                name,
                style: TextStyle(
                  color: colors.foreground,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistAvatar extends StatelessWidget {
  final ImageProvider? image;
  final double size;
  final VoidCallback? onError;

  const _ArtistAvatar({required this.image, required this.size, this.onError});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final placeholder = ColoredBox(
      color: colors.muted,
      child: Center(
        child: Icon(
          Icons.person,
          color: colors.mutedForeground,
          size: size * 0.4,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: image != null
            ? Image(
                image: image!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) {
                  onError?.call();
                  return placeholder;
                },
              )
            : placeholder,
      ),
    );
  }
}

class _ArtistPageState extends State<ArtistPage> with LayoutPageMixin {
  static const double _desktopHeroHeight = 400;
  static const int _mobileSongLimit = 5;

  ArtistDetail? _artist;
  ArtistInfo? _info;
  ArtistAbout? _about;
  List<Song>? _songs;
  bool _songsRanked = true;
  bool _showAllSongs = false;
  bool _loading = true;
  String? _error;
  bool _starred = false;
  Color? _accent;
  ImageProvider? _accentSource;
  final Set<ImageProvider> _failedImages = {};

  String? get _bio => _about?.bio ?? _plainBio(_info?.biography);

  bool get _hasAbout => _bio != null || !(_about?.isEmpty ?? true);

  Color get _heroColor {
    final accent = _accent;
    if (accent == null) return context.theme.colors.muted;
    final hsl = HSLColor.fromColor(accent);
    return hsl.withLightness(hsl.lightness.clamp(0.2, 0.45)).toColor();
  }

  ImageProvider? get _image {
    final artist = _artist;
    final coverArt = artist?.coverArt;
    final urls = {?artist?.artistImageUrl, ?_info?.imageUrl, ?_about?.imageUrl};
    final candidates = <ImageProvider>[
      if (coverArt != null)
        coverArtProvider(_subsonic.cachedCoverArtUrl(coverArt, size: 800)),
      for (final url in urls) NetworkImage(url),
    ];
    return candidates.where((c) => !_failedImages.contains(c)).firstOrNull;
  }

  Album? get _latestAlbum => _artist?.albums.firstOrNull;

  Color get _linkColor {
    final accent = _accent;
    if (accent == null) return AppColors.auraColor;
    final hsl = HSLColor.fromColor(accent);
    return hsl.withLightness(hsl.lightness.clamp(0.62, 0.85)).toColor();
  }

  Subsonic get _subsonic => context.read<SubsonicProvider>().subsonic;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 360,
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (_error != null || _artist == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 160),
        child: Center(
          child: Text(
            _error ?? 'Artist not found',
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
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Widget _albumsSection(List<Album> albums, double inset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: const _SectionTitle('Albums'),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 210,
          child: _dragScroll(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: inset),
              itemCount: albums.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(right: 14),
                child: AlbumCard(
                  album: albums[i],
                  subsonic: _subsonic,
                  subtitle: _albumMeta(albums[i]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _desktopAbout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('About ${_artist!.name}'),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.theme.colors.secondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: _AboutBody(
              about: _about,
              bio: _bio,
              linkColor: _linkColor,
              wide: AppLayout.desktopContentWidth(context) >= 760,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopHero(ArtistDetail artist) {
    final theme = context.theme;
    final songs = _songs;

    return SizedBox(
      height: _desktopHeroHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          24,
          DesktopLayout.topBarHeight + 16,
          24,
          24,
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _ArtistAvatar(
                  image: _image,
                  size: 200,
                  onError: () => _imageFailed(_image),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _CircleButton(
                  icon: Icons.play_arrow_rounded,
                  size: 52,
                  iconSize: 32,
                  background: theme.colors.primary,
                  foreground: theme.colors.primaryForeground,
                  onTap: songs == null || songs.isEmpty ? null : _playSongs,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.xl4.copyWith(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      height: 1.15,
                      shadows: const [
                        Shadow(blurRadius: 14, color: Colors.black45),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                _starButton(40),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopLatest(Album album) {
    final theme = context.theme;
    final coverArt = album.coverArt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Latest Release'),
        const SizedBox(height: 14),
        TapArea(
          onTap: () => context.push('/library/album/${album.id}'),
          borderRadius: 8,
          child: Row(
            children: [
              _SquareCover(
                url: coverArt != null
                    ? _subsonic.cachedCoverArtUrl(coverArt, size: 300)
                    : null,
                size: 150,
                radius: 8,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (album.year != null && album.year! > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${album.year}',
                          style: theme.typography.xs.copyWith(
                            color: theme.colors.mutedForeground,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    Text(
                      album.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.md.copyWith(
                        color: theme.colors.foreground,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _songCount(album.songCount),
                      style: theme.typography.sm.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PillButton(
                      icon: Icons.play_arrow_rounded,
                      label: 'Play',
                      onTap: () => _playAlbum(album),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _desktopLayout() {
    final artist = _artist!;
    final latest = _latestAlbum;
    final songs = _songs;
    final similar = _info?.similarArtists ?? const <Artist>[];
    final wide = AppLayout.desktopContentWidth(context) >= 860;
    final showSongs = songs == null || songs.isNotEmpty;

    final latestBlock = latest != null ? _desktopLatest(latest) : null;
    final songsBlock = showSongs ? _desktopSongs(songs) : null;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _desktopHeroHeight + 220,
          child: _HeroBackdrop(color: _heroColor),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _desktopHero(artist),
            if (latestBlock != null || songsBlock != null)
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 20),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (latestBlock != null) ...[
                            SizedBox(width: 330, child: latestBlock),
                            const SizedBox(width: 32),
                          ],
                          Expanded(child: songsBlock ?? const SizedBox()),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (latestBlock != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 24),
                              child: latestBlock,
                            ),
                          if (latestBlock != null && songsBlock != null)
                            const SizedBox(height: 28),
                          ?songsBlock,
                        ],
                      ),
              ),
            if (artist.albums.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: _albumsSection(artist.albums, 24),
              ),
            if (similar.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _similarSection(similar, 24),
              ),
            if (_hasAbout) _desktopAbout(),
            const SizedBox(height: 32),
          ],
        ),
      ],
    );
  }

  Widget _desktopSongs(List<Song>? songs) {
    final title = _SectionTitle(_songsRanked ? 'Top Songs' : 'Songs');
    if (songs == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, const SizedBox(height: 14), _songsLoading(204)],
      );
    }

    final rows = min(songs.length, 3);
    final columns = (songs.length / rows).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 10),
        SizedBox(
          height: 68.0 * rows,
          child: _dragScroll(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 12),
              itemCount: columns,
              itemBuilder: (context, column) {
                final start = column * rows;
                final end = min(start + rows, songs.length);
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 300,
                    child: Column(
                      children: [
                        for (var i = start; i < end; i++) _songRow(songs, i),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _extractAccent(List<ImageProvider> sources) async {
    for (final source in sources) {
      try {
        final palette = await PaletteGenerator.fromImageProvider(
          source,
          size: const Size(200, 200),
        );
        final color =
            palette.vibrantColor?.color ?? palette.dominantColor?.color;
        if (!mounted || sources.first != _accentSource) return;
        if (color == null) continue;
        setState(() => _accent = color);
        return;
      } catch (_) {}
    }
  }

  void _imageFailed(ImageProvider? image) {
    if (image == null || _failedImages.contains(image)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_failedImages.add(image)) return;
      setState(() {});
      _refreshAccent();
    });
  }

  Future<void> _load() async {
    final provider = context.read<SubsonicProvider>();
    final account = provider.activeAccount;
    if (account == null) {
      setState(() {
        _error = 'No active account';
        _loading = false;
      });
      return;
    }

    final subsonic = provider.subsonic;
    final artist = await subsonic.getArtistDetail(widget.artistId);
    if (!mounted) return;
    if (artist == null) {
      setState(() {
        _error = provider.isOffline
            ? 'Artists are not available offline'
            : 'Artist not found';
        _loading = false;
      });
      return;
    }

    artist.albums.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
    setState(() {
      _artist = artist;
      _starred = artist.starred != null;
      _loading = false;
    });
    _refreshAccent();
    unawaited(_loadSongs(subsonic, artist));
    unawaited(_loadInfo(subsonic, account.id, artist));
  }

  Future<void> _loadInfo(
    Subsonic subsonic,
    String accountId,
    ArtistDetail artist,
  ) async {
    final info = await subsonic.getArtistInfo(artist.id);
    if (!mounted) return;
    setState(() => _info = info);
    _refreshAccent();

    final about = await artistAboutService.load(
      accountId,
      artistId: artist.id,
      name: artist.name,
      musicBrainzId: artist.musicBrainzId ?? info?.musicBrainzId,
    );
    if (!mounted) return;
    setState(() => _about = about);
    _refreshAccent();
  }

  Future<void> _loadSongs(Subsonic subsonic, ArtistDetail artist) async {
    var ranked = true;
    var songs = await subsonic.getTopSongs(artist.name);
    if (songs.isEmpty) {
      songs = await subsonic.getArtistSongs(artist.id, artist.name);
    }
    if (songs.isEmpty) {
      ranked = false;
      for (final album in artist.albums.take(2)) {
        final detail = await subsonic.getAlbum(album.id);
        if (detail == null) continue;
        orderSongsByDisc(detail.songs);
        songs = [...songs, ...detail.songs];
      }
      songs = songs.take(20).toList();
    }
    if (!mounted) return;
    setState(() {
      _songs = songs;
      _songsRanked = ranked;
    });
  }

  Widget _mobileHero(ArtistDetail artist) {
    final theme = context.theme;
    final image = _image;
    final width = MediaQuery.sizeOf(context).width;
    final topPadding = MediaQuery.paddingOf(context).top;
    final name = Text(
      artist.name,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.xl2.copyWith(
        color: Colors.white,
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.15,
        shadows: const [Shadow(blurRadius: 14, color: Colors.black45)],
      ),
    );

    if (image == null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(24, topPadding + 76, 24, 0),
        child: Column(
          children: [
            const _ArtistAvatar(image: null, size: 180),
            const SizedBox(height: 24),
            name,
          ],
        ),
      );
    }

    return SizedBox(
      height: min(width, 420.0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0.0, 0.5, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: Image(
              image: image,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) {
                _imageFailed(image);
                return const SizedBox.expand();
              },
            ),
          ),
          Positioned(left: 24, right: 24, bottom: 0, child: name),
        ],
      ),
    );
  }

  Widget _mobileLatest(Album album) {
    final theme = context.theme;
    final coverArt = album.coverArt;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: TapArea(
        onTap: () => context.push('/library/album/${album.id}'),
        borderRadius: 16,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colors.border),
          ),
          child: Row(
            children: [
              _SquareCover(
                url: coverArt != null
                    ? _subsonic.cachedCoverArtUrl(coverArt, size: 300)
                    : null,
                size: 84,
                radius: 8,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.year != null && album.year! > 0
                          ? 'Latest release · ${album.year}'
                          : 'Latest release',
                      style: theme.typography.xs.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      album.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.sm.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _songCount(album.songCount),
                      style: theme.typography.xs.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _CircleButton(
                icon: Icons.play_arrow_rounded,
                size: 40,
                iconSize: 24,
                background: Colors.white.withValues(alpha: 0.12),
                foreground: Colors.white,
                onTap: () => _playAlbum(album),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileLayout() {
    final theme = context.theme;
    final artist = _artist!;
    final latest = _latestAlbum;
    final songs = _songs;
    final similar = _info?.similarArtists ?? const <Artist>[];
    final width = MediaQuery.sizeOf(context).width;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: min(width, 420.0) + 380,
          child: _HeroBackdrop(color: _heroColor),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _mobileHero(artist),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CircleButton(
                  icon: Icons.info_outline_rounded,
                  size: 44,
                  iconSize: 22,
                  background: Colors.white.withValues(alpha: 0.12),
                  foreground: Colors.white,
                  bordered: true,
                  onTap: _hasAbout ? _showAbout : null,
                ),
                const SizedBox(width: 20),
                _CircleButton(
                  icon: Icons.play_arrow_rounded,
                  size: 64,
                  iconSize: 40,
                  background: theme.colors.primary,
                  foreground: theme.colors.primaryForeground,
                  onTap: songs == null || songs.isEmpty ? null : _playSongs,
                ),
                const SizedBox(width: 20),
                _starButton(44),
              ],
            ),
            if (latest != null) _mobileLatest(latest),
            if (songs == null || songs.isNotEmpty) _mobileSongs(songs),
            if (artist.albums.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 28),
                child: _albumsSection(artist.albums, 20),
              ),
            if (similar.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _similarSection(similar, 20),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ],
    );
  }

  Widget _mobileSongs(List<Song>? songs) {
    final theme = context.theme;
    final canExpand = songs != null && songs.length > _mobileSongLimit;
    final shown = songs == null || _showAllSongs
        ? songs
        : songs.take(_mobileSongLimit).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SectionTitle(
              _songsRanked ? 'Top Songs' : 'Songs',
              trailing: canExpand
                  ? TapArea(
                      onTap: () =>
                          setState(() => _showAllSongs = !_showAllSongs),
                      child: Text(
                        _showAllSongs ? 'Show less' : 'See all',
                        style: theme.typography.xs.copyWith(
                          color: _linkColor,
                          letterSpacing: -0.1,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          if (shown == null)
            _songsLoading(120)
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (var i = 0; i < shown.length; i++) _songRow(songs!, i),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _playAlbum(Album album) async {
    final player = context.read<PlayerProvider>();
    final detail = await _subsonic.getAlbum(album.id);
    if (detail == null) return;
    orderSongsByDisc(detail.songs);
    await player.playAlbum(detail.songs);
  }

  Future<void> _playSongAt(List<Song> songs, int index) async {
    final player = context.read<PlayerProvider>();
    if (!player.isSongPlayable(songs[index])) return;
    await player.resetQueue();
    await player.playNow(songs[index]);
    if (index < songs.length - 1) {
      player.addBulkToQueue(songs.sublist(index + 1));
    }
  }

  void _playSongs() {
    final songs = _songs;
    if (songs == null || songs.isEmpty) return;
    context.read<PlayerProvider>().playAlbum(songs);
  }

  void _refreshAccent() {
    final latestCover = _latestAlbum?.coverArt;
    final sources = [
      ?_image,
      if (latestCover != null)
        coverArtProvider(_subsonic.cachedCoverArtUrl(latestCover, size: 300)),
    ];
    if (sources.isEmpty || sources.first == _accentSource) return;
    _accentSource = sources.first;
    unawaited(_extractAccent(sources));
  }

  void _showAbout() {
    showFSheet(
      context: context,
      side: FLayout.btt,
      useRootNavigator: true,
      mainAxisMaxRatio: 0.8,
      builder: (_) => _AboutSheet(
        name: _artist!.name,
        child: _AboutBody(about: _about, bio: _bio, linkColor: _linkColor),
      ),
    );
  }

  Widget _similarSection(List<Artist> artists, double inset) {
    final theme = context.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: const _SectionTitle('Similar Artists'),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 150,
          child: _dragScroll(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: inset),
              itemCount: artists.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, i) {
                final artist = artists[i];
                final coverArt = artist.coverArt;
                return TapArea(
                  onTap: () => context.push('/library/artist/${artist.id}'),
                  borderRadius: 8,
                  child: SizedBox(
                    width: 100,
                    child: Column(
                      children: [
                        _ArtistAvatar(
                          image: coverArt != null
                              ? coverArtProvider(
                                  _subsonic.cachedCoverArtUrl(
                                    coverArt,
                                    size: 200,
                                  ),
                                )
                              : null,
                          size: 100,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          artist.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.sm.copyWith(
                            color: theme.colors.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _songRow(List<Song> songs, int index) {
    final song = songs[index];
    return SongRow(
      song: song,
      subsonic: _subsonic,
      subtitle: song.album ?? '',
      playingColor: _linkColor,
      onPlay: () => _playSongAt(songs, index),
    );
  }

  Widget _songsLoading(double height) => SizedBox(
    height: height,
    child: const Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      ),
    ),
  );

  Widget _starButton(double size) => _CircleButton(
    icon: _starred ? Icons.star_rounded : Icons.star_border_rounded,
    size: size,
    iconSize: size * 0.5,
    background: Colors.white.withValues(alpha: 0.12),
    foreground: _starred ? Colors.yellow[700]! : Colors.white,
    bordered: true,
    onTap: _toggleStar,
  );

  Future<void> _toggleStar() async {
    final artist = _artist;
    if (artist == null) return;
    final subsonic = _subsonic;
    final next = !_starred;
    setState(() => _starred = next);
    final ok = next
        ? await subsonic.starArtist(artist.id)
        : await subsonic.unstarArtist(artist.id);
    if (!ok && mounted) setState(() => _starred = !next);
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final Color background;
  final Color foreground;
  final bool bordered;
  final VoidCallback? onTap;

  const _CircleButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.bordered = false,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: AnimatedOpacity(
        opacity: onTap != null ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: TapArea(
          onTap: onTap,
          borderRadius: size / 2,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: background,
              border: bordered
                  ? Border.all(color: context.theme.colors.border)
                  : null,
            ),
            child: Icon(icon, size: iconSize, color: foreground),
          ),
        ),
      ),
    );
  }
}

class _HeroBackdrop extends StatelessWidget {
  final Color color;

  const _HeroBackdrop({required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOut,
        builder: (context, value, _) {
          final tone = value ?? color;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tone,
                  tone.withValues(alpha: 0.6),
                  tone.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LinkText extends StatelessWidget {
  final String label;
  final String url;
  final Color color;

  const _LinkText({
    required this.label,
    required this.url,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => launchUrl(Uri.parse(url)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.theme.typography.xs.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new_rounded, size: 12, color: color),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
          decoration: BoxDecoration(
            color: AppColors.mutedButtonColor,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: theme.colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: theme.colors.foreground),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.typography.xs.copyWith(
                  color: theme.colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionTitle(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.theme.typography.lg.copyWith(
              color: context.theme.colors.foreground,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              height: 1.3,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _SquareCover extends StatelessWidget {
  final String? url;
  final double size;
  final double radius;

  const _SquareCover({
    required this.url,
    required this.size,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final placeholder = Container(
      width: size,
      height: size,
      color: colors.muted,
      child: Icon(Icons.album, color: colors.mutedForeground, size: size * 0.4),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url != null
          ? Image(
              image: coverArtProvider(url!),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            )
          : placeholder,
    );
  }
}
