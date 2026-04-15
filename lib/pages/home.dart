import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _AlbumCard extends StatefulWidget {
  final Album album;
  final Subsonic subsonic;

  const _AlbumCard({required this.album, required this.subsonic});

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard> {
  static const double _cardWidth = 150.0;
  late final String? _coverUrl;

  @override
  void initState() {
    super.initState();
    _coverUrl = widget.album.coverArt != null
        ? widget.subsonic.coverArtUrl(widget.album.coverArt!, size: 300)
        : null;
  }

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
                      decoration: BoxDecoration(
                        color: context.theme.colors.muted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.album,
                        color: context.theme.colors.mutedForeground,
                        size: 40,
                      ),
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
        _HorizontalCarousel(
          title: 'Recently Added',
          albums: _recentAlbums ?? [],
          subsonic: provider.subsonic,
        ),
        _HorizontalCarousel(
          title: 'Starred',
          albums: _starredAlbums ?? [],
          subsonic: provider.subsonic,
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

  const _HorizontalCarousel({
    required this.title,
    required this.albums,
    required this.subsonic,
  });

  @override
  Widget build(BuildContext context) {
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
          if (albums.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Nothing here yet',
                style: context.theme.typography.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
            )
          else
            SizedBox(
              height: 210,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: albums.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < albums.length - 1 ? 12 : 0,
                    ),
                    child: _AlbumCard(album: albums[index], subsonic: subsonic),
                  );
                },
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add an account to get started',
              style: context.theme.typography.xl.copyWith(
                color: context.theme.colors.foreground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FButton(
              onPress: () => context.push('/adduser'),
              child: const Text('Add Account'),
            ),
          ],
        ),
      ),
    );
  }
}
