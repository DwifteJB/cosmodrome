import 'dart:async';

import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/services/offline_cache_service.dart'
    show SpotlightItem;
import 'package:cosmodrome/utils/cover_art/cover_art_provider.dart';
import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ArtistDetailPage extends StatefulWidget {
  final SpotlightItem item;
  final String? artistId;

  const ArtistDetailPage({super.key, required this.item, this.artistId});

  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _AlbumCard extends StatelessWidget {
  static const double _size = 120.0;
  final Album album;
  final Subsonic subsonic;

  final Color? accentColor;

  const _AlbumCard({
    required this.album,
    required this.subsonic,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = album.coverArt != null
        ? subsonic.cachedCoverArtUrl(album.coverArt!, size: 300)
        : null;

    return GestureDetector(
      onTap: () => context.push('/library/album/${album.id}'),
      child: SizedBox(
        width: _size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: coverUrl != null
                  ? Image(
                      image: coverArtProvider(coverUrl),
                      width: _size,
                      height: _size,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, e, st) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(height: 6),
            Text(
              album.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (album.year != null && album.year! > 0)
              Text(
                '${album.year}',
                style: const TextStyle(color: Color(0x80FFFFFF), fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: _size,
    height: _size,
    decoration: BoxDecoration(
      color: accentColor?.withValues(alpha: 0.3) ?? const Color(0xFF2A2A2A),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(Icons.album, color: Color(0x80FFFFFF), size: 32),
  );
}

class _AlbumRow extends StatelessWidget {
  final List<Album> albums;
  final Subsonic subsonic;
  final Color? accentColor;

  const _AlbumRow({
    required this.albums,
    required this.subsonic,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 172,
      child: ScrollConfiguration(
        behavior: ScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.mouse,
            PointerDeviceKind.touch,
            PointerDeviceKind.trackpad,
          },
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: albums.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _AlbumCard(
              album: albums[i],
              subsonic: subsonic,
              accentColor: accentColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtistDetailPageState extends State<ArtistDetailPage> {
  List<Album>? _albums;
  bool _loadingAlbums = true;

  @override
  Widget build(BuildContext context) {
    final subsonic = context.read<SubsonicProvider>().subsonic;
    final item = widget.item;
    final accentColor = item.accentColor;
    final coverUrl = item.coverArt != null
        ? subsonic.cachedCoverArtUrl(item.coverArt!, size: 1200)
        : null;

    if (!isMobileView(context)) {
      return ColoredBox(
        color: const Color(0xFF111111),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DesktopHero(
                item: item,
                accentColor: accentColor,
                coverUrl: coverUrl,
              ),
              if (item.description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    item.description!,
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.6,
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 28, bottom: 14),
                child: Text(
                  'Related Albums',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              _buildAlbumSection(context, subsonic, accentColor),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            backgroundColor: const Color(0xFF111111),
            automaticallyImplyLeading: false,
            leading: _BackButton(accentColor: accentColor),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl != null)
                    Image(
                      image: coverArtProvider(coverUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, e, st) => ColoredBox(
                        color: accentColor ?? const Color(0xFF1A1A1A),
                      ),
                    )
                  else
                    ColoredBox(color: accentColor ?? const Color(0xFF1A1A1A)),
                  if (accentColor != null)
                    ColoredBox(color: accentColor.withValues(alpha: 0.25)),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.35, 1.0],
                        colors: [Colors.transparent, Color(0xFF111111)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.artistName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            shadows: [
                              Shadow(blurRadius: 10, color: Colors.black54),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.albumName,
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.2,
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
          ),
          if (item.description != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  item.description!,
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 14),
              child: Text(
                'Related Albums',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _buildAlbumSection(context, subsonic, accentColor),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(_fetchAlbums());
  }

  Widget _buildAlbumSection(
    BuildContext context,
    Subsonic subsonic,
    Color? accentColor,
  ) {
    if (_loadingAlbums) {
      return Skeletonizer(
        enabled: true,
        effect: ShimmerEffect(
          baseColor: const Color(0xFF222222),
          highlightColor: const Color(0xFF333333),
        ),
        child: _AlbumRow(
          albums: List.generate(
            5,
            (i) => Album(
              id: 'fake_$i',
              name: 'Album Name',
              artist: '',
              coverArt: null,
              songCount: 0,
              duration: 0,
            ),
          ),
          subsonic: subsonic,
          accentColor: accentColor,
        ),
      );
    }

    final albums = _albums;
    if (albums == null || albums.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'No albums found.',
          style: TextStyle(color: Color(0x80FFFFFF), fontSize: 13),
        ),
      );
    }

    return _AlbumRow(
      albums: albums,
      subsonic: subsonic,
      accentColor: accentColor,
    );
  }

  Future<void> _fetchAlbums() async {
    final id = widget.item.artistId;
    if (id == null || id.isEmpty) {
      if (mounted) setState(() => _loadingAlbums = false);
      return;
    }
    try {
      final subsonic = context.read<SubsonicProvider>().subsonic;
      final albums = await subsonic.getArtist(id);
      albums.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
      if (mounted) {
        setState(() {
          _albums = albums;
          _loadingAlbums = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAlbums = false);
    }
  }
}

class _BackButton extends StatelessWidget {
  final Color? accentColor;

  const _BackButton({this.accentColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pop(),
      child: Container(
        margin: const EdgeInsets.all(8),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }
}

class _DesktopHero extends StatelessWidget {
  final SpotlightItem item;
  final Color? accentColor;
  final String? coverUrl;

  const _DesktopHero({
    required this.item,
    required this.accentColor,
    required this.coverUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 320,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (coverUrl != null)
              Image(
                image: coverArtProvider(coverUrl!),
                fit: BoxFit.cover,
                errorBuilder: (ctx, e, st) =>
                    ColoredBox(color: accentColor ?? const Color(0xFF1A1A1A)),
              )
            else
              ColoredBox(color: accentColor ?? const Color(0xFF1A1A1A)),
            if (accentColor != null)
              ColoredBox(color: accentColor!.withValues(alpha: 0.25)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.35, 1.0],
                  colors: [Colors.transparent, Color(0xFF111111)],
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.artistName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black54)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.albumName,
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.2,
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
    );
  }
}
