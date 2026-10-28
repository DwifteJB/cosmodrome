import 'dart:io';

import 'package:cosmodrome/providers/download_provider.dart';
import 'package:cosmodrome/services/local_music/local_music_service.dart';
import 'package:cosmodrome/utils/open_folder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

// used in downloads page
Future<void> viewDownloadedFiles(BuildContext context) async {
  final downloads = context.read<DownloadProvider>();
  if (kIsWeb) {
    if (downloads.completedDownloads.isEmpty) {
      _toast(context, 'No downloaded songs yet');
      return;
    }
    await downloads.saveAllToDevice();
    return;
  }

  final path = downloads.downloadsDirectory;
  if (path == null) return;
  final opened = await openFolder(path);
  if (!opened && context.mounted) _toast(context, path);
}

void _toast(BuildContext context, String message) =>
    showFToast(context: context, title: Text(message));

String localFilesHint(String? directory) {
  if (kIsWeb) {
    return 'Click "Import Music" to select files from your device to add to Cosmodrome.';
  }
  if (Platform.isIOS) {
    return 'Drop music into Files -> On My iPhone -> Cosmodrome!';
  }
  return 'Music can be placed in $directory for Cosmodrome to find it.';
}

Future<void> importLocalMusic(BuildContext context) async {
  final imported = await localMusicService.importFiles();
  if (!context.mounted || imported == 0) return;
  _toast(context, 'Imported $imported song${imported == 1 ? '' : 's'}');
}

Future<void> openLocalMusicFolder(BuildContext context) async {
  final path = localMusicService.musicDirectory;
  if (path == null) return;
  final opened = await openFolder(path);
  if (!opened && context.mounted) _toast(context, path);
}

class LocalFilesSettingsPage extends StatelessWidget {
  const LocalFilesSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final local = context.watch<LocalMusicService>();
    final count = local.count;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Row(
            children: [
              Text(
                'Local Files',
                style: context.theme.typography.xl.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    FIcons.x,
                    size: 20,
                    color: colors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  localFilesHint(local.musicDirectory),
                  style: context.theme.typography.sm.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: colors.muted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        FIcons.folder,
                        size: 18,
                        color: colors.mutedForeground,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        localFilesAlbumName,
                        style: context.theme.typography.sm.copyWith(
                          color: colors.foreground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (local.isScanning)
                        SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.mutedForeground,
                          ),
                        )
                      else
                        Text(
                          '$count song${count == 1 ? '' : 's'}',
                          style: context.theme.typography.sm.copyWith(
                            color: colors.mutedForeground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FButton(
                  onPress: () => importLocalMusic(context),
                  child: const Text('Import Music'),
                ),
                if (local.canOpenFolder && canOpenFolders) ...[
                  const SizedBox(height: 8),
                  FButton(
                    variant: FButtonVariant.outline,
                    onPress: () => openLocalMusicFolder(context),
                    child: const Text('Open Music Folder'),
                  ),
                ],
                const SizedBox(height: 8),
                FButton(
                  variant: FButtonVariant.outline,
                  onPress: local.isScanning ? null : local.scan,
                  child: const Text('Rescan'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
