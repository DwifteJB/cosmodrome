import 'dart:io';

import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/download_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/utils/cover_art_provider.dart';
import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

void showDownloadsSheet(BuildContext context) {
  if (isMobile(context)) {
    showFSheet(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: 0.92,
      useSafeArea: true,
      builder: (_) => const _DownloadsContent(),
    );
  } else {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: const SizedBox(
            width: 520,
            height: 600,
            child: _DownloadsContent(),
          ),
        ),
      ),
    );
  }
}

class _ActiveDownloadTile extends StatelessWidget {
  final SongDownload download;
  const _ActiveDownloadTile(this.download);

  @override
  Widget build(BuildContext context) {
    final song = download.songMeta;
    final pct = ((download.progress) * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _SongArt(song),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song?.title ?? download.songId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (song?.artist != null)
                    Text(
                      song!.artist!,
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: download.progress,
                            backgroundColor: const Color(0xFF2A2A2A),
                            color: Colors.white,
                            minHeight: 3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$pct%',
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () =>
                  context.read<DownloadProvider>().cancelDownload(download.songId),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedDownloadTile extends StatelessWidget {
  final SongDownload download;
  const _CompletedDownloadTile(this.download);

  @override
  Widget build(BuildContext context) {
    final song = download.songMeta;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _SongArt(song),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song?.title ?? download.songId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (song?.artist != null)
                    Text(
                      song!.artist!,
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  FutureBuilder<int>(
                    future: _fileSize(download.localPath),
                    builder: (_, snap) {
                      if (!snap.hasData || snap.data == 0) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        _formatBytes(snap.data!),
                        style: const TextStyle(
                          color: Color(0xFF555555),
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
               
                GestureDetector(
                  onTap: () => context
                      .read<DownloadProvider>()
                      .deleteDownload(download.songId),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 14,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<int> _fileSize(String? path) async {
    if (path == null) return 0;
    try {
      return await File(path).length();
    } catch (_) {
      return 0;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _DownloadsContent extends StatelessWidget {
  const _DownloadsContent();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF111111),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(),
          Expanded(
            child: Consumer<DownloadProvider>(
              builder: (ctx, dl, _) {
                final active = dl.activeDownloads;
                final done = dl.completedDownloads;

                if (active.isEmpty && done.isEmpty) {
                  return _EmptyState();
                }

                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (active.isNotEmpty) ...[
                      _SectionLabel('Downloading'),
                      ...active.map((d) => _ActiveDownloadTile(d)),
                    ],
                    if (done.isNotEmpty) ...[
                      _SectionLabel('Downloaded'),
                      ...done.map((d) => _CompletedDownloadTile(d)),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.download_rounded,
                size: 36,
                color: Color(0xFF444444),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No downloads yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Long-press any song to download it for offline playback.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF666666), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (ctx, dl, _) {
        final count = dl.completedDownloads.length;
        final active = dl.activeDownloads.length;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF2A2A2A), width: 1),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.download_rounded, size: 22, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Downloads',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      active > 0
                          ? '$count downloaded · $active in progress'
                          : '$count song${count == 1 ? '' : 's'} downloaded',
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF666666),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SongArt extends StatelessWidget {
  final Song? song;
  const _SongArt(this.song);

  @override
  Widget build(BuildContext context) {
    final sp = context.read<SubsonicProvider>();
    final coverArt = song?.coverArt;
    String? url;
    if (coverArt != null) {
      try {
        url = sp.subsonic.cachedCoverArtUrl(coverArt, size: 80);
      } catch (_) {}
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: url != null
          ? Image(
              image: coverArtProvider(url),
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() => Container(
    width: 44,
    height: 44,
    color: const Color(0xFF2A2A2A),
    child: const Icon(Icons.music_note, size: 20, color: Color(0xFF555555)),
  );
}
