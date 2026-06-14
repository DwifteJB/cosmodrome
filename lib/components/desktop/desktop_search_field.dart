// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/services/offline_cache_service.dart';
import 'package:cosmodrome/utils/cover_art/cover_art_provider.dart';
import 'package:cosmodrome/utils/notifiers/search_notifier.dart';
import 'package:cosmodrome/utils/tap_area.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Desktop sidebar search field with a typeahead popover.
///
/// Typing runs a debounced [Subsonic.search3] and shows results grouped into
/// Albums / Artists / Songs (capped at 4 each) in a popover anchored beneath
/// the field. Pressing Enter opens the full results page (`/search`).
class DesktopSearchField extends StatefulWidget {
  const DesktopSearchField({super.key});

  @override
  State<DesktopSearchField> createState() => _DesktopSearchFieldState();
}

class _DesktopSearchFieldState extends State<DesktopSearchField>
    with SingleTickerProviderStateMixin {
  static const Duration _debounceDelay = Duration(milliseconds: 350);
  static const int _perSection = 4;

  late final FPopoverController _popover;

  SearchResult? _results;
  bool _loading = false;
  String _query = '';
  Timer? _debounce;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _popover = FPopoverController(vsync: this);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _popover.dispose();
    super.dispose();
  }

  void _onChange(String value) {
    searchQuery.value = value;
    _query = value;

    _debounce?.cancel();
    final normalized = value.trim();

    if (normalized.isEmpty) {
      setState(() {
        _results = null;
        _loading = false;
      });
      _popover.hide();
      return;
    }

    setState(() => _loading = true);
    if (_popover.status == AnimationStatus.dismissed ||
        _popover.status == AnimationStatus.reverse) {
      _popover.show();
    }

    _debounce = Timer(_debounceDelay, () async {
      final generation = ++_generation;
      final provider = context.read<SubsonicProvider>();
      final result = await provider.subsonic.search3(
        normalized,
        artistCount: _perSection,
        albumCount: _perSection,
        songCount: _perSection,
      );

      if (!mounted) return;
      if (generation != _generation || normalized != _query.trim()) return;

      setState(() {
        _results = result;
        _loading = false;
      });
    });
  }

  void _onSubmit(String value) {
    if (value.trim().isEmpty) return;
    searchQuery.value = value;
    _popover.hide();
    GoRouter.of(context).go('/search');
  }

  void _addRecent(RecentSearch search) {
    final provider = context.read<SubsonicProvider>();
    if (provider.activeAccount == null) return;
    offlineCacheService.addRecentSearch(provider.activeAccount!.id, search);
  }

  @override
  Widget build(BuildContext context) {
    return FPopover(
      control: FPopoverControl.managed(controller: _popover),
      childAnchor: Alignment.bottomLeft,
      popoverAnchor: Alignment.topLeft,
      // keep the field interactive/focused while the popover is open
      hideRegion: FPopoverHideRegion.excludeChild,
      popoverBuilder: (context, _) => _buildPopover(context),
      child: FTextField(
        hint: 'Search music...',
        control: FTextFieldControl.managed(
          onChange: (value) => _onChange(value.text),
        ),
        onSubmit: _onSubmit,
        prefixBuilder: (ctx, style, variants) => FTextField.prefixIconBuilder(
          ctx,
          style,
          variants,
          const Icon(FIcons.search),
        ),
      ),
    );
  }

  Widget _buildPopover(BuildContext context) {
    final result = _results;
    final hasResults =
        result != null &&
        (result.albums.isNotEmpty ||
            result.artists.isNotEmpty ||
            result.songs.isNotEmpty);

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 320,
        maxWidth: 340,
        maxHeight: 460,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (hasResults) ...[
                if (result.albums.isNotEmpty) ...[
                  const _SectionHeader('Albums'),
                  ...result.albums
                      .take(_perSection)
                      .map((album) => _resultRow(context, album: album)),
                ],
                if (result.artists.isNotEmpty) ...[
                  const _SectionHeader('Artists'),
                  ...result.artists
                      .take(_perSection)
                      .map((artist) => _resultRow(context, artist: artist)),
                ],
                if (result.songs.isNotEmpty) ...[
                  const _SectionHeader('Songs'),
                  ...result.songs
                      .take(_perSection)
                      .map((song) => _resultRow(context, song: song)),
                ],
              ] else if (!_loading && result != null) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No results for "${_query.trim()}".',
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ),
              ],
              if (hasResults) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    'Press Enter to see all results',
                    style: context.theme.typography.xs.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultRow(
    BuildContext context, {
    SearchAlbum? album,
    SearchArtist? artist,
    SearchSong? song,
  }) {
    final subsonic = context.read<SubsonicProvider>().subsonic;

    late final String artId;
    late final String title;
    late final String subtitle;
    VoidCallback? onTap;

    if (album != null) {
      artId = album.coverArt;
      title = album.name;
      subtitle = album.artist;
      onTap = () {
        _addRecent(
          RecentSearch(
            id: album.id,
            type: RecentSearchEnum.album,
            title: album.name,
            subtitle: album.artist,
            artId: album.coverArt,
          ),
        );
        _popover.hide();
        GoRouter.of(context).push('/library/album/${album.id}');
      };
    } else if (artist != null) {
      artId = artist.coverArt;
      title = artist.name;
      subtitle = 'Artist';
      onTap = null; // artist navigation disabled (parity with mobile search)
    } else {
      artId = song!.coverArt;
      title = song.title;
      subtitle = song.album.isNotEmpty
          ? '${song.artist} • ${song.album}'
          : song.artist;
      onTap = () async {
        _popover.hide();
        final full = await subsonic.getSong(song.id);
        if (full != null && mounted) {
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
      };
    }

    final isArtist = artist != null;

    return TapArea(
      onTap: onTap,
      child: Opacity(
        opacity: isArtist ? 0.7 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  isArtist ? 22 : 8,
                ),
                child: Image(
                  image: coverArtProvider(
                    subsonic.cachedCoverArtUrl(artId, size: 100),
                  ),
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 44,
                    height: 44,
                    color: context.theme.colors.secondary,
                    child: Icon(
                      isArtist ? Icons.person : Icons.music_note,
                      size: 18,
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                    const SizedBox(height: 1),
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

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Text(
        title.toUpperCase(),
        style: context.theme.typography.xs.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: context.theme.colors.mutedForeground,
        ),
      ),
    );
  }
}
