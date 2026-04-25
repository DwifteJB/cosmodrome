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
  List<RecentSearch>? recentSearches;
  SearchResult? searchResult;

  String localSearchQuery = '';
  DateTime? lastQueryTime;

  @override
  bool get isScrollable => true;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubsonicProvider>();

    if (provider.activeAccount == null) {
      return NoAccountView();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(height: 16),

          _RecentSearchsItem(
            search: RecentSearch(
              id: "test",
              title: "THIS IS A MUST",
              subtitle: "Kanye West",
              artId: "test",
              type: RecentSearchEnum.song,
            ),
          ),
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
        lastQueryTime = DateTime.now();
      });
    }
  }
}
