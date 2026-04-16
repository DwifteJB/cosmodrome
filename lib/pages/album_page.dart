import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/utils/accent_notifier.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:cosmodrome/utils/is_colour_too_dark.dart';
import 'package:cosmodrome/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

class AlbumPage extends StatefulWidget {
  final String albumId;

  const AlbumPage({super.key, required this.albumId});

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumHeader extends StatelessWidget {
  final AlbumDetail album;

  const _AlbumHeader({required this.album, super.key});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (album.year != null) album.year.toString(),
      '${album.songCount} track${album.songCount == 1 ? '' : 's'}',
      _formatDuration(album.duration),
    ];

    //
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // move to bottom, use spacer
          Text(
            album.name,
            style: context.theme.typography.xl2.copyWith(
              fontWeight: FontWeight.w400,
              color: context.theme.colors.foreground,
              letterSpacing: 1,
              height: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            album.artist,
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            parts.join(' • '),
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

class _AlbumPageState extends State<AlbumPage> {
  AlbumDetail? _album;
  String? _coverUrl;
  bool _loading = true;
  String? _error;

  Color _localCoverColor = AppColors.auraColor;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (_error != null || _album == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: Text(
            _error ?? 'Album not found',
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ),
      );
    }

    return isMobileView(context) ? _mobileLayout() : _desktopLayout();
  }

  @override
  void dispose() {
    accentColorNotifier.value = null;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchAlbum();
  }

  void onClickSong(Song song) async {
    PlayerProvider pp = context.read<PlayerProvider>();
    await pp.resetQueue();
    await pp.playNow(song);
    // add songs after this as album
    final index = _album!.songs.indexOf(song);
    if (index != -1 && index < _album!.songs.length - 1) {
      final nextSongs = _album!.songs.sublist(index + 1);
      pp.addBulkToQueue(nextSongs.toList());
    }
  }

  Widget _coverPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: context.theme.colors.muted,
      child: Icon(
        Icons.album,
        color: context.theme.colors.mutedForeground,
        size: size * 0.4,
      ),
    );
  }

  Widget _desktopLayout() {
    final album = _album!;
    final coverUrl = _coverUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: coverUrl != null
                    ? Image.network(
                        coverUrl,
                        width: 280,
                        height: 280,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          width: 280,
                          height: 280,
                          color: context.theme.colors.muted,
                          child: Icon(
                            Icons.album,
                            color: context.theme.colors.mutedForeground,
                            size: 80,
                          ),
                        ),
                      )
                    : Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          color: context.theme.colors.muted,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.album,
                          color: context.theme.colors.mutedForeground,
                          size: 80,
                        ),
                      ),
              ),
              Expanded(child: _AlbumHeader(album: album)),
            ],
          ),
          const SizedBox(height: 20),
          ...album.songs.map(
            (s) => _DesktopTrackTile(
              song: s,
              albumArtist: album.artist,
              onTap: () => onClickSong(s),
              accentColor: accentColorNotifier.value ?? _localCoverColor,
            ),
          ),
        ],
      ),
    );
  }

  void _extractAccentColor() async {
    if (_coverUrl == null) return;
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(_coverUrl!),
        size: const Size(200, 200),
      );
      final color =
          generator.vibrantColor?.color ?? generator.dominantColor?.color;
      // figure out if its too dark
      final tooDark = isColourTooDark(color ?? AppColors.auraColor);

      if (tooDark) {
        if (mounted) accentColorNotifier.value = AppColors.auraColor;
        setState(() {
          _localCoverColor = AppColors.auraColor;
        });
        return;
      }

      if (mounted) accentColorNotifier.value = color;
      setState(() {
        _localCoverColor = color ?? AppColors.auraColor;
      });
    } catch (_) {}
  }

  Future<void> _fetchAlbum() async {
    final provider = context.read<SubsonicProvider>();
    if (provider.activeAccount == null) {
      setState(() {
        _error = 'No active account';
        _loading = false;
      });
      return;
    }

    try {
      final album = await provider.subsonic.getAlbum(widget.albumId);
      if (mounted) {
        setState(() {
          _album = album;
          _coverUrl = album?.coverArt != null
              ? provider.subsonic.coverArtUrl(album!.coverArt!, size: 600)
              : null;
          _error = album == null ? 'Album not found' : null;
          _loading = false;
        });
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

  Widget _mobileLayout() {
    final album = _album!;
    final coverUrl = _coverUrl;

    final metaParts = <String>[
      if (album.genre != null) album.genre!,
      if (album.year != null) '${album.year}',
      '${album.songCount} track${album.songCount == 1 ? '' : 's'}',
    ];

    final additionalDetails = <Widget>[
      Row(
        children: [
          const Icon(Icons.access_time, size: 16, color: AppColors.trackNumber),
          const SizedBox(width: 4),
          Text(
            _AlbumHeader._formatDuration(album.duration),
            style: context.theme.typography.xs.copyWith(
              color: AppColors.trackNumber,
            ),
          ),
        ],
      ),
    ];

    // width of the device capped at 400
    var cardWidth = MediaQuery.of(context).size.width * 0.8;
    if (cardWidth > 400) cardWidth = 400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // sized
        SizedBox(height: 40),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: coverUrl != null
                ? Image.network(
                    coverUrl,
                    width: cardWidth,
                    height: cardWidth,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => _coverPlaceholder(200),
                  )
                : _coverPlaceholder(200),
          ),
        ),
        const SizedBox(height: 20),
        // album details
        Text(
          album.name,
          textAlign: TextAlign.center,
          style: context.theme.typography.xl2.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.06,
            height: 0,
          ),
        ),
        Text(
          album.artist,
          textAlign: TextAlign.center,
          style: context.theme.typography.sm.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.05,
          ),
        ),
        if (metaParts.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            metaParts.join(' • '),
            textAlign: TextAlign.center,
            style: context.theme.typography.xs.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ],
        const SizedBox(height: 24),
        // buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: FButton(
                  onPress: () =>
                      context.read<PlayerProvider>().playAlbum(album.songs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
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
                  onPress: () => context.read<PlayerProvider>().playAlbum(
                    album.songs,
                    shuffle: true,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.shuffle_rounded, size: 20),
                      SizedBox(width: 6),
                      Text('Shuffle'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ...album.songs.map(
          (s) => _MobileTrackTile(
            song: s,
            albumArtist: album.artist,
            onTap: () => onClickSong(s),
            accentColor: accentColorNotifier.value ?? AppColors.auraColor,
          ),
        ),

        // additional details
        if (additionalDetails.isNotEmpty) ...[
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: additionalDetails
                .map(
                  (w) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: w,
                  ),
                )
                .toList(),
          ),
        ],

        const SizedBox(height: 32),
      ],
    );
  }
}

class _DesktopTrackTile extends StatefulWidget {
  final Song song;
  final String albumArtist;
  final Color? accentColor;
  final VoidCallback? onTap;

  const _DesktopTrackTile({
    required this.song,
    required this.albumArtist,
    this.onTap,
    this.accentColor,
    super.key,
  });

  @override
  State<_DesktopTrackTile> createState() => _DesktopTrackTileState();
}

class _DesktopTrackTileState extends State<_DesktopTrackTile> {
  bool _isHovered = false;
  bool _showPopover = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  bool get isPlaying {
    final player = context.watch<PlayerProvider>();
    return player.currentSong?.id == widget.song.id;
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final trackNumber = song.track;
    final showArtist =
        song.artist != null &&
        song.artist!.isNotEmpty &&
        song.artist != widget.albumArtist;
    final hoverBg = context.theme.colors.secondary.withValues(alpha: 0.2);

    return GestureDetector(
      onTap: widget.onTap ?? () => context.read<PlayerProvider>().playNow(song),
      onSecondaryTap: () => _showContextMenu(context),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          color: _isHovered ? hoverBg : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                // number
                SizedBox(
                  width: 32,
                  child: Text(
                    trackNumber != null ? '$trackNumber' : '—',
                    style: context.theme.typography.xs.copyWith(
                      color: AppColors.trackNumber,
                      letterSpacing: -0.5,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                // title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: context.theme.typography.sm.copyWith(
                          color: isPlaying
                              ? widget.accentColor
                              : context.theme.colors.foreground,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // artist
                      if (showArtist)
                        Text(
                          song.artist!,
                          style: context.theme.typography.xs.copyWith(
                            color: AppColors.trackNumber,
                            letterSpacing: -0.05,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // duration
                if (song.duration != null)
                  Text(
                    _formatDuration(song.duration!),
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                const SizedBox(width: 8),
                // ... elpisis button
                CompositedTransformTarget(
                  link: _layerLink,
                  child: AnimatedOpacity(
                    opacity: _isHovered || _showPopover ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: IconButton(
                      icon: Icon(
                        Icons.more_horiz,
                        size: 16,
                        color: context.theme.colors.mutedForeground,
                      ),
                      onPressed: () => _showContextMenu(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _showPopover = false);
  }

  // TODO: fix
  void _showContextMenu(BuildContext context) {
    _removeOverlay();
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _removeOverlay,
            ),
          ),
          Positioned(
            left: offset.dx + size.width - 160,
            top: offset.dy + size.height / 2,
            child: Material(
              color: AppColors.sidebarSelected,
              borderRadius: BorderRadius.circular(8),
              elevation: 8,
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PopoverItem(
                      label: 'Play now',
                      icon: Icons.play_arrow_rounded,
                      onTap: () {
                        _removeOverlay();
                        context.read<PlayerProvider>().playNow(widget.song);
                      },
                    ),
                    _PopoverItem(
                      label: 'Add to queue',
                      icon: Icons.queue_music_rounded,
                      onTap: () {
                        _removeOverlay();
                        context.read<PlayerProvider>().addToQueue(widget.song);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_overlayEntry!);
    setState(() => _showPopover = true);
  }

  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _MobileTrackTile extends StatefulWidget {
  final Song song;
  final String albumArtist;
  final Color accentColor;
  final VoidCallback? onTap;

  const _MobileTrackTile({
    required this.song,
    required this.albumArtist,
    required this.accentColor,
    this.onTap,
    super.key,
  });

  @override
  State<_MobileTrackTile> createState() => _MobileTrackTileState();
}

class _MobileTrackTileState extends State<_MobileTrackTile> {
  bool get isPlaying {
    final player = context.watch<PlayerProvider>();
    return player.currentSong?.id == widget.song.id;
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final albumArtist = widget.albumArtist;
    final onTap = widget.onTap;
    final trackNumber = song.track;

    return InkWell(
      onTap: onTap ?? () => context.read<PlayerProvider>().playNow(song),
      onLongPress: () => showFSheet(
        context: context,
        side: FLayout.btt,
        builder: (ctx) =>
            _TrackContextMenu(song: song, albumArtist: albumArtist),
        useRootNavigator: true,
      ),
      child: Container(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  trackNumber != null
                      ? '$trackNumber'
                      : '—', // em dash should be on all devices via font
                  style: context.theme.typography.xs.copyWith(
                    color: AppColors.trackNumber,
                    letterSpacing: -0.5,
                    fontWeight: .bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: context.theme.typography.sm.copyWith(
                        color: isPlaying
                            ? widget.accentColor
                            : context.theme.colors.foreground,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.05,
                      ),

                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    Text(
                      song.artist ?? albumArtist,
                      style: context.theme.typography.xs.copyWith(
                        color: AppColors.trackNumber,
                        letterSpacing: -0.05,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (song.duration != null)
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Text(
                    _formatDuration(song.duration!),
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _PopoverItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PopoverItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_PopoverItem> createState() => _PopoverItemState();
}

class _PopoverItemState extends State<_PopoverItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: _isHovered ? Colors.white10 : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: Colors.white70),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackContextMenu extends StatelessWidget {
  final Song song;
  final String albumArtist;

  const _TrackContextMenu({required this.song, required this.albumArtist});

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
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.play_arrow_rounded, color: colors.foreground),
              title: Text(
                'Play now',
                style: TextStyle(color: colors.foreground),
              ),
              onTap: () {
                context.read<PlayerProvider>().playAlbum([song]);
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
                context.read<PlayerProvider>().addToQueue(song);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
