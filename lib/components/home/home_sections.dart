import 'dart:async';
import 'dart:math';

import 'package:cosmodrome/components/album_card.dart';
import 'package:cosmodrome/components/desktop/desktop_song_popover.dart';
import 'package:cosmodrome/components/home/featured_spotlight.dart';
import 'package:cosmodrome/components/library/song_grid_item.dart';
import 'package:cosmodrome/components/mobile/song_context_sheet.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/services/offline_cache_service.dart';
import 'package:cosmodrome/services/play_history_service.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/cover_art/cover_art_provider.dart';
import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:cosmodrome/utils/tap_area.dart';
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

final homeSections = <HomeSectionDefinition>[
  CustomHomeSection(
    id: 'featured',
    title: 'Featured',
    builder: (key, subsonic, accountId, isOffline) => Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 16),
      child: FeaturedSpotlight(
        subsonic: subsonic,
        accountId: accountId,
        isOffline: isOffline,
      ),
    ),
  ),
  HomeSection<Song>(
    id: 'recently_played_songs',
    title: 'Recently Played',
    rowsPerColumn: 4,
    itemWidth: 300,
    height: 68,
    maxItems: 16,
    showSkeleton: false,
    listenable: playHistoryService,
    load: (ctx) async {
      await playHistoryService.ensureLoaded(ctx.accountId);
      return playHistoryService.songs(ctx.accountId);
    },
    placeholders: const [],
    itemBuilder: (context, song, ctx) => _SongRow(song: song, ctx: ctx),
  ),
  HomeSection<Playlist>(
    id: 'recently_played_playlists',
    title: 'Recently Played Playlists',
    showSkeleton: false,
    listenable: playHistoryService,
    load: (ctx) async {
      await playHistoryService.ensureLoaded(ctx.accountId);
      return playHistoryService.playlists(ctx.accountId);
    },
    placeholders: const [],
    itemBuilder: (context, playlist, ctx) =>
        _PlaylistCard(playlist: playlist, subsonic: ctx.subsonic),
  ),
  albumListSection(id: 'recent', title: 'Recently Played Albums'),
  albumListSection(
    id: 'newest',
    title: 'Newly Added',
    seeAllRoute: '/library/recent',
    loadCached: offlineCacheService.loadRecentAlbums,
    saveCached: offlineCacheService.saveRecentAlbums,
  ),
  albumListSection(id: 'frequent', title: 'Most Played'),
  albumListSection(
    id: 'starred',
    title: 'Starred',
    seeAllRoute: '/library/starred',
    loadCached: offlineCacheService.loadStarredAlbums,
    saveCached: offlineCacheService.saveStarredAlbums,
  ),
];

final _sectionMemory = <String, List<Object?>>{};

HomeSection<Album> albumListSection({
  required String id,
  required String title,
  String? type,
  String? seeAllRoute,
  Future<List<Album>?> Function(String accountId)? loadCached,
  Future<void> Function(String accountId, List<Album> items)? saveCached,
}) {
  return HomeSection<Album>(
    id: id,
    title: title,
    seeAllRoute: seeAllRoute,
    load: (ctx) => ctx.subsonic.getAlbumList2(
      type ?? id,
      size: 20,
      forceRefresh: ctx.forceRefresh,
    ),
    loadCached:
        loadCached ??
        (accountId) => offlineCacheService.loadAlbumList(accountId, id),
    saveCached:
        saveCached ??
        (accountId, items) =>
            offlineCacheService.saveAlbumList(accountId, id, items),
    placeholders: fakeAlbums,
    itemBuilder: (context, album, ctx) =>
        AlbumCard(album: album, subsonic: ctx.subsonic),
  );
}

class CustomHomeSection implements HomeSectionDefinition {
  @override
  final String id;
  @override
  final String title;
  final Widget Function(
    Key key,
    Subsonic subsonic,
    String accountId,
    bool isOffline,
  )
  builder;

  const CustomHomeSection({
    required this.id,
    required this.title,
    required this.builder,
  });

  @override
  Widget buildView({
    required Key key,
    required Subsonic subsonic,
    required String accountId,
    required bool isOffline,
  }) => builder(key, subsonic, accountId, isOffline);
}

class HomeSection<T> implements HomeSectionDefinition {
  @override
  final String id;
  @override
  final String title;
  final String? seeAllRoute;
  final Future<List<T>> Function(HomeSectionContext ctx) load;
  final Future<List<T>?> Function(String accountId)? loadCached;
  final Future<void> Function(String accountId, List<T> items)? saveCached;
  final Widget Function(BuildContext context, T item, HomeSectionContext ctx)
  itemBuilder;
  final List<T> placeholders;
  final Listenable? listenable;
  final bool showSkeleton;
  final double height;
  final double itemWidth;
  final int rowsPerColumn;
  final int maxItems;

  const HomeSection({
    required this.id,
    required this.title,
    required this.load,
    required this.itemBuilder,
    required this.placeholders,
    this.seeAllRoute,
    this.loadCached,
    this.saveCached,
    this.listenable,
    this.showSkeleton = true,
    this.height = 210,
    this.itemWidth = 150,
    this.rowsPerColumn = 1,
    this.maxItems = 10,
  });

  @override
  Widget buildView({
    required Key key,
    required Subsonic subsonic,
    required String accountId,
    required bool isOffline,
  }) => HomeSectionView<T>(
    key: key,
    section: this,
    subsonic: subsonic,
    accountId: accountId,
    isOffline: isOffline,
  );
}

class HomeSectionContext {
  final Subsonic subsonic;
  final String accountId;
  final bool isOffline;
  final bool forceRefresh;

  const HomeSectionContext({
    required this.subsonic,
    required this.accountId,
    required this.isOffline,
    this.forceRefresh = false,
  });
}

abstract interface class HomeSectionDefinition {
  String get id;
  String get title;

  Widget buildView({
    required Key key,
    required Subsonic subsonic,
    required String accountId,
    required bool isOffline,
  });
}

class HomeSectionView<T> extends StatefulWidget {
  final HomeSection<T> section;
  final Subsonic subsonic;
  final String accountId;
  final bool isOffline;

  const HomeSectionView({
    super.key,
    required this.section,
    required this.subsonic,
    required this.accountId,
    required this.isOffline,
  });

  @override
  State<HomeSectionView<T>> createState() => _HomeSectionViewState<T>();
}

abstract interface class ReloadableHomeSection {
  Future<void> reload({bool force = false});
}

class _HomeSectionViewState<T> extends State<HomeSectionView<T>>
    implements ReloadableHomeSection {
  List<T>? _items;
  bool _loading = true;
  int _loadGeneration = 0;
  bool _stale = false;

  bool get _visible => ModalRoute.of(context)?.isCurrent ?? true;

  String get _memoryKey => '${widget.accountId}:${_section.id}';
  HomeSection<T> get _section => widget.section;

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final showSkeleton =
        _section.showSkeleton && _loading && (items == null || items.isEmpty);

    Widget child;
    if (showSkeleton) {
      child = _buildSection(context, _section.placeholders, skeleton: true);
    } else if (items == null || items.isEmpty) {
      child = const SizedBox(width: double.infinity);
    } else {
      child = _buildSection(context, items);
    }

    return SizedBox(
      width: double.infinity,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topLeft,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [...previous, ?current],
          ),
          child: KeyedSubtree(
            key: ValueKey(showSkeleton ? 'skeleton' : 'content'),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(HomeSectionView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section.listenable != _section.listenable) {
      oldWidget.section.listenable?.removeListener(_onSourceChanged);
      _section.listenable?.addListener(_onSourceChanged);
    }
    if (oldWidget.isOffline && !widget.isOffline) unawaited(reload());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stale && _visible) {
      _stale = false;
      unawaited(reload());
    }
  }

  @override
  void dispose() {
    _section.listenable?.removeListener(_onSourceChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final remembered = _sectionMemory[_memoryKey];
    if (remembered != null) {
      _items = remembered.cast<T>();
      _loading = false;
    }
    _section.listenable?.addListener(_onSourceChanged);
    unawaited(reload());
  }

  @override
  Future<void> reload({bool force = false}) async {
    final generation = ++_loadGeneration;
    final accountId = widget.accountId;
    final ctx = HomeSectionContext(
      subsonic: widget.subsonic,
      accountId: accountId,
      isOffline: widget.isOffline,
      forceRefresh: force,
    );

    if (_items == null && _section.loadCached != null) {
      final cached = await _section.loadCached!(accountId);
      if (cached != null && generation == _loadGeneration) _apply(cached);
    }

    if (widget.isOffline && _section.loadCached != null) {
      _stopLoading(generation);
      return;
    }

    try {
      final fresh = await _section.load(ctx);
      if (generation != _loadGeneration) return;
      _apply(fresh);
      if (_section.saveCached != null) {
        unawaited(_section.saveCached!(accountId, fresh));
      }
    } catch (_) {
      _stopLoading(generation);
    }
  }

  void _apply(List<T> items) {
    final trimmed = items.take(_section.maxItems).toList(growable: false);
    _sectionMemory[_memoryKey] = trimmed;
    if (!mounted) return;
    if (!_visible) {
      _stale = true;
      return;
    }
    setState(() {
      _items = trimmed;
      _loading = false;
    });
  }

  Widget _buildSection(
    BuildContext context,
    List<T> items, {
    bool skeleton = false,
  }) {
    if (items.isEmpty) return const SizedBox(width: double.infinity);
    final colors = context.theme.colors;
    final ctx = HomeSectionContext(
      subsonic: widget.subsonic,
      accountId: widget.accountId,
      isOffline: widget.isOffline,
    );
    final rows = min(items.length, _section.rowsPerColumn);
    final columnCount = (items.length / rows).ceil();

    final list = SizedBox(
      height: _section.height * rows,
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
          itemCount: columnCount,
          itemBuilder: (context, column) {
            final start = column * rows;
            final end = (start + rows).clamp(0, items.length);
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: _section.itemWidth,
                child: rows == 1
                    ? _section.itemBuilder(context, items[start], ctx)
                    : Column(
                        children: [
                          for (var i = start; i < end; i++)
                            _section.itemBuilder(context, items[i], ctx),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _section.title,
                  style: context.theme.typography.md.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.foreground,
                    letterSpacing: -0.1,
                  ),
                ),
                if (_section.seeAllRoute != null)
                  TapArea(
                    onTap: () => context.push(_section.seeAllRoute!),
                    child: Text(
                      'See all',
                      style: context.theme.typography.xs.copyWith(
                        color: AppColors.auraColor,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          skeleton
              ? Skeletonizer(
                  effect: ShimmerEffect(
                    baseColor: colors.muted,
                    highlightColor: colors.muted.withValues(alpha: 0.5),
                  ),
                  child: list,
                )
              : list,
        ],
      ),
    );
  }

  // offstage pages must not change shape, see flutter/flutter#161718
  void _onSourceChanged() {
    if (!mounted || !_visible) {
      _stale = true;
      return;
    }
    unawaited(reload());
  }

  void _stopLoading(int generation) {
    if (generation == _loadGeneration && mounted && _loading) {
      if (!_visible) {
        _stale = true;
        return;
      }
      setState(() => _loading = false);
    }
  }
}

class _PlaylistCard extends StatelessWidget {
  static const double _cardWidth = 150.0;

  final Playlist playlist;
  final Subsonic subsonic;

  const _PlaylistCard({required this.playlist, required this.subsonic});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final coverUrl = playlist.coverArt != null
        ? subsonic.cachedCoverArtUrl(playlist.coverArt!, size: 300)
        : null;
    final placeholder = Container(
      width: _cardWidth,
      height: _cardWidth,
      color: colors.muted,
      child: Icon(Icons.queue_music, color: colors.mutedForeground, size: 40),
    );

    return GestureDetector(
      onTap: () => context.push('/library/playlist/${playlist.id}'),
      child: SizedBox(
        width: _cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: coverUrl != null
                  ? Image(
                      image: coverArtProvider(coverUrl),
                      width: _cardWidth,
                      height: _cardWidth,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => placeholder,
                    )
                  : placeholder,
            ),
            const SizedBox(height: 6),
            Text(
              playlist.name,
              style: context.theme.typography.sm.copyWith(
                fontWeight: FontWeight.w400,
                color: colors.foreground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${playlist.songCount} song${playlist.songCount == 1 ? '' : 's'}',
              style: context.theme.typography.xs.copyWith(
                color: colors.mutedForeground,
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

class _SongRow extends StatelessWidget {
  final Song song;
  final HomeSectionContext ctx;

  const _SongRow({required this.song, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (song.artist?.isNotEmpty == true) song.artist!,
      if (song.album?.isNotEmpty == true) song.album!,
    ].join(' · ');
    final mobile = isMobileView(context);

    return SongGridItem(
      title: song.title,
      subtitle: subtitle,
      imageUrl: song.coverArt != null
          ? ctx.subsonic.cachedCoverArtUrl(song.coverArt!, size: 120)
          : null,
      onPlay: () => context.read<PlayerProvider>().playNow(song),
      onLongPress: mobile ? () => showSongContextSheet(context, song) : null,
      onContextMenu: mobile
          ? null
          : (pos) => showSongContextMenuAt(context, song, pos),
      trailingBuilder: mobile
          ? null
          : (context, hovered) =>
                _SongRowMenuButton(song: song, hovered: hovered),
    );
  }
}

// the ... button, popover only mounted while hovered or open to keep rows cheap
class _SongRowMenuButton extends StatefulWidget {
  final Song song;
  final bool hovered;

  const _SongRowMenuButton({required this.song, required this.hovered});

  @override
  State<_SongRowMenuButton> createState() => _SongRowMenuButtonState();
}

class _SongRowMenuButtonState extends State<_SongRowMenuButton> {
  bool _mounted = false;
  bool _open = false;
  Timer? _unmountTimer;

  @override
  Widget build(BuildContext context) {
    if (!_mounted) return const SizedBox.square(dimension: 28);
    final colors = context.theme.colors;

    return DesktopSongPopover(
      song: widget.song,
      onGoToAlbum: goToAlbumAction(context, widget.song),
      onShownChanged: _onShownChanged,
      builder: (context, controller) => AnimatedOpacity(
        opacity: widget.hovered || _open ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: IconButton(
          icon: Icon(Icons.more_horiz, size: 16, color: colors.mutedForeground),
          onPressed: controller.toggle,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(_SongRowMenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hovered && !_mounted) {
      _unmountTimer?.cancel();
      _mounted = true;
    } else if (!widget.hovered && oldWidget.hovered) {
      _scheduleUnmount();
    }
  }

  @override
  void dispose() {
    _unmountTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _mounted = widget.hovered;
  }

  bool get _visible => ModalRoute.isCurrentOf(context) ?? true;

  void _onShownChanged(bool shown) {
    if (!mounted) return;
    if (_visible) {
      setState(() => _open = shown);
    } else {
      _open = shown;
    }
    if (!shown) _scheduleUnmount();
  }

  void _scheduleUnmount() {
    _unmountTimer?.cancel();
    _unmountTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || widget.hovered || _open || !_mounted) return;
      if (!_visible) return;
      setState(() => _mounted = false);
    });
  }
}
