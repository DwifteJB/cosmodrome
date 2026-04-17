import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

class DesktopSongPopover extends StatefulWidget {
  final Song song;
  final VoidCallback? onRemoveFromPlaylist;
  final Widget Function(BuildContext context, FPopoverController controller)
  builder;

  const DesktopSongPopover({
    super.key,
    required this.song,
    required this.builder,
    this.onRemoveFromPlaylist,
  });

  @override
  State<DesktopSongPopover> createState() => _DesktopSongPopoverState();
}

class _DesktopSongPopoverState extends State<DesktopSongPopover> {
  _PopoverMode _mode = _PopoverMode.main;
  List<Playlist> _playlists = [];
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return FPopover(
      popoverAnchor: .bottomRight,
      childAnchor: .topRight,

      popoverBuilder: (context, controller) {
        return Padding(
          padding: const EdgeInsets.all(4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 220,
              maxWidth: 280,
              maxHeight: 320,
            ),
            child: _mode == _PopoverMode.main
                ? _buildMain(controller)
                : _buildPlaylistPicker(controller),
          ),
        );
      },

      builder: (context, controller, _) => widget.builder(context, controller),
    );
  }

  Future<void> _addToPlaylist(
    Playlist playlist,
    FPopoverController controller,
  ) async {
    final provider = context.read<SubsonicProvider>();
    try {
      await provider.subsonic.updatePlaylist(
        playlistId: playlist.id,
        songIdToAdd: widget.song.id,
      );
    } catch (_) {}

    if (mounted) controller.hide();
  }

  Widget _buildMain(FPopoverController controller) {
    return FItemGroup(
      children: [
        FItem(
          prefix: const Icon(Icons.play_arrow_rounded, size: 16),
          title: const Text('Play now'),
          onPress: () {
            context.read<PlayerProvider>().playNow(widget.song);
            controller.hide();
          },
        ),
        FItem(
          prefix: const Icon(Icons.queue_music_rounded, size: 16),
          title: const Text('Add to queue'),
          onPress: () {
            context.read<PlayerProvider>().addToQueue(widget.song);
            controller.hide();
          },
        ),
        FItem(
          prefix: const Icon(Icons.playlist_add, size: 16),
          title: const Text('Add to playlist'),
          suffix: const Icon(FIcons.chevronRight, size: 14),
          onPress: _goToPlaylistPicker,
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
              controller.hide();
              widget.onRemoveFromPlaylist!();
            },
          ),
      ],
    );
  }

  Widget _buildPlaylistPicker(FPopoverController controller) {
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
        // back header
        Row(
          children: [
            IconButton(
              icon: const Icon(FIcons.chevronLeft, size: 18),
              onPressed: () => setState(() => _mode = _PopoverMode.main),
            ),
            const Text('Add to playlist'),
          ],
        ),
        const Divider(height: 1),

        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('New playlist'),
                onTap: () => _createAndAdd(controller),
              ),
              ..._playlists.map((p) {
                return ListTile(
                  title: Text(p.name),
                  subtitle: Text(
                    '${p.songCount} song${p.songCount == 1 ? '' : 's'}',
                  ),
                  onTap: () => _addToPlaylist(p, controller),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _createAndAdd(FPopoverController controller) async {
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
      }
    } catch (_) {}

    if (mounted) controller.hide();
  }

  Future<void> _goToPlaylistPicker() async {
    setState(() {
      _mode = _PopoverMode.playlistPicker;
      _loading = true;
    });

    try {
      final provider = context.read<SubsonicProvider>();
      final playlists = await provider.subsonic.getPlaylists();
      if (mounted) {
        setState(() => _playlists = playlists);
      }
    } catch (_) {
      if (mounted) setState(() => _playlists = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

enum _PopoverMode { main, playlistPicker }
