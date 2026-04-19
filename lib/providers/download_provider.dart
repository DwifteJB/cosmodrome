// easy to use provider for managing song download & storage state

import 'dart:typed_data';

import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/services/local_storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DownloadProvider extends ChangeNotifier {
  final Map<String, SongDownload> _downloads = {};
  final Map<String, http.Client> _activeClients = {};
  final Set<String> _cancelledDownloads = {};
  String? _currentAccountId;

  List<SongDownload> get activeDownloads => _downloads.values
      .where((d) => d.status == DownloadStatus.downloading)
      .toList();

  List<SongDownload> get completedDownloads => _downloads.values
      .where((d) => d.status == DownloadStatus.done)
      .toList();

  Future<void> cancelDownload(String songId) async {
    _cancelledDownloads.add(songId);
    _activeClients[songId]?.close();
    _activeClients.remove(songId);
    _downloads.remove(songId);
    notifyListeners();
  }

  Future<void> deleteDownload(String songId) async {
    final d = _downloads[songId];
    if (d?.localPath != null) {
      try {
        await LocalStorageService.deleteSong(d!.localPath!);
      } catch (_) {}
    }
    _downloads.remove(songId);
    if (_currentAccountId != null) await _saveManifest(_currentAccountId!);
    notifyListeners();
  }

  Future<void> downloadSong(Song song, SubsonicProvider sp) async {
    final accountId = sp.activeAccount?.id;
    if (accountId == null) return;

    final existing = _downloads[song.id];
    if (existing?.status == DownloadStatus.downloading ||
        existing?.status == DownloadStatus.done) {
      return;
    }

    final suffix = song.suffix ?? 'mp3';
    final path = LocalStorageService.songPath(accountId, song.id, suffix);

    _downloads[song.id] = SongDownload(
      songId: song.id,
      status: DownloadStatus.downloading,
      progress: 0.0,
      songMeta: song,
    );
    notifyListeners();

    try {
      await LocalStorageService.ensureDirs(accountId);

      final streamUrl = sp.subsonic.streamUrl(song.id);
      final uri = Uri.parse(streamUrl);

      final client = http.Client();
      _activeClients[song.id] = client;

      final request = http.Request('GET', uri);
      final response = await client.send(request);

      final contentLength = response.contentLength ?? 0;
      int received = 0;
      final bytes = BytesBuilder(copy: false);

      await for (final chunk in response.stream) {
        if (_cancelledDownloads.contains(song.id)) {
          throw _DownloadCancelled();
        }
        bytes.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          final download = _downloads[song.id];
          if (download != null) {
            download.progress = received / contentLength;
          }
          notifyListeners();
        }
      }

      await LocalStorageService.writeSongBytes(path, bytes.takeBytes());

      client.close();
      _activeClients.remove(song.id);
      _cancelledDownloads.remove(song.id);

      _downloads[song.id]!
        ..status = DownloadStatus.done
        ..localPath = path
        ..progress = 1.0;

      await _saveManifest(accountId);
      notifyListeners();
    } catch (e) {
      if (e is! _DownloadCancelled) {
        final download = _downloads[song.id];
        if (download != null) {
          download
            ..status = DownloadStatus.error
            ..error = e.toString();
        }
      }
      _activeClients[song.id]?.close();
      _activeClients.remove(song.id);
      _cancelledDownloads.remove(song.id);
      notifyListeners();
    }
  }

  SongDownload? getDownload(String songId) => _downloads[songId];

  String? getLocalPath(String songId) {
    final d = _downloads[songId];
    if (d?.status == DownloadStatus.done) return d?.localPath;
    return null;
  }

  bool isSongDownloaded(String songId) =>
      _downloads[songId]?.status == DownloadStatus.done &&
      _downloads[songId]?.localPath != null;

  Future<void> loadForAccount(String accountId) async {
    if (_currentAccountId == accountId) return;
    _currentAccountId = accountId;
    _downloads.clear();
    await _loadManifest(accountId);
    notifyListeners();
  }

  Future<void> retryDownload(Song song, SubsonicProvider sp) async {
    _downloads.remove(song.id);
    await downloadSong(song, sp);
  }

  Future<void> _loadManifest(String accountId) async {
    try {
      final raw = await LocalStorageService.readJsonMeta(
        accountId,
        'downloads_manifest',
      );
      if (raw == null) return;
      for (final entry in raw.entries) {
        final data = entry.value as Map<String, dynamic>;
        final localPath = data['localPath'] as String?;
        if (localPath == null ||
            !await LocalStorageService.songExists(localPath)) {
          continue;
        }
        final songData = data['song'] as Map<String, dynamic>?;
        _downloads[entry.key] = SongDownload(
          songId: entry.key,
          status: DownloadStatus.done,
          progress: 1.0,
          localPath: localPath,
          songMeta: songData != null ? Song.fromJson(songData) : null,
        );
      }
    } catch (_) {}
  }

  Future<void> _saveManifest(String accountId) async {
    try {
      await LocalStorageService.ensureDirs(accountId);
      final data = <String, dynamic>{};
      for (final entry in _downloads.entries) {
        if (entry.value.status == DownloadStatus.done && entry.value.localPath != null) {
          data[entry.key] = {
            'localPath': entry.value.localPath,
            if (entry.value.songMeta != null) 'song': entry.value.songMeta!.toJson(),
          };
        }
      }
      await LocalStorageService.writeJsonMeta(
        accountId,
        'downloads_manifest',
        data,
      );
    } catch (_) {}
  }
}

enum DownloadStatus { idle, downloading, done, error }

class SongDownload {
  final String songId;
  DownloadStatus status;
  double progress;
  String? localPath;
  String? error;
  Song? songMeta;

  SongDownload({
    required this.songId,
    this.status = DownloadStatus.idle,
    this.progress = 0.0,
    this.localPath,
    this.error,
    this.songMeta,
  });
}

class _DownloadCancelled implements Exception {}
