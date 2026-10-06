import 'dart:async';
import 'dart:convert';

import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/services/offline_cache_service.dart'
    show SpotlightItem, offlineCacheService;
import 'package:cosmodrome/utils/cover_art/cover_art_provider.dart';
import 'package:cosmodrome/utils/logger/logger.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

final _fakeSpotlightItems = List.generate(
  3,
  (i) => SpotlightItem(
    albumId: 'fake_$i',
    albumName: 'Album Name',
    artistName: 'Artist Name',
    artistId: null,
    coverArt: null,
    description:
        'A short description about this artist and their unique sound.',
    accentColorValue: null,
  ),
);

final _spotlightMemory = <String, List<SpotlightItem>>{};

class FeaturedSpotlight extends StatefulWidget {
  final Subsonic subsonic;
  final String accountId;
  final bool isOffline;

  const FeaturedSpotlight({
    super.key,
    required this.subsonic,
    required this.accountId,
    required this.isOffline,
  });

  @override
  State<FeaturedSpotlight> createState() => _FeaturedSpotlightState();
}

class _FeaturedSpotlightState extends State<FeaturedSpotlight> {
  List<SpotlightItem>? _items;
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null && widget.isOffline) return const SizedBox.shrink();
    if (!_loading && (items == null || items.isEmpty)) {
      return const SizedBox.shrink();
    }

    final displayItems = _loading ? _fakeSpotlightItems : items!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Featured',
            style: context.theme.typography.md.copyWith(
              fontWeight: FontWeight.w500,
              color: context.theme.colors.foreground,
              letterSpacing: -0.1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        RepaintBoundary(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: SizedBox(
              key: ValueKey(_loading),
              height: 180,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  itemCount: displayItems.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _loading
                        ? const _SpotlightCardPlaceholder()
                        : _SpotlightCard(
                            item: displayItems[index],
                            subsonic: widget.subsonic,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    final remembered = _spotlightMemory[widget.accountId];
    if (remembered != null) {
      _items = remembered;
      _loading = false;
      return;
    }
    unawaited(_load());
  }

  Future<SpotlightItem?> _buildSpotlightItem(Album album) async {
    try {
      final mbFuture = _fetchMusicBrainzDisambiguation(album.artist);
      final wikiFuture = _fetchWikipediaExtract(album.name);

      final mbdesc = await mbFuture;
      final wikidesc = await wikiFuture;

      final description = (wikidesc != null && wikidesc.isNotEmpty)
          ? wikidesc
          : mbdesc;

      return SpotlightItem(
        albumId: album.id,
        albumName: album.name,
        artistName: album.artist,
        artistId: album.artistId,
        coverArt: album.coverArt,
        description: description,
        accentColorValue: null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchAndUpdate({bool display = true}) async {
    try {
      final albums = await widget.subsonic.getAlbumList2('random', size: 5);
      if (albums.isEmpty) {
        if (mounted && display) setState(() => _loading = false);
        return;
      }

      // build all at same time
      final results = await Future.wait(
        albums.map((a) => _buildSpotlightItem(a)),
      );
      final items = results.whereType<SpotlightItem>().toList();

      if (items.isNotEmpty) {
        unawaited(
          offlineCacheService.saveSpotlightItems(widget.accountId, items),
        );
      }

      if (!display) return;
      if (items.isNotEmpty) _spotlightMemory[widget.accountId] = items;
      if (mounted) {
        setState(() {
          if (items.isNotEmpty) _items = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && display) setState(() => _loading = false);
    }
  }

  Future<String?> _fetchMusicBrainzDisambiguation(String artistName) async {
    try {
      final uri = Uri.parse(
        'https://musicbrainz.org/ws/2/artist?query=${Uri.encodeComponent(artistName)}&fmt=json&limit=1',
      );

      loggerPrint("MB lookup for '$artistName' at $uri");
      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'Cosmodrome/1.0 (cosmodrome-app)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));

      loggerPrint("MB response for '$artistName': ${response.statusCode}");
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final artists = data['artists'] as List<dynamic>?;
      if (artists == null || artists.isEmpty) return null;
      return (artists.first as Map<String, dynamic>)['disambiguation']
          as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetchWikipediaExtract(String whatever) async {
    try {
      loggerPrint("get Wikipedia extract for '$whatever'");
      final uri = Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(whatever)}',
      );
      final response = await http
          .get(uri, headers: {'User-Agent': 'Cosmodrome/1.0 (cosmodrome-app)'})
          .timeout(const Duration(seconds: 8));

      loggerPrint("Wikipedia response for '$whatever': ${response.statusCode}");

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final extract = data['extract'] as String?;
      if (extract == null || extract.isEmpty) return null;
      return extract.length > 300 ? '${extract.substring(0, 297)}...' : extract;
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    final cached = await offlineCacheService.loadSpotlightItems(
      widget.accountId,
    );

    if (cached != null && cached.isNotEmpty) {
      _spotlightMemory[widget.accountId] = cached;
      if (mounted) {
        setState(() {
          _items = cached;
          _loading = false;
        });
      }
      if (widget.isOffline) return;
      unawaited(_fetchAndUpdate(display: false));
      return;
    }

    // No cache
    if (widget.isOffline) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    await _fetchAndUpdate();
  }
}

class _SpotlightCard extends StatelessWidget {
  static const double _cardWidth = 280.0;
  static const double _cardHeight = 180.0;

  final SpotlightItem item;
  final Subsonic subsonic;

  const _SpotlightCard({required this.item, required this.subsonic});

  @override
  Widget build(BuildContext context) {
    final coverUrl = item.coverArt != null
        ? subsonic.cachedCoverArtUrl(item.coverArt!, size: 560)
        : null;
    final accentColor = item.accentColor;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () =>
            context.push('/artist-detail/${item.albumId}', extra: item),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: _cardWidth,
            height: _cardHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: accentColor ?? context.theme.colors.muted),
                if (coverUrl != null)
                  Image(
                    image: coverArtProvider(coverUrl),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    gaplessPlayback: true,
                    frameBuilder: (context, child, frame, sync) {
                      if (sync) return child;
                      return AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        child: child,
                      );
                    },
                    errorBuilder: (context, err, stack) => ColoredBox(
                      color: accentColor ?? context.theme.colors.muted,
                    ),
                  ),
                if (accentColor != null)
                  ColoredBox(color: accentColor.withValues(alpha: 0.3)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.3, 1.0],
                      colors: [Colors.transparent, Color(0xCC000000)],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.artistName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black54),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.albumName,
                        style: const TextStyle(
                          color: Color(0xBFFFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.description != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          item.description!,
                          style: const TextStyle(
                            color: Color(0x99FFFFFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpotlightCardPlaceholder extends StatelessWidget {
  const _SpotlightCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: _SpotlightCard._cardWidth,
        height: _SpotlightCard._cardHeight,
        color: context.theme.colors.muted,
      ),
    );
  }
}
