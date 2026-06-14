// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:cosmodrome/components/album_card.dart';
import 'package:cosmodrome/components/shared_views/no_account_view.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/services/offline_cache_service.dart';
import 'package:cosmodrome/utils/cover_art/cover_art_provider.dart';
import 'package:cosmodrome/utils/layout_page_mixin.dart';
import 'package:cosmodrome/utils/notifiers/search_notifier.dart';
import 'package:cosmodrome/utils/tap_area.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Full desktop search results page (Apple-Music-style layout):
/// Top Results -> Artists -> Albums -> Songs.
class DesktopSearchPage extends StatefulWidget {
  const DesktopSearchPage({super.key});

  @override
  State<DesktopSearchPage> createState() => _DesktopSearchPageState();
}

/// A scored entry used to build the "Top Results" section.
class _TopResult {
  final double score;
  final SearchAlbum? album;
  final SearchArtist? artist;
  final SearchSong? song;

  const _TopResult({
    required this.score,
    this.album,
    this.artist,
    this.song,
  });
}

class _DesktopSearchPageState extends State<DesktopSearchPage>
    with LayoutPageMixin {
  static const Duration _debounceDelay = Duration(milliseconds: 350);

  SearchResult? _results;
  bool _loading = false;
  String _query = '';
  Timer? _debounce;
  int _generation = 0;

  @override
  bool get isScrollable => true;

  @override
  String? get pageTitle => 'Search';

  @override
  void initState() {
    super.initState();
    _query = searchQuery.value;
    searchQuery.addListener(_onQueryChanged);
    if (_query.trim().isNotEmpty) _queueSearch(_query, immediate: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchQuery.removeListener(_onQueryChanged);
    super.dispose();
  }

  void _onQueryChanged() {
    if (!mounted || searchQuery.value == _query) return;
    setState(() => _query = searchQuery.value);
    _queueSearch(_query);
  }

  void _queueSearch(String query, {bool immediate = false}) {
    _debounce?.cancel();
    final normalized = query.trim();

    if (normalized.isEmpty) {
      setState(() {
        _results = null;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);

    if (immediate) {
      _runSearch(normalized);
    } else {
      _debounce = Timer(_debounceDelay, () => _runSearch(normalized));
    }
  }

  Future<void> _runSearch(String normalized) async {
    final generation = ++_generation;
    final provider = context.read<SubsonicProvider>();
    final result = await provider.subsonic.search3(
      normalized,
      artistCount: 20,
      albumCount: 20,
      songCount: 50,
    );

    if (!mounted) return;
    if (generation != _generation || normalized != _query.trim()) return;

    setState(() {
      _results = result;
      _loading = false;
    });
  }

  /// Scores how well [name] matches the current query. 0 means no match.
  double _matchScore(String name, double typeWeight) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return 0;
    final n = name.toLowerCase();
    double base;
    if (n == q) {
      base = 100;
    } else if (n.startsWith(q)) {
      base = 60;
    } else if (n.contains(q)) {
      base = 30;
    } else {
      return 0;
    }
    return base + typeWeight;
  }

  List<_TopResult> _topResults(SearchResult result) {
    final candidates = <_TopResult>[
      // artists weighted highest, then albums, then songs
      for (final a in result.artists)
        _TopResult(score: _matchScore(a.name, 6), artist: a),
      for (final a in result.albums)
        _TopResult(score: _matchScore(a.name, 3), album: a),
      for (final s in result.songs)
        _TopResult(score: _matchScore(s.title, 0), song: s),
    ]..removeWhere((r) => r.score <= 0);

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.take(6).toList();
  }

  void _addRecent(RecentSearch search) {
    final provider = context.read<SubsonicProvider>();
    if (provider.activeAccount == null) return;
    offlineCacheService.addRecentSearch(provider.activeAccount!.id, search);
  }

  void _openAlbum(SearchAlbum album) {
    _addRecent(
      RecentSearch(
        id: album.id,
        type: RecentSearchEnum.album,
        title: album.name,
        subtitle: album.artist,
        artId: album.coverArt,
      ),
    );
    GoRouter.of(context).push('/library/album/${album.id}');
  }

  Future<void> _playSong(SearchSong song) async {
    final subsonic = context.read<SubsonicProvider>().subsonic;
    final full = await subsonic.getSong(song.id);
    if (full == null || !mounted) return;
    _addRecent(
      RecentSearch(
        id: song.id,
        type: RecentSearchEnum.song,
        title: song.title,
        subtitle: '${song.artist} • ${song.album}',
        artId: song.coverArt,
      ),
    );
    context.read<PlayerProvider>().playNow(full);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubsonicProvider>();
    if (provider.activeAccount == null) return const NoAccountView();

    final subsonic = provider.subsonic;
    final result = _results;
    final hasResults =
        result != null &&
        (result.albums.isNotEmpty ||
            result.artists.isNotEmpty ||
            result.songs.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading) ...[
            const SizedBox(height: 4),
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
          ],

          if (_query.trim().isEmpty)
            _emptyState(context, 'Search for artists, albums and songs.')
          else if (!hasResults && !_loading && result != null)
            _emptyState(context, 'No results found for "${_query.trim()}".')
          else if (hasResults) ...[
            _TopResultsSection(
              results: _topResults(result),
              subsonic: subsonic,
              onAlbum: _openAlbum,
              onSong: _playSong,
            ),
            if (result.artists.isNotEmpty)
              _ArtistsSection(artists: result.artists, subsonic: subsonic),
            if (result.albums.isNotEmpty)
              _AlbumsSection(albums: result.albums, subsonic: subsonic),
            if (result.songs.isNotEmpty)
              _SongsSection(
                songs: result.songs,
                subsonic: subsonic,
                onPlay: _playSong,
              ),
          ],
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Text(
          message,
          style: context.theme.typography.md.copyWith(
            color: context.theme.colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Text(
        title,
        style: context.theme.typography.xl.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}

class _TopResultsSection extends StatelessWidget {
  final List<_TopResult> results;
  final Subsonic subsonic;
  final void Function(SearchAlbum album) onAlbum;
  final Future<void> Function(SearchSong song) onSong;

  const _TopResultsSection({
    required this.results,
    required this.subsonic,
    required this.onAlbum,
    required this.onSong,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Top Results'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: results.map((r) => _card(context, r)).toList(),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, _TopResult r) {
    final isArtist = r.artist != null;
    final String artId;
    final String title;
    final String subtitle;
    VoidCallback? onTap;

    if (r.album != null) {
      artId = r.album!.coverArt;
      title = r.album!.name;
      subtitle = 'Album • ${r.album!.artist}';
      onTap = () => onAlbum(r.album!);
    } else if (r.artist != null) {
      artId = r.artist!.coverArt;
      title = r.artist!.name;
      subtitle = 'Artist';
      onTap = null;
    } else {
      artId = r.song!.coverArt;
      title = r.song!.title;
      subtitle = 'Song • ${r.song!.artist}';
      onTap = () => onSong(r.song!);
    }

    return SizedBox(
      width: 280,
      child: TapArea(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.theme.colors.secondary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(isArtist ? 30 : 10),
                child: Image(
                  image: coverArtProvider(
                    subsonic.cachedCoverArtUrl(artId, size: 200),
                  ),
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 60,
                    height: 60,
                    color: context.theme.colors.muted,
                    child: Icon(
                      isArtist ? Icons.person : Icons.music_note,
                      color: context.theme.colors.mutedForeground,
                    ),
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
                      style: context.theme.typography.md.copyWith(
                        fontWeight: FontWeight.w700,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtistsSection extends StatelessWidget {
  final List<SearchArtist> artists;
  final Subsonic subsonic;

  const _ArtistsSection({required this.artists, required this.subsonic});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Artists'),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: artists.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, i) {
              final artist = artists[i];
              return SizedBox(
                width: 100,
                child: Column(
                  children: [
                    ClipOval(
                      child: Image(
                        image: coverArtProvider(
                          subsonic.cachedCoverArtUrl(artist.coverArt, size: 200),
                        ),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 100,
                          height: 100,
                          color: context.theme.colors.muted,
                          child: Icon(
                            Icons.person,
                            color: context.theme.colors.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      artist.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.typography.sm,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AlbumsSection extends StatelessWidget {
  final List<SearchAlbum> albums;
  final Subsonic subsonic;

  const _AlbumsSection({required this.albums, required this.subsonic});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Albums'),
        Wrap(
          spacing: 20,
          runSpacing: 24,
          children: albums
              .map(
                (a) => AlbumCard(
                  album: Album(
                    id: a.id,
                    name: a.name,
                    artist: a.artist,
                    artistId: a.artistId,
                    coverArt: a.coverArt,
                    songCount: a.songCount,
                    duration: a.duration,
                  ),
                  subsonic: subsonic,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _SongsSection extends StatelessWidget {
  final List<SearchSong> songs;
  final Subsonic subsonic;
  final Future<void> Function(SearchSong song) onPlay;

  const _SongsSection({
    required this.songs,
    required this.subsonic,
    required this.onPlay,
  });

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '--:--';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Songs'),
        ...songs.map(
          (song) => TapArea(
            onTap: () => onPlay(song),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image(
                      image: coverArtProvider(
                        subsonic.cachedCoverArtUrl(song.coverArt, size: 100),
                      ),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 48,
                        height: 48,
                        color: context.theme.colors.secondary,
                        child: Icon(
                          Icons.music_note,
                          size: 18,
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.theme.typography.sm.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.album.isNotEmpty
                              ? '${song.artist} • ${song.album}'
                              : song.artist,
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
                    _formatDuration(song.duration),
                    style: context.theme.typography.xs.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
