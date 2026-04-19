import 'dart:async';

import 'package:cosmodrome/components/music-pages/music_page_cover_header.dart';
import 'package:cosmodrome/components/music-pages/track_tile.dart';
import 'package:cosmodrome/components/scrolling_text.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/download_provider.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/utils/accent_notifier.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/cover_art_provider.dart';
import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:cosmodrome/utils/layout_notifier.dart';
import 'package:cosmodrome/utils/layout_page_mixin.dart';
import 'package:cosmodrome/utils/sidebar_notifier.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

class PlaylistPage extends StatefulWidget {
  final String playlistId;

  const PlaylistPage({super.key, required this.playlistId});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _AddSongsSheet extends StatefulWidget {
  final String playlistId;
  final VoidCallback onSongAdded;

  const _AddSongsSheet({required this.playlistId, required this.onSongAdded});

  @override
  State<_AddSongsSheet> createState() => _AddSongsSheetState();
}

class _AddSongsSheetState extends State<_AddSongsSheet> {
  final _controller = TextEditingController();
  List<Song> _results = [];
  final Map<String, String> _coverUrlCache = {};
  bool _searching = false;
  Timer? _debounce;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Material(
      color: const Color(0xFF111111),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: TextStyle(color: colors.foreground),
                decoration: InputDecoration(
                  hintText: 'Search songs…',
                  hintStyle: TextStyle(color: colors.mutedForeground),
                  prefixIcon: Icon(Icons.search, color: colors.mutedForeground),
                  filled: true,
                  fillColor: colors.muted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _onQueryChanged,
              ),
            ),
            const SizedBox(height: 8),
            if (_searching)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) {
                    final song = _results[i];
                    final coverUrl = _coverUrlCache[song.id];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: coverUrl != null
                            ? Image(
                                image: coverArtProvider(coverUrl),
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, e, s) => Container(
                                  width: 44,
                                  height: 44,
                                  color: colors.muted,
                                  child: Icon(
                                    Icons.music_note,
                                    color: colors.mutedForeground,
                                    size: 20,
                                  ),
                                ),
                              )
                            : Container(
                                width: 44,
                                height: 44,
                                color: colors.muted,
                                child: Icon(
                                  Icons.music_note,
                                  color: colors.mutedForeground,
                                  size: 20,
                                ),
                              ),
                      ),
                      title: Text(
                        song.title,
                        style: TextStyle(color: colors.foreground),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: song.artist != null
                          ? Text(
                              song.artist!,
                              style: TextStyle(color: colors.mutedForeground),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: Icon(Icons.add, color: colors.mutedForeground),
                      onTap: () => _addSong(song),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addSong(Song song) async {
    final provider = context.read<SubsonicProvider>();
    try {
      await provider.subsonic.updatePlaylist(
        playlistId: widget.playlistId,
        songIdToAdd: song.id,
      );
      widget.onSongAdded();
      if (mounted) Navigator.pop(context);
    } catch (_) {}
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() => _searching = true);
    try {
      final provider = context.read<SubsonicProvider>();
      final results = await provider.subsonic.searchThreeSongs(
        q: query,
        count: 50,
      );
      if (mounted) {
        final cache = <String, String>{};
        for (final song in results) {
          if (song.coverArt != null) {
            cache[song.id] = provider.subsonic.cachedCoverArtUrl(
              song.coverArt!,
              size: 100,
            );
          }
        }
        setState(() {
          _results = results;
          _coverUrlCache
            ..clear()
            ..addAll(cache);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }
}

class _PlaylistActionsPopover extends StatelessWidget {
  final VoidCallback onAddSongs;
  final VoidCallback onRename;

  const _PlaylistActionsPopover({
    required this.onAddSongs,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return FPopover(
      popoverAnchor: Alignment.topRight,
      childAnchor: Alignment.bottomRight,
      popoverBuilder: (context, controller) {
        return Padding(
          padding: const EdgeInsets.all(4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
            child: FItemGroup(
              children: [
                FItem(
                  prefix: const Icon(Icons.playlist_add, size: 16),
                  title: const Text('Add songs'),
                  onPress: () {
                    controller.hide();
                    onAddSongs();
                  },
                ),
                FItem(
                  prefix: const Icon(Icons.edit_outlined, size: 16),
                  title: const Text('Rename'),
                  onPress: () {
                    controller.hide();
                    onRename();
                  },
                ),
              ],
            ),
          ),
        );
      },
      builder: (context, controller, _) => IconButton(
        icon: Icon(
          Icons.more_horiz,
          color: context.theme.colors.mutedForeground,
        ),
        onPressed: controller.toggle,
      ),
    );
  }
}

class _PlaylistHeader extends StatelessWidget {
  final PlaylistDetail playlist;
  final List<Song> songs;
  final VoidCallback onAddSongs;
  final VoidCallback onRename;

  const _PlaylistHeader({
    required this.playlist,
    required this.songs,
    required this.onAddSongs,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final metaText =
        '${songs.length} song${songs.length == 1 ? '' : 's'} • ${formatPageDuration(playlist.duration)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ScrollingText(
                  text: playlist.name,
                  maxWidth: 600,
                  style: context.theme.typography.xl4.copyWith(
                    fontWeight: FontWeight.w500,
                    color: context.theme.colors.foreground,
                    letterSpacing: 1,
                    height: 0,
                  ),
                ),
              ),
              _PlaylistActionsPopover(
                onAddSongs: onAddSongs,
                onRename: onRename,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            playlist.owner,
            style: context.theme.typography.xl.copyWith(
              color: Colors.white,
              height: 0,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metaText,
            style: context.theme.typography.md.copyWith(
              color: context.theme.colors.mutedForeground,
              height: 0,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: FButton(
                  onPress: songs.isEmpty
                      ? null
                      : () => context.read<PlayerProvider>().playAlbum(songs),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 20),
                      SizedBox(width: 6),
                      Text('Play'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FButton(
                  variant: FButtonVariant.outline,
                  onPress: songs.isEmpty
                      ? null
                      : () => context.read<PlayerProvider>().playAlbum(
                          songs,
                          shuffle: true,
                        ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shuffle_rounded, size: 20),
                      SizedBox(width: 6),
                      Text('Shuffle'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaylistPageState extends State<PlaylistPage> with LayoutPageMixin {
  PlaylistDetail? _playlist;
  List<Song> _songs = [];
  String? _coverUrl;
  bool _loading = true;
  String? _error;

  Color _localCoverColor = AppColors.auraColor;

  @override
  bool get isScrollable => false;

  @override
  List<TopbarButton> get pageButtons => [
    TopbarButton(onPressed: _showAddSongsSheet, icon: Icons.playlist_add),
    TopbarButton(onPressed: _showEditTitleSheet, icon: Icons.edit_outlined),
  ];

  @override
  String? get pageTitle => _playlist?.name ?? 'Playlist';

  @override
  Widget build(BuildContext context) {
    context.watch<SubsonicProvider>().isOffline;
    context.watch<DownloadProvider>();

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
      );
    }

    if (_error != null || _playlist == null) {
      return Center(
        child: Text(
          _error ?? 'Playlist not found',
          style: context.theme.typography.sm.copyWith(
            color: context.theme.colors.mutedForeground,
          ),
        ),
      );
    }

    return isMobileView(context) ? _buildMobileScrollable() : _desktopLayout();
  }

  @override
  void dispose() {
    accentColorNotifier.value = null;
    coverUrlNotifier.value = null;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchPlaylist();
  }

  Widget _buildMobileScrollable() {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final playlist = _playlist!;
    final coverUrl = _coverUrl;
    final accentColor = accentColorNotifier.value ?? AppColors.auraColor;

    var cardWidth = MediaQuery.of(context).size.width * 0.8;
    if (cardWidth > 400) cardWidth = 400;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: topPadding + 56 + 20)),

        // cover art
        SliverToBoxAdapter(
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: coverUrl != null
                  ? Image(
                      image: coverArtProvider(coverUrl),
                      width: cardWidth,
                      height: cardWidth,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) =>
                          _coverPlaceholder(cardWidth),
                    )
                  : _coverPlaceholder(cardWidth),
            ),
          ),
        ),

        // playlist info
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  playlist.name,
                  textAlign: TextAlign.center,
                  style: context.theme.typography.xl2.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.06,
                    height: 0,
                  ),
                ),
                Text(
                  playlist.owner,
                  textAlign: TextAlign.center,
                  style: context.theme.typography.sm.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.05,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_songs.length} song${_songs.length == 1 ? '' : 's'} • ${formatPageDuration(playlist.duration)}',
                  textAlign: TextAlign.center,
                  style: context.theme.typography.xs.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FButton(
                        onPress: _songs.isEmpty
                            ? null
                            : () => context.read<PlayerProvider>().playAlbum(
                                _songs,
                              ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 20),
                            SizedBox(width: 6),
                            Text('Play'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FButton(
                        variant: FButtonVariant.outline,
                        onPress: _songs.isEmpty
                            ? null
                            : () => context.read<PlayerProvider>().playAlbum(
                                _songs,
                                shuffle: true,
                              ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shuffle_rounded, size: 20),
                            SizedBox(width: 6),
                            Text('Shuffle'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // reorderable song list
        SliverReorderableList(
          itemCount: _songs.length,
          itemBuilder: (ctx, i) => ReorderableDragStartListener(
            key: ValueKey(_songs[i].id),
            index: i,
            enabled: false,
            child: MusicPageMobileTrackTile(
              song: _songs[i],
              trackNumber: i + 1,
              enabled: _isSongPlayable(_songs[i]),
              accentColor: accentColor,
              onTap: () => _playSongAt(i),
              onRemove: () => _removeAt(i),
              showDragHandle: true,
              reorderIndex: i,
            ),
          ),
          onReorder: _onReorder,
        ),

        SliverToBoxAdapter(child: SizedBox(height: bottomPadding + 100)),
      ],
    );
  }

  Widget _compactPlaylistHeader(PlaylistDetail playlist, String? coverUrl) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: coverUrl != null
                    ? Image(
                        image: coverArtProvider(coverUrl),
                        width: 220,
                        height: 220,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _coverPlaceholder(220),
                      )
                    : _coverPlaceholder(220),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Text(
                    playlist.name,
                    textAlign: TextAlign.center,
                    style: context.theme.typography.xl2.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    playlist.owner,
                    textAlign: TextAlign.center,
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_songs.length} song${_songs.length == 1 ? '' : 's'} • ${formatPageDuration(playlist.duration)}',
                    textAlign: TextAlign.center,
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FButton(
                          onPress: _songs.isEmpty
                              ? null
                              : () => context.read<PlayerProvider>().playAlbum(
                                  _songs,
                                ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 20),
                              SizedBox(width: 6),
                              Text('Play'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FButton(
                          variant: FButtonVariant.outline,
                          onPress: _songs.isEmpty
                              ? null
                              : () => context.read<PlayerProvider>().playAlbum(
                                  _songs,
                                  shuffle: true,
                                ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shuffle_rounded, size: 20),
                              SizedBox(width: 6),
                              Text('Shuffle'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          right: 0,
          child: _PlaylistActionsPopover(
            onAddSongs: _showAddSongsSheet,
            onRename: _showEditTitleSheet,
          ),
        ),
      ],
    );
  }

  Widget _coverPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: context.theme.colors.muted,
      child: Icon(
        Icons.queue_music,
        color: context.theme.colors.mutedForeground,
        size: size * 0.4,
      ),
    );
  }

  Widget _desktopLayout() {
    final playlist = _playlist!;
    final coverUrl = _coverUrl;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompact)
                _compactPlaylistHeader(playlist, coverUrl)
              else
                _widePlaylistHeader(playlist, coverUrl),
              const SizedBox(height: 20),
              ..._songs.asMap().entries.map(
                (e) => MusicPageDesktopTrackTile(
                  song: e.value,
                  trackNumber: e.key + 1,
                  enabled: _isSongPlayable(e.value),
                  accentColor: accentColorNotifier.value ?? _localCoverColor,
                  onTap: () => _playSongAt(e.key),
                  onRemove: () => _removeAt(e.key),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _extractAccentColor() async {
    if (_coverUrl == null) return;
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        coverArtProvider(_coverUrl!),
        size: const Size(200, 200),
      );
      final color =
          generator.vibrantColor?.color ?? generator.dominantColor?.color;
  
      if (mounted) accentColorNotifier.value = color;
      setState(() => _localCoverColor = color ?? AppColors.auraColor);
    } catch (_) {}
  }

  Future<void> _fetchPlaylist() async {
    final provider = context.read<SubsonicProvider>();
    if (provider.activeAccount == null) {
      setState(() {
        _error = 'No active account';
        _loading = false;
      });
      return;
    }

    try {
      final playlist = await provider.subsonic.getPlaylist(widget.playlistId);
      if (mounted) {
        final coverUrl = playlist?.coverArt != null
            ? provider.subsonic.cachedCoverArtUrl(
                playlist!.coverArt!,
                size: 600,
              )
            : null;
        if (coverUrl != null) {
          await precacheImage(
            coverArtProvider(coverUrl),
            context,
          ).catchError((_) {});
        }
        if (!mounted) return;
        setState(() {
          _playlist = playlist;
          _songs = List.of(playlist?.songs ?? []);
          _coverUrl = coverUrl;
          _error = playlist == null ? 'Playlist not found' : null;
          _loading = false;
        });
        coverUrlNotifier.value = coverUrl;

        layoutConfig.value = LayoutConfig(
          title: playlist?.name ?? 'Playlist',
          buttons: pageButtons,
          isScrollable: false,
        );
        _extractAccentColor();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  bool _isSongPlayable(Song song) {
    final subsonic = context.read<SubsonicProvider>();
    if (!subsonic.isOffline) return true;
    return context.read<DownloadProvider>().isSongDownloaded(song.id);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final song = _songs.removeAt(oldIndex);
      _songs.insert(newIndex, song);
    });
    _syncReorder();
  }

  void _playSongAt(int index) async {
    if (!_isSongPlayable(_songs[index])) return;
    final pp = context.read<PlayerProvider>();
    await pp.resetQueue();
    await pp.playNow(_songs[index]);
    if (index < _songs.length - 1) {
      pp.addBulkToQueue(_songs.sublist(index + 1));
    }
  }

  Future<void> _refreshPlaylist() async {
    final provider = context.read<SubsonicProvider>();
    try {
      final playlist = await provider.subsonic.getPlaylist(widget.playlistId);
      if (mounted && playlist != null) {
        setState(() {
          _playlist = playlist;
          _songs = List.of(playlist.songs);
        });
        layoutConfig.value = LayoutConfig(
          title: playlist.name,
          buttons: pageButtons,
          isScrollable: false,
        );
      }
    } catch (_) {}
  }

  Future<void> _removeAt(int index) async {
    final removed = _songs[index];
    setState(() => _songs.removeAt(index));
    try {
      final provider = context.read<SubsonicProvider>();
      await provider.subsonic.updatePlaylist(
        playlistId: widget.playlistId,
        songIndexToRemove: index,
      );
    } catch (_) {
      if (mounted) setState(() => _songs.insert(index, removed));
    }
  }

  Future<void> _renamePlaylist(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == _playlist?.name) return;
    try {
      final provider = context.read<SubsonicProvider>();
      await provider.subsonic.updatePlaylist(
        playlistId: widget.playlistId,
        name: trimmed,
      );
      if (mounted) {
        setState(() {
          _playlist = PlaylistDetail(
            id: _playlist!.id,
            name: trimmed,
            comment: _playlist!.comment,
            songCount: _playlist!.songCount,
            duration: _playlist!.duration,
            coverArt: _playlist!.coverArt,
            owner: _playlist!.owner,
            public: _playlist!.public,
            songs: _songs,
          );
        });
        layoutConfig.value = LayoutConfig(
          title: trimmed,
          buttons: pageButtons,
          isScrollable: false,
        );
        notifyPlaylistsChanged();
      }
    } catch (_) {}
  }

  void _showAddSongsSheet() {
    showFSheet(
      context: context,
      side: FLayout.btt,
      builder: (ctx) => _AddSongsSheet(
        playlistId: widget.playlistId,
        onSongAdded: _refreshPlaylist,
      ),
      useRootNavigator: true,
    );
  }

  void _showEditTitleSheet() {
    final currentName = _playlist?.name ?? '';
    String newName = currentName;

    showFSheet(
      context: context,
      side: FLayout.btt,
      useRootNavigator: true,
      builder: (ctx) {
        final colors = ctx.theme.colors;
        return Material(
          color: const Color(0xFF111111),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Rename playlist',
                    style: TextStyle(
                      color: colors.foreground,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    controller: TextEditingController(text: currentName),
                    style: TextStyle(color: colors.foreground),
                    decoration: InputDecoration(
                      hintText: 'Playlist name',
                      hintStyle: TextStyle(color: colors.mutedForeground),
                      filled: true,
                      fillColor: colors.muted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => newName = v,
                    onSubmitted: (_) async {
                      Navigator.pop(ctx);
                      await _renamePlaylist(newName);
                    },
                  ),
                  const SizedBox(height: 12),
                  FButton(
                    onPress: () async {
                      Navigator.pop(ctx);
                      await _renamePlaylist(newName);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _syncReorder() {
    final provider = context.read<SubsonicProvider>();
    final ids = _songs.map((s) => s.id).toList();
    provider.subsonic.replacePlaylistSongs(widget.playlistId, ids);
  }

  Widget _widePlaylistHeader(PlaylistDetail playlist, String? coverUrl) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: coverUrl != null
                ? Image(
                    image: coverArtProvider(coverUrl),
                    width: 280,
                    height: 280,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _coverPlaceholder(280),
                  )
                : _coverPlaceholder(280),
          ),
          Expanded(
            child: _PlaylistHeader(
              playlist: playlist,
              songs: _songs,
              onAddSongs: _showAddSongsSheet,
              onRename: _showEditTitleSheet,
            ),
          ),
        ],
      ),
    );
  }
}
