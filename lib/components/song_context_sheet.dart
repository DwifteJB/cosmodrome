import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/download_provider.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/utils/cover_art_provider.dart';
import 'package:cosmodrome/utils/sidebar_notifier.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

void showSongContextSheet(
  BuildContext context,
  Song song, {
  VoidCallback? onRemoveFromPlaylist,
}) {
  showFSheet(
    context: context,
    side: FLayout.btt,
    builder: (ctx) => _SongContextSheet(
      song: song,
      onRemoveFromPlaylist: onRemoveFromPlaylist,
    ),
    useRootNavigator: true,
  );
}

enum _SheetMode { main, playlistPicker }

class _SongContextSheet extends StatefulWidget {
  final Song song;
  final VoidCallback? onRemoveFromPlaylist;

  const _SongContextSheet({required this.song, this.onRemoveFromPlaylist});

  @override
  State<_SongContextSheet> createState() => _SongContextSheetState();
}

class _SongContextSheetState extends State<_SongContextSheet> {
  _SheetMode _mode = _SheetMode.main;
  List<Playlist> _playlists = [];
  bool _loadingPlaylists = false;

  @override
  Widget build(BuildContext context) {
    return _mode == _SheetMode.main
        ? _buildMain(context)
        : _buildPlaylistPicker(context);
  }

  Future<void> _addToPlaylist(Playlist playlist) async {
    final provider = context.read<SubsonicProvider>();
    try {
      await provider.subsonic.updatePlaylist(
        playlistId: playlist.id,
        songIdToAdd: widget.song.id,
      );
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  Widget _artPlaceholder(FColors colors, double size) => Container(
    width: size,
    height: size,
    color: colors.muted,
    child: Icon(
      Icons.music_note,
      color: colors.mutedForeground,
      size: size * 0.5,
    ),
  );

  Widget _buildMain(BuildContext context) {
    final colors = context.theme.colors;
    final song = widget.song;

    return Material(
      color: const Color(0xFF111111),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            _handle(colors),
            const SizedBox(height: 8),
            // song header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  if (song.coverArt != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image(
                        image: coverArtProvider(
                          context
                              .read<SubsonicProvider>()
                              .subsonic
                              .cachedCoverArtUrl(song.coverArt!, size: 100),
                        ),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _artPlaceholder(colors, 48),
                      ),
                    )
                  else
                    _artPlaceholder(colors, 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: TextStyle(
                            color: colors.foreground,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (song.artist != null)
                          Text(
                            song.artist!,
                            style: TextStyle(
                              color: colors.mutedForeground,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            ListTile(
              leading: Icon(Icons.play_arrow_rounded, color: colors.foreground),
              title: Text(
                'Play now',
                style: TextStyle(color: colors.foreground),
              ),
              onTap: () {
                context.read<PlayerProvider>().playNow(widget.song);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.queue_music_rounded,
                color: colors.foreground,
              ),
              title: Text(
                'Add to queue',
                style: TextStyle(color: colors.foreground),
              ),
              onTap: () {
                context.read<PlayerProvider>().addToQueue(widget.song);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.playlist_add, color: colors.foreground),
              title: Text(
                'Add to playlist',
                style: TextStyle(color: colors.foreground),
              ),
              trailing: Icon(
                FIcons.chevronRight,
                size: 16,
                color: colors.mutedForeground,
              ),
              onTap: _goToPlaylistPicker,
            ),
            Consumer2<DownloadProvider, SubsonicProvider>(
              builder: (ctx, dl, sp, _) {
                final d = dl.getDownload(widget.song.id);
                final status = d?.status ?? DownloadStatus.idle;

                if (status == DownloadStatus.done) {
                  return ListTile(
                    leading: const Icon(
                      Icons.download_done_rounded,
                      color: Colors.greenAccent,
                    ),
                    title: Text(
                      'Downloaded',
                      style: TextStyle(color: colors.foreground),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      onPressed: () => dl.deleteDownload(widget.song.id),
                    ),
                  );
                }

                if (status == DownloadStatus.downloading) {
                  final pct = ((d?.progress ?? 0) * 100).round();
                  return ListTile(
                    leading: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: d?.progress,
                        strokeWidth: 2,
                        color: colors.foreground,
                      ),
                    ),
                    title: Text(
                      '$pct% downloading…',
                      style: TextStyle(color: colors.mutedForeground),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.close,
                        color: colors.mutedForeground,
                        size: 18,
                      ),
                      onPressed: () => dl.cancelDownload(widget.song.id),
                    ),
                  );
                }

                if (status == DownloadStatus.error) {
                  return ListTile(
                    leading: const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                    ),
                    title: Text(
                      'Download failed - tap to retry',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    onTap: () => dl.retryDownload(widget.song, sp),
                  );
                }

                return ListTile(
                  leading: Icon(Icons.download_rounded, color: colors.foreground),
                  title: Text(
                    'Download',
                    style: TextStyle(color: colors.foreground),
                  ),
                  onTap: () => dl.downloadSong(widget.song, sp),
                );
              },
            ),
            if (widget.onRemoveFromPlaylist != null)
              ListTile(
                leading: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Remove from playlist',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onRemoveFromPlaylist!();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistPicker(BuildContext context) {
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
            _handle(colors),
            const SizedBox(height: 4),
            // back & title row
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    FIcons.chevronLeft,
                    color: colors.foreground,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _mode = _SheetMode.main),
                ),
                Text(
                  'Add to playlist',
                  style: TextStyle(
                    color: colors.foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            if (_loadingPlaylists)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              )
            else ...[
              // new playlist button
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.muted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.add, color: colors.mutedForeground),
                ),
                title: Text(
                  'New playlist',
                  style: TextStyle(color: colors.foreground),
                ),
                onTap: _createAndAddToPlaylist,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _playlists.length,
                  itemBuilder: (ctx, i) {
                    final p = _playlists[i];
                    final imgUrl = p.coverArt != null
                        ? context
                              .read<SubsonicProvider>()
                              .subsonic
                              .cachedCoverArtUrl(p.coverArt!, size: 80)
                        : null;
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: imgUrl != null
                            ? Image(
                                image: coverArtProvider(imgUrl),
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _artPlaceholder(colors, 40),
                              )
                            : _artPlaceholder(colors, 40),
                      ),
                      title: Text(
                        p.name,
                        style: TextStyle(color: colors.foreground),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${p.songCount} song${p.songCount == 1 ? '' : 's'}',
                        style: TextStyle(color: colors.mutedForeground),
                      ),
                      onTap: () => _addToPlaylist(p),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _createAndAddToPlaylist() async {
    String newName = '';
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
          onChanged: (v) => newName = v,
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
    if (confirmed != true || newName.trim().isEmpty || !mounted) return;
    final provider = context.read<SubsonicProvider>();
    try {
      final id = await provider.subsonic.createNewPlaylist(newName.trim());
      if (id != null && mounted) {
        await provider.subsonic.updatePlaylist(
          playlistId: id,
          songIdToAdd: widget.song.id,
        );
        notifyPlaylistsChanged();
      }
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  Future<void> _goToPlaylistPicker() async {
    setState(() {
      _mode = _SheetMode.playlistPicker;
      _loadingPlaylists = true;
    });
    try {
      final provider = context.read<SubsonicProvider>();
      final playlists = await provider.subsonic.getPlaylists();
      if (mounted) setState(() => _playlists = playlists);
    } catch (_) {
      if (mounted) setState(() => _playlists = []);
    } finally {
      if (mounted) setState(() => _loadingPlaylists = false);
    }
  }

  Widget _handle(FColors colors) => Center(
    child: Container(
      width: 32,
      height: 4,
      decoration: BoxDecoration(
        color: colors.border,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}
