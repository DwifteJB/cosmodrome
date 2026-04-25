import 'dart:async';

import 'package:cosmodrome/components/shared_views/no_account_view.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/services/offline_cache_service.dart';
import 'package:cosmodrome/utils/cover_art_provider.dart';
import 'package:cosmodrome/utils/layout_page_mixin.dart';
import 'package:cosmodrome/utils/search_notifier.dart';
import 'package:cosmodrome/utils/tap_area.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _RecentSearchsItem extends StatelessWidget {
  final RecentSearch search;

  const _RecentSearchsItem({required this.search});

  @override
  Widget build(BuildContext context) {
    // get string
    String properEnum() {
      switch (search.type) {
        case RecentSearchEnum.album:
          return "Album";
        case RecentSearchEnum.artist:
          return "Artist";
        case RecentSearchEnum.playlist:
          return "Playlist";
        case RecentSearchEnum.song:
          return "Song";
      }
    }

    return Consumer2<SubsonicProvider, PlayerProvider>(
      builder: (context, subsonic, player, child) {
        return TapArea(
          onTap: () async {
            // depending on what this is, we change to a diff page
            var router = GoRouter.of(context);
            switch (search.type) {
              case RecentSearchEnum.album:
                router.push("/library/album/${search.id}");
                break;
              case RecentSearchEnum.artist:
                // router.push("/library/artist/${search.id}");
                // TODO: artist page :)
                break;
              case RecentSearchEnum.playlist:
                router.push("/library/playlist/${search.id}");
                break;
              case RecentSearchEnum.song:
                // PLAY THE SONG!!!!
                var song = await subsonic.subsonic.getSong(search.id);
                if (song != null) {
                  player.playNow(song);
                }
                break;
            }
          },
          child: Container(
            decoration: BoxDecoration(border: BoxBorder.symmetric()),
            child: ListTile(
              leading: Image(
                image: coverArtProvider(
                  subsonic.subsonic.cachedCoverArtUrl(search.artId, size: 100),
                ),
                width: 60,
                height: 60,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.black26,
                  child: const Icon(Icons.music_note, color: Colors.white54),
                ),
              ),
              title: Text(
                search.title,
                style: context.theme.typography.sm.copyWith(
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
              // subtitle: Text("${properEnum()} • ${search.subtitle}")
              subtitle: Row(
                children: [
                  Text(properEnum(), style: context.theme.typography.xs),
                  if (search.subtitle.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      '•',
                      style: context.theme.typography.xs3.copyWith(
                        color: context.theme.colors.mutedForeground,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        search.subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.typography.xs,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchPageState extends State<SearchPage> with LayoutPageMixin {
  static const Duration _searchDebounceDelay = Duration(milliseconds: 350);

  List<RecentSearch>? recentSearches;
  SearchResult? searchResult;

  bool isSearching = false;

  String localSearchQuery = '';
  Timer? _searchDebounceTimer;
  int _searchGeneration = 0;

  @override
  bool get isScrollable => true;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubsonicProvider>();

    if (provider.activeAccount == null) {
      return NoAccountView();
    }

    final result = searchResult;
    final hasResults =
        result != null &&
        (result.albums.isNotEmpty ||
            result.artists.isNotEmpty ||
            result.songs.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(height: 16),

          if (isSearching && localSearchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
          ],

          if (localSearchQuery.isNotEmpty && hasResults) ...[
            if (result.albums.isNotEmpty) ...[
              _SearchSectionHeader(
                title: 'Albums',
                count: result.albums.length,
              ),
              ...result.albums.map(
                (album) => _SearchResultTile(
                  imageUrl: provider.subsonic.cachedCoverArtUrl(
                    album.coverArt,
                    size: 160,
                  ),
                  title: album.name,
                  subtitle: album.artist,
                  trailing: '${album.songCount} songs',
                  onTap: () =>
                      GoRouter.of(context).push('/library/album/${album.id}'),
                ),
              ),
            ],
            if (result.artists.isNotEmpty) ...[
              _SearchSectionHeader(
                title: 'Artists',
                count: result.artists.length,
              ),
              ...result.artists.map(
                (artist) => _SearchResultTile(
                  imageUrl: provider.subsonic.cachedCoverArtUrl(
                    artist.coverArt,
                    size: 160,
                  ),
                  title: artist.name,
                  subtitle: 'Artist',
                  trailing: '${artist.albumCount} albums',
                  onTap: null,
                ),
              ),
            ],
            if (result.songs.isNotEmpty)
              _SearchSongsSection(
                songs: result.songs,
                onPlay: (songId) async {
                  final song = await provider.subsonic.getSong(songId);
                  if (song != null && mounted) {
                    context.read<PlayerProvider>().playNow(song);
                  }
                },
              ),
          ] else if (localSearchQuery.isNotEmpty &&
              !isSearching &&
              searchResult != null) ...[
            SizedBox(height: 16),
            Text(
              'No results found for "$localSearchQuery".',
              style: context.theme.typography.md,
            ),
          ],

          if (localSearchQuery == '' &&
              recentSearches != null &&
              recentSearches!.isNotEmpty) ...[
            ...recentSearches!.map(
              (search) => _RecentSearchsItem(search: search),
            ),
          ] else if (localSearchQuery == '') ...[
            SizedBox(height: 16),
            Text(
              'You have no recent searches.',
              style: context.theme.typography.md,
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    searchQuery.removeListener(_onSearchQueryChanged);
    super.dispose();
  }

  // listen to search query changes and trigger a rebuild to update the displayed query
  @override
  void initState() {
    super.initState();
    searchQuery.addListener(_onSearchQueryChanged);

    // load recent searches for the current account
    loadRecentSearches();
  }

  void loadRecentSearches() async {
    final provider = context.read<SubsonicProvider>();
    if (provider.activeAccount == null) return;

    final searches = await offlineCacheService.loadRecentSearches(
      provider.activeAccount!.id,
    );

    if (mounted) {
      setState(() {
        recentSearches = searches;
      });
    }
  }

  void _onSearchQueryChanged() {
    if (mounted && searchQuery.value != localSearchQuery) {
      setState(() {
        localSearchQuery = searchQuery.value;
      });

      _queueSearch(localSearchQuery);
    }
  }

  void _queueSearch(String query) {
    _searchDebounceTimer?.cancel();

    final normalizedQuery = query.trim();

    if (normalizedQuery.isEmpty) {
      setState(() {
        searchResult = null;
        isSearching = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
    });

    _searchDebounceTimer = Timer(_searchDebounceDelay, () async {
      final generation = ++_searchGeneration;
      final provider = context.read<SubsonicProvider>();
      final result = await provider.subsonic.search3(normalizedQuery);

      if (!mounted) return;

      if (generation != _searchGeneration ||
          normalizedQuery != localSearchQuery.trim()) {
        return;
      }

      setState(() {
        searchResult = result;
        isSearching = false;
      });
    });
  }
}

class _SearchResultTile extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback? onTap;

  const _SearchResultTile({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapArea(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.theme.colors.secondary.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image(
                image: coverArtProvider(imageUrl),
                width: 54,
                height: 54,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 54,
                  height: 54,
                  color: context.theme.colors.secondary,
                  child: const Icon(Icons.music_note),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.typography.sm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.typography.xs.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              trailing,
              style: context.theme.typography.xs.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SearchSectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: context.theme.typography.lg.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchSongsSection extends StatelessWidget {
  final List<SearchSong> songs;
  final Future<void> Function(String songId) onPlay;

  const _SearchSongsSection({required this.songs, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SearchSectionHeader(title: 'Songs', count: songs.length),
        ...songs.map(
          (song) => _SearchResultTile(
            imageUrl: context
                .read<SubsonicProvider>()
                .subsonic
                .cachedCoverArtUrl(song.coverArt, size: 160),
            title: song.title,
            subtitle: '${song.artist} • ${song.album}',
            trailing: _formatDuration(song.duration),
            onTap: () => onPlay(song.id),
          ),
        ),
      ],
    );
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '--:--';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
