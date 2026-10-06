import 'dart:math';

import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/download_provider.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/utils/navigation.dart';
import 'package:cosmodrome/utils/notifiers/sidebar_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

const _menuConstraints = BoxConstraints(
  minWidth: 220,
  maxWidth: 280,
  maxHeight: 320,
);

VoidCallback? goToAlbumAction(BuildContext context, Song song) {
  if (song.albumId.isEmpty) return null;
  final router = GoRouter.of(context);
  return () => router.push('/library/album/${song.albumId}');
}

VoidCallback? goToArtistAction(BuildContext context, Song song) {
  if (!songHasArtist(song)) return null;
  final router = GoRouter.of(context);
  final subsonic = context.read<SubsonicProvider>().subsonic;
  return () => openArtist(
    router,
    subsonic,
    artistId: song.artistId,
    artistName: song.artist,
  );
}

// context menu anchored at a pointer position (right click / long press)
Future<void> showSongContextMenuAt(
  BuildContext context,
  Song song,
  Offset globalPosition, {
  VoidCallback? onRemoveFromPlaylist,
  bool showGoToAlbum = true,
}) {
  final onGoToAlbum = showGoToAlbum ? goToAlbumAction(context, song) : null;
  return Navigator.of(context, rootNavigator: true).push(
    _SongContextMenuRoute(
      song: song,
      position: globalPosition,
      onRemoveFromPlaylist: onRemoveFromPlaylist,
      onGoToAlbum: onGoToAlbum,
    ),
  );
}

class DesktopSongPopover extends StatelessWidget {
  final Song song;
  final VoidCallback? onRemoveFromPlaylist;
  final VoidCallback? onGoToAlbum;
  final ValueChanged<bool>? onShownChanged;
  final Widget Function(BuildContext context, FPopoverController controller)
  builder;

  const DesktopSongPopover({
    super.key,
    required this.song,
    required this.builder,
    this.onRemoveFromPlaylist,
    this.onGoToAlbum,
    this.onShownChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FPopover(
      control: FPopoverControl.managed(onChange: onShownChanged),
      popoverAnchor: Alignment.bottomRight,
      childAnchor: Alignment.topRight,
      popoverBuilder: (context, controller) => Padding(
        padding: const EdgeInsets.all(4),
        child: ConstrainedBox(
          constraints: _menuConstraints,
          child: SongMenuContent(
            song: song,
            onRemoveFromPlaylist: onRemoveFromPlaylist,
            onGoToAlbum: onGoToAlbum,
            close: controller.hide,
          ),
        ),
      ),
      builder: (context, controller, _) => builder(context, controller),
    );
  }
}

class SongMenuContent extends StatefulWidget {
  final Song song;
  final VoidCallback? onRemoveFromPlaylist;
  final VoidCallback? onGoToAlbum;
  final VoidCallback close;

  const SongMenuContent({
    super.key,
    required this.song,
    required this.close,
    this.onRemoveFromPlaylist,
    this.onGoToAlbum,
  });

  @override
  State<SongMenuContent> createState() => _SongMenuContentState();
}

class _SongMenuContentState extends State<SongMenuContent> {
  _MenuMode _mode = _MenuMode.main;
  List<Playlist> _playlists = [];
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return _mode == _MenuMode.main ? _buildMain() : _buildPlaylistPicker();
  }

  Future<void> _addToPlaylist(Playlist playlist) async {
    final provider = context.read<SubsonicProvider>();
    try {
      await provider.subsonic.updatePlaylist(
        playlistId: playlist.id,
        songIdToAdd: widget.song.id,
      );
    } catch (_) {}
    if (mounted) widget.close();
  }

  Widget _buildMain() {
    final dl = context.watch<DownloadProvider>();
    final sp = context.watch<SubsonicProvider>();
    final d = dl.getDownload(widget.song.id);
    final status = d?.status ?? DownloadStatus.idle;

    final downloadItem = switch (status) {
      DownloadStatus.done => FItem(
        prefix: const Icon(
          Icons.download_done_rounded,
          size: 16,
          color: Colors.greenAccent,
        ),
        title: const Text('Downloaded'),
        suffix: const Icon(
          Icons.delete_outline,
          size: 16,
          color: Colors.redAccent,
        ),
        onPress: () {
          dl.deleteDownload(widget.song.id);
          widget.close();
        },
      ),
      DownloadStatus.downloading => FItem(
        prefix: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(value: d?.progress, strokeWidth: 2),
        ),
        title: Text('${((d?.progress ?? 0) * 100).round()}% downloading…'),
        suffix: const Icon(Icons.close, size: 16),
        onPress: () => dl.cancelDownload(widget.song.id),
      ),
      DownloadStatus.error => FItem(
        prefix: const Icon(
          Icons.error_outline,
          size: 16,
          color: Colors.redAccent,
        ),
        title: const Text(
          'Download failed - click to retry?',
          style: TextStyle(color: Colors.redAccent),
        ),
        onPress: () => dl.retryDownload(widget.song, sp),
      ),
      DownloadStatus.idle => FItem(
        prefix: const Icon(Icons.download_rounded, size: 16),
        title: const Text('Download'),
        onPress: () => dl.downloadSong(widget.song, sp),
      ),
    };

    return FItemGroup(
      children: [
        FItem(
          prefix: const Icon(Icons.play_arrow_rounded, size: 16),
          title: const Text('Play now'),
          onPress: () {
            context.read<PlayerProvider>().playNow(widget.song);
            widget.close();
          },
        ),
        FItem(
          prefix: const Icon(Icons.queue_music_rounded, size: 16),
          title: const Text('Add to queue'),
          onPress: () {
            context.read<PlayerProvider>().addToQueue(widget.song);
            widget.close();
          },
        ),
        FItem(
          prefix: const Icon(Icons.playlist_add, size: 16),
          title: const Text('Add to playlist'),
          suffix: const Icon(FIcons.chevronRight, size: 14),
          onPress: _goToPlaylistPicker,
        ),
        downloadItem,
        if (widget.onGoToAlbum != null)
          FItem(
            prefix: const Icon(Icons.album_outlined, size: 16),
            title: const Text('Go to album'),
            onPress: () {
              widget.close();
              widget.onGoToAlbum!();
            },
          ),
        if (songHasArtist(widget.song))
          FItem(
            prefix: const Icon(Icons.person_outline, size: 16),
            title: const Text('Go to artist'),
            onPress: () {
              final goToArtist = goToArtistAction(context, widget.song);
              widget.close();
              goToArtist?.call();
            },
          ),
        if (widget.onRemoveFromPlaylist != null)
          FItem(
            prefix: const Icon(
              Icons.remove_circle_outline,
              size: 16,
              color: Colors.redAccent,
            ),
            title: const Text(
              'Remove from playlist',
              style: TextStyle(color: Colors.redAccent),
            ),
            onPress: () {
              widget.close();
              widget.onRemoveFromPlaylist!();
            },
          ),
      ],
    );
  }

  Widget _buildPlaylistPicker() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(FIcons.chevronLeft, size: 18),
              onPressed: () => setState(() => _mode = _MenuMode.main),
            ),
            const Text('Add to playlist'),
          ],
        ),
        const Divider(height: 1),
        Flexible(
          child: Material(
            type: MaterialType.transparency,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('New playlist'),
                  onTap: _createAndAdd,
                ),
                ..._playlists.map(
                  (p) => ListTile(
                    title: Text(p.name),
                    subtitle: Text(
                      '${p.songCount} song${p.songCount == 1 ? '' : 's'}',
                    ),
                    onTap: () => _addToPlaylist(p),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createAndAdd() async {
    String name = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(
          autofocus: true,
          onChanged: (v) => name = v,
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (confirmed != true || name.trim().isEmpty || !mounted) return;
    final provider = context.read<SubsonicProvider>();
    try {
      final id = await provider.subsonic.createNewPlaylist(name.trim());
      if (id != null) {
        await provider.subsonic.updatePlaylist(
          playlistId: id,
          songIdToAdd: widget.song.id,
        );
        notifyPlaylistsChanged();
      }
    } catch (_) {}
    if (mounted) widget.close();
  }

  Future<void> _goToPlaylistPicker() async {
    setState(() {
      _mode = _MenuMode.playlistPicker;
      _loading = true;
    });
    try {
      final provider = context.read<SubsonicProvider>();
      final playlists = await provider.subsonic.getPlaylists();
      if (mounted) setState(() => _playlists = playlists);
    } catch (_) {
      if (mounted) setState(() => _playlists = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

enum _MenuMode { main, playlistPicker }

class _SongContextMenuRoute extends PopupRoute<void> {
  final Song song;
  final Offset position;
  final VoidCallback? onRemoveFromPlaylist;
  final VoidCallback? onGoToAlbum;

  _SongContextMenuRoute({
    required this.song,
    required this.position,
    this.onRemoveFromPlaylist,
    this.onGoToAlbum,
  });

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 100);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final style = context.theme.popoverStyle;
    return CustomSingleChildLayout(
      delegate: _ContextMenuLayout(position),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).pop(),
        },
        child: Focus(
          autofocus: true,
          child: ConstrainedBox(
            constraints: _menuConstraints,
            child: DecoratedBox(
              decoration: style.decoration,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Builder(
                  builder: (ctx) => SongMenuContent(
                    song: song,
                    onRemoveFromPlaylist: onRemoveFromPlaylist,
                    onGoToAlbum: onGoToAlbum,
                    close: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        alignment: Alignment.topLeft,
        scale: Tween<double>(begin: 0.93, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}

class _ContextMenuLayout extends SingleChildLayoutDelegate {
  static const _pad = 8.0;

  final Offset position;

  const _ContextMenuLayout(this.position);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var x = position.dx;
    var y = position.dy;
    if (x + childSize.width > size.width - _pad) x -= childSize.width;
    if (y + childSize.height > size.height - _pad) y -= childSize.height;
    x = x.clamp(_pad, max(_pad, size.width - childSize.width - _pad));
    y = y.clamp(_pad, max(_pad, size.height - childSize.height - _pad));
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_ContextMenuLayout oldDelegate) =>
      oldDelegate.position != position;
}
