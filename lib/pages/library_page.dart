import 'package:cosmodrome/components/scrolling_text.dart';
import 'package:cosmodrome/components/song_context_sheet.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/layout_notifier.dart';
import 'package:cosmodrome/utils/layout_page_mixin.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

enum CurrentMobileView { albums, artists, playlists, songs }

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryGridItem extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String? subtitle;
  final IconData placeholderIcon;
  final VoidCallback? onTap;

  const _LibraryGridItem({
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.placeholderIcon = Icons.music_note,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) => progress == null
                          ? child
                          : Container(color: ctx.theme.colors.muted),
                      errorBuilder: (ctx, e, s) => _placeholder(ctx),
                    )
                  : _placeholder(context),
            ),
          ),
          const SizedBox(height: 5),
          ScrollingText(
            text: title,
            style: context.theme.typography.xs.copyWith(
              fontWeight: FontWeight.w600,
              color: context.theme.colors.foreground,
            ),
            maxWidth: 200,
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: context.theme.typography.xs.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
    color: context.theme.colors.muted,
    child: Icon(
      placeholderIcon,
      color: context.theme.colors.mutedForeground,
      size: 28,
    ),
  );
}

class _LibraryPageState extends State<LibraryPage> with LayoutPageMixin {
  CurrentMobileView _currentView = CurrentMobileView.albums;

  List<Album> _albums = [];
  List<Artist> _artists = [];
  List<Playlist> _playlists = [];
  List<Song> _songs = [];

  final Set<CurrentMobileView> _loading = {};
  final Set<CurrentMobileView> _fetched = {};

  // Custom top bar with scrollable view switcher tabs.
  @override
  Widget Function(BuildContext)? get topBarBuilder => _buildLibraryTopBar;

  @override
  Widget build(BuildContext context) {
    // if (isMobile(context)) return _buildMobileView();
    // return const SizedBox.shrink();
    return _buildMobileView(); // TODO: desktop
  }

  @override
  void initState() {
    super.initState();
    _fetchView(CurrentMobileView.albums);
  }

  Widget _buildCurrentView() {
    if (_loading.contains(_currentView)) {
      return const SizedBox(
        height: 240,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }

    final subsonic = context.read<SubsonicProvider>().subsonic;

    switch (_currentView) {
      case CurrentMobileView.albums:
        return _buildGrid(
          items: _albums,
          itemBuilder: (ctx, album, _) => _LibraryGridItem(
            imageUrl: album.coverArt != null
                ? subsonic.cachedCoverArtUrl(album.coverArt!, size: 200)
                : null,
            title: album.name,
            subtitle: album.artist,
            placeholderIcon: Icons.album,
            onTap: () => ctx.push('/library/album/${album.id}'),
          ),
        );

      case CurrentMobileView.artists:
        return _buildGrid(
          items: _artists,
          itemBuilder: (ctx, artist, _) => _LibraryGridItem(
            imageUrl: artist.coverArt != null
                ? subsonic.cachedCoverArtUrl(artist.coverArt!, size: 200)
                : null,
            title: artist.name,
            subtitle:
                '${artist.albumCount} album${artist.albumCount == 1 ? '' : 's'}',
            placeholderIcon: Icons.person,
          ),
        );

      case CurrentMobileView.playlists:
        return _buildGrid(
          items: _playlists,
          itemBuilder: (ctx, playlist, _) => _LibraryGridItem(
            imageUrl: playlist.coverArt != null
                ? subsonic.cachedCoverArtUrl(playlist.coverArt!, size: 200)
                : null,
            title: playlist.name,
            subtitle:
                '${playlist.songCount} song${playlist.songCount == 1 ? '' : 's'}',
            placeholderIcon: Icons.queue_music,
            onTap: () => ctx.push('/library/playlist/${playlist.id}'),
          ),
        );

      case CurrentMobileView.songs:
        return _buildList(
          _songs,
          (ctx, song, _) => _SongGridItem(
            imageUrl: song.coverArt != null
                ? subsonic.cachedCoverArtUrl(song.coverArt!, size: 200)
                : null,
            title: song.title,
            subtitle: '${song.artist} • ${song.album}',
            onPlay: () => context.read<PlayerProvider>().playNow(song),
            onLongPress: () => showSongContextSheet(context, song),
          ),
        );
    }
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: 15,
            itemBuilder: (_, i) => Container(
              decoration: BoxDecoration(
                color: AppColors.sidebar,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "It's kinda empty here",
                  style: context.theme.typography.lg.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.theme.colors.foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid<T>({
    required List<T> items,
    required Widget Function(BuildContext ctx, T item, int index) itemBuilder,
  }) {
    if (items.isEmpty) return _buildEmptyState();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.only(top: 12),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: items.length,
        itemBuilder: (ctx, i) => itemBuilder(ctx, items[i], i),
      ),
    );
  }

  Widget _buildLibraryTopBar(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final colors = context.theme.colors;

    return Container(
      height: 56 + topPadding,
      padding: EdgeInsets.only(top: topPadding, left: 20, right: 8),
      color: Colors.transparent,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _currentView.title,
                style: context.theme.typography.xl2.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 0,
                  color: colors.foreground,
                ),
              ),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList<T>(
    List<T> items,
    Widget Function(BuildContext ctx, T item, int index) itemBuilder,
  ) {
    if (items.isEmpty) return _buildEmptyState();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        padding: EdgeInsets.only(top: 12),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) => itemBuilder(ctx, items[i], i),
      ),
    );
  }

  Widget _buildMobileView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 30),
        // view switcher
        Center(
          child: SizedBox(
            height: 30,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...CurrentMobileView.values.map((view) {
                    final isActive = _currentView == view;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: GestureDetector(
                        onTap: () => _switchView(view),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? context.theme.colors.primary
                                : AppColors.mutedButtonColor,
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(
                              color: context.theme.colors.border,
                            ),
                          ),
                          child: Text(
                            view.tabLabel,
                            style: context.theme.typography.xs.copyWith(
                              color: isActive
                                  ? context.theme.colors.primaryForeground
                                  : context.theme.colors.foreground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  // "+" to create a playlist (only shown for playlists tab)
                  if (_currentView == CurrentMobileView.playlists)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: GestureDetector(
                        onTap: _showCreatePlaylistDialog,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.mutedButtonColor,
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(
                              color: context.theme.colors.border,
                            ),
                          ),
                          child: Icon(
                            Icons.add,
                            size: 18,
                            color: context.theme.colors.foreground,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
        _buildCurrentView(),
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _fetchView(CurrentMobileView view) async {
    if (_loading.contains(view) || _fetched.contains(view)) return;

    final provider = context.read<SubsonicProvider>();
    if (provider.activeAccount == null) return;

    setState(() => _loading.add(view));

    try {
      final s = provider.subsonic;
      switch (view) {
        case CurrentMobileView.albums:
          final data = await s.getAlbumList2('alphabeticalByName', size: 500);
          if (mounted) setState(() => _albums = data);
        case CurrentMobileView.artists:
          final data = await s.getArtists();
          if (mounted) setState(() => _artists = data);
        case CurrentMobileView.playlists:
          final data = await s.getPlaylists();
          if (mounted) setState(() => _playlists = data);
        case CurrentMobileView.songs:
          final data = await s.searchThreeSongs(count: 500);
          if (mounted) setState(() => _songs = data);
      }
      if (mounted) setState(() => _fetched.add(view));
    } catch (_) {
      // leave _fetched empty so next visit retries
    } finally {
      if (mounted) setState(() => _loading.remove(view));
    }
  }

  Future<void> _showCreatePlaylistDialog() async {
    String name = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'New playlist',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white30),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
          onChanged: (v) => name = v,
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || name.trim().isEmpty || !mounted) return;

    final provider = context.read<SubsonicProvider>();
    final id = await provider.subsonic.createNewPlaylist(name.trim());

    if (id != null && mounted) {
      // nav immediately to new playliust
      context.push('/library/playlist/$id');
      // invalidate cache, so the new playlist appears in the list when they navigate back
      _fetched.remove(CurrentMobileView.playlists);
    }
  }

  void _switchView(CurrentMobileView view) {
    if (_currentView == view) return;
    setState(() => _currentView = view);
    // Push updated layout config so the main layout rebuilds the top bar
    layoutConfig.value = LayoutConfig(topBarBuilder: topBarBuilder);
    _fetchView(view);
  }
}

class _SongGridItem extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback? onPlay;
  final VoidCallback? onLongPress;

  const _SongGridItem({
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.onPlay,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPlay,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) =>
                              progress == null
                              ? child
                              : Container(color: ctx.theme.colors.muted),
                          errorBuilder: (ctx, e, s) => Container(
                            color: ctx.theme.colors.muted,
                            child: Icon(
                              Icons.music_note,
                              color: ctx.theme.colors.mutedForeground,
                            ),
                          ),
                        )
                      : Container(
                          color: context.theme.colors.muted,
                          child: Icon(
                            Icons.music_note,
                            color: context.theme.colors.mutedForeground,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScrollingText(text: title, maxWidth: 500),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: context.theme.typography.xs.copyWith(
                        color: context.theme.colors.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

extension on CurrentMobileView {
  String get tabLabel => switch (this) {
    CurrentMobileView.albums => 'Albums',
    CurrentMobileView.artists => 'Artists',
    CurrentMobileView.playlists => 'Playlists',
    CurrentMobileView.songs => 'Songs',
  };

  String get title => switch (this) {
    CurrentMobileView.albums => 'your albums',
    CurrentMobileView.artists => 'your artists',
    CurrentMobileView.playlists => 'your playlists',
    CurrentMobileView.songs => 'your songs',
  };
}
