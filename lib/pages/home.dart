import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

final fakeAlbums = List.generate(
  10,
  (index) => Album(
    id: 'fake_$index',
    name: 'Album $index',
    artist: 'Artist $index',
    coverArt: null,
    songCount: 0,
    duration: 0,
  ),
);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _AlbumCard extends StatefulWidget {
  final Album album;
  final Subsonic subsonic;
  final String type = 'album';

  const _AlbumCard({required this.album, required this.subsonic});

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard> {
  static const double _cardWidth = 150.0;
  late final String? _coverUrl;

  @override
  Widget build(BuildContext context) {
    const cardWidth = _cardWidth;

    return GestureDetector(
      onTap: () => context.push('/library/album/${widget.album.id}'),
      child: SizedBox(
        width: cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _coverUrl != null
                  ? Image.network(
                      _coverUrl,
                      width: cardWidth,
                      height: cardWidth,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: cardWidth,
                          height: cardWidth,
                          decoration: BoxDecoration(
                            color: context.theme.colors.muted,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      },
                      errorBuilder: (ctx, err, stack) => Container(
                        width: cardWidth,
                        height: cardWidth,
                        color: context.theme.colors.muted,
                        child: Icon(
                          Icons.album,
                          color: context.theme.colors.mutedForeground,
                          size: 40,
                        ),
                      ),
                    )
                  : Container(
                      width: cardWidth,
                      height: cardWidth,
                      color: context.theme.colors.muted,
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.album.name,
              style: context.theme.typography.sm.copyWith(
                fontWeight: FontWeight.bold,
                color: context.theme.colors.foreground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.album.artist,
              style: context.theme.typography.xs.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _coverUrl = widget.album.coverArt != null
        ? widget.subsonic.cachedCoverArtUrl(widget.album.coverArt!, size: 300)
        : null;
  }
}

class _HomePageState extends State<HomePage> {
  List<Album>? _recentAlbums;
  List<Album>? _starredAlbums;
  bool _loading = true;
  String? _prevAccountId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubsonicProvider>();

    if (provider.activeAccount == null) {
      return _NoAccountView();
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _HorizontalCarousel(
          title: 'Recently Added',
          albums: _recentAlbums ?? [],
          subsonic: provider.subsonic,
          isLoading: _loading,
        ),
        _HorizontalCarousel(
          title: 'Starred',
          albums: _starredAlbums ?? [],
          subsonic: provider.subsonic,
          isLoading: _loading,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<SubsonicProvider>();
    final currentId = provider.activeAccount?.id;
    if (currentId != _prevAccountId) {
      _prevAccountId = currentId;
      _fetchAlbums();
    }
  }

  Future<void> _fetchAlbums() async {
    final provider = context.read<SubsonicProvider>();
    if (provider.activeAccount == null) {
      setState(() {
        _loading = false;
        _recentAlbums = null;
        _starredAlbums = null;
      });
      return;
    }

    setState(() => _loading = true);

    final results = await Future.wait([
      provider.subsonic.getAlbumList2('newest', size: 20),
      provider.subsonic.getAlbumList2('starred', size: 20),
    ]);

    if (mounted) {
      setState(() {
        _recentAlbums = results[0];
        _starredAlbums = results[1];
        _loading = false;
      });
    }
  }
}

class _HorizontalCarousel extends StatelessWidget {
  final String title;
  final List<Album> albums;
  final Subsonic subsonic;
  final bool isLoading;

  const _HorizontalCarousel({
    required this.title,
    required this.albums,
    required this.subsonic,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading && albums.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              title,
              style: context.theme.typography.xl.copyWith(
                fontWeight: FontWeight.bold,
                color: context.theme.colors.foreground,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // fall back to fake albums if the real ones aren't loaded yet, to show the skeleton effect
          Skeletonizer(
            enabled: isLoading,
            effect: ShimmerEffect(
              baseColor: context.theme.colors.muted,
              highlightColor: context.theme.colors.muted.withValues(alpha: 0.5),
            ),
            child: !isLoading && albums.isEmpty
                ? SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        'It feels empty in here...',
                        style: context.theme.typography.md.copyWith(
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                    ),
                  )
                : SizedBox(
                    height: 210,
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
                        itemCount:
                            albums.length +
                            (albums.isEmpty ? fakeAlbums.length : 0),
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: _AlbumCard(
                              album: albums.isNotEmpty
                                  ? albums[index]
                                  : fakeAlbums[index - albums.length],
                              subsonic: subsonic,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NoAccountView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // background of a bunch of shimmering album cards in a row
    // so grid based layout that it looks like a music library, but the cards are just gray boxes with a shimmer effect
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'No account connected',
            style: context.theme.typography.xl.copyWith(
              fontWeight: FontWeight.bold,
              color: context.theme.colors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Please add an account to view your music library.',
            style: context.theme.typography.md.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
