import 'dart:async';

import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/services/offline_cache_service.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/cover_art_provider.dart';
import 'package:cosmodrome/utils/sidebar_notifier.dart';
import 'package:cosmodrome/utils/tap_area.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

final fakePlaylists = List.generate(
  10,
  (index) => Playlist(
    id: 'fake_$index',
    name: 'Playlist $index',
    coverArt: null,
    songCount: 0,
    duration: 0,
    owner: "you!",
  ),
);

final homeItems = [
  _HomeCard(icon: FIcons.history, title: 'Recently Added', onTap: null),
  _HomeCard(icon: FIcons.shuffle, title: 'Random', onTap: null),
  _HomeCard(icon: FIcons.star, title: 'Starred', onTap: null),
  _HomeCard(
    icon: FIcons.clockArrowDown,
    title: 'Frequently played',
    onTap: null,
  ),
];

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
  late String? _coverUrl;

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
                  ? Image(
                      image: coverArtProvider(_coverUrl!),
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
                fontWeight: FontWeight.w400,
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
  void didUpdateWidget(_AlbumCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.album.id != widget.album.id ||
        oldWidget.album.coverArt != widget.album.coverArt) {
      _updateCoverUrl();
    }
  }

  @override
  void initState() {
    super.initState();
    _updateCoverUrl();
  }

  void _updateCoverUrl() {
    _coverUrl = widget.album.coverArt != null
        ? widget.subsonic.cachedCoverArtUrl(widget.album.coverArt!, size: 300)
        : null;
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _HomeCard({required this.icon, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: colors.muted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colors.mutedForeground),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: context.theme.typography.xs.copyWith(
                  color: colors.mutedForeground,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
        SizedBox(height: 50),
        if (provider.isOffline)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _OfflineBanner(),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: homeItems[0]),
                  const SizedBox(width: 8),
                  Expanded(child: homeItems[1]),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: homeItems[2]),
                  const SizedBox(width: 8),
                  Expanded(child: homeItems[3]),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
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

  @override
  void dispose() {
    super.dispose();
    starredCountChanged.removeListener(_onStarOrPlaylistChanged);
    playlistsCountChanged.removeListener(_onStarOrPlaylistChanged);
    homeRefreshNotifier.removeListener(_onHomeRefreshRequested);
  }

  @override
  void initState() {
    super.initState();
    starredCountChanged.addListener(_onStarOrPlaylistChanged);
    playlistsCountChanged.addListener(_onStarOrPlaylistChanged);
    homeRefreshNotifier.addListener(_onHomeRefreshRequested);
  }

  Future<void> _fetchAlbums() async {
    final provider = context.read<SubsonicProvider>();
    final accountId = provider.activeAccount?.id;
    if (accountId == null) {
      setState(() {
        _loading = false;
        _recentAlbums = null;
        _starredAlbums = null;
      });
      return;
    }

    final cachedRecent = await offlineCacheService.loadRecentAlbums(accountId);
    final cachedStarred = await offlineCacheService.loadStarredAlbums(
      accountId,
    );

    if (provider.isOffline) {
      if (mounted) {
        setState(() {
          _recentAlbums = cachedRecent;
          _starredAlbums = cachedStarred;
          _loading = false;
        });
      }
      return;
    }

    if (mounted && (cachedRecent != null || cachedStarred != null)) {
      setState(() {
        _recentAlbums = cachedRecent;
        _starredAlbums = cachedStarred;
        _loading = false;
      });
    }

    if (!mounted) return;
    setState(() => _loading = _recentAlbums == null && _starredAlbums == null);

    try {
      final results = await Future.wait([
        provider.subsonic.getAlbumList2('newest', size: 20),
        provider.subsonic.getAlbumList2('starred', size: 20),
      ]);

      await Future.wait([
        offlineCacheService.saveRecentAlbums(accountId, results[0]),
        offlineCacheService.saveStarredAlbums(accountId, results[1]),
      ]);

      if (mounted) {
        setState(() {
          _recentAlbums = results[0];
          _starredAlbums = results[1];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _recentAlbums = cachedRecent;
          _starredAlbums = cachedStarred;
          _loading = false;
        });
      }
      unawaited(provider.checkConnectivity());
    }
  }

  void _onHomeRefreshRequested() {
    final completer = homeRefreshNotifier.value;
    if (completer == null || completer.isCompleted) return;
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await _fetchAlbums();
      if (!completer.isCompleted) completer.complete();
    });
  }

  void _onStarOrPlaylistChanged() {
    // defer until after current frame
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _fetchAlbums();
    });
  }
}

// ignore: must_be_immutable
class _HorizontalCarousel extends StatelessWidget {
  final String title;
  List<Album> albums = const [];
  final Subsonic subsonic;
  final bool isLoading;

  _HorizontalCarousel({
    required this.title,
    this.albums = const [],
    required this.subsonic,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading && albums.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: context.theme.typography.md.copyWith(
                  fontWeight: FontWeight.w500,
                  color: context.theme.colors.foreground,
                  letterSpacing: -0.1,
                ),
              ),

              TapArea(
                child: Text(
                  'See all',
                  style: context.theme.typography.xs.copyWith(
                    color: AppColors.auraColor,
                    letterSpacing: -0.1,
                  ),
                ),
                onTap: () {},
              ),
            ],
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

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1F00),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF5A3F00), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 14,
            color: Color(0xFFFFB300),
          ),
          const SizedBox(width: 8),
          const Text(
            'You are currently offline. Functionality is limited.',
            style: TextStyle(
              color: Color(0xFFFFB300),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              overflow: TextOverflow.fade,
            ),
          ),
        ],
      ),
    );
  }
}
