import 'package:cosmodrome/components/pill_header.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/utils/accent_notifier.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:cosmodrome/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            album.name,
            style: context.theme.typography.xl2.copyWith(
              fontWeight: FontWeight.bold,
              color: context.theme.colors.foreground,
              letterSpacing: -0.06
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
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

  Widget _coverPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: context.theme.colors.muted,
      child: Icon(Icons.album, color: context.theme.colors.mutedForeground, size: size * 0.4),
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
          IconButton(
            icon: Icon(Icons.arrow_back, color: context.theme.colors.foreground),
            onPressed: () => context.pop(),
          ),
          const SizedBox(height: 8),
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
              const SizedBox(width: 24),
              Expanded(child: _AlbumHeader(album: album)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          ...album.songs.map(
            (s) => _TrackTile(song: s, albumArtist: album.artist),
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
      final color = generator.vibrantColor?.color ?? generator.dominantColor?.color;
      loggerPrint("Extracted accent color: $color");
      if (mounted) accentColorNotifier.value = color;
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
        PillHeader(title: '', onBack: () => context.pop()),
        const SizedBox(height: 16),
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
            height: 0
          ),
        ),
        Text(
          album.artist,
          textAlign: TextAlign.center,
          style: context.theme.typography.sm.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
              letterSpacing: -0.05
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
                  onPress: () {},
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
                  onPress: () {},
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
          (s) => _TrackTile(song: s, albumArtist: album.artist),
        ),

        // additional details
        if (additionalDetails.isNotEmpty) ...[
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: additionalDetails
                .map((w) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: w,
                    ))
                .toList(),
          ),
        
        ],

        const SizedBox(height: 32),

      ],
    );
  }
}


class _TrackTile extends StatelessWidget {
  final Song song;
  final String albumArtist;

  const _TrackTile({required this.song, required this.albumArtist});

  @override
  Widget build(BuildContext context) {
    final trackNumber = song.track;
    final showArtist = song.artist != null &&
        song.artist!.isNotEmpty &&
        song.artist != albumArtist;

    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                trackNumber != null ? '$trackNumber' : '—', // em dash should be on all devices via font
                style: context.theme.typography.xs.copyWith(
                  color: AppColors.trackNumber,
                  letterSpacing: -0.5,
                  fontWeight: .bold
                  
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
                      color: context.theme.colors.foreground,
                      fontWeight: .bold,
                      letterSpacing: -0.05
                    ),
                    
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showArtist)
                    Text(
                      song.artist!,
                      style: context.theme.typography.xs.copyWith(
                        color: AppColors.trackNumber,
                        letterSpacing: -0.05
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (song.duration != null)
              Padding(padding: const EdgeInsets.only(left: 24), child: Text(
                _formatDuration(song.duration!),
                style: context.theme.typography.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),)
          ],
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
