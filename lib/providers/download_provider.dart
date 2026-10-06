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
  String? _currentAccountId;

  List<SongDownload> get activeDownloads => _downloads.values
      .where((d) => d.status == DownloadStatus.downloading)
      .toList();

  List<SongDownload> get completedDownloads =>
      _downloads.values.where((d) => d.status == DownloadStatus.done).toList();

  Future<void> cancelDownload(String songId) async {
    // only in-progress downloads can be cancelled, finished ones are deleted instead
    if (_downloads[songId]?.status != DownloadStatus.downloading) return;
    _activeClients.remove(songId)?.close();
    _downloads.remove(songId);
    notifyListeners();
  }

  Future<void> deleteDownload(String songId) async {
    final localPath = _downloads[songId]?.localPath;
    if (localPath != null) {
      try {
        await LocalStorageService.deleteSong(localPath);
      } catch (_) {}
    }
    _downloads.remove(songId);
    final accountId = _currentAccountId;
    if (accountId != null) await _saveManifest(accountId);
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

    // each attempt owns its SongDownload. if the map entry is no longer this
    // object, the attempt was cancelled (and maybe re-queued) and must not touch
    // the newer attempt's state
    final download = SongDownload(
      songId: song.id,
      status: DownloadStatus.downloading,
      progress: 0.0,
      songMeta: song,
    );
    _downloads[song.id] = download;
    bool isCancelled() => !identical(_downloads[song.id], download);
    notifyListeners();

    http.Client? client;

    try {
      await LocalStorageService.ensureDirs(accountId);

      final streamUrl = sp.subsonic.streamUrl(song.id);
      final uri = Uri.parse(streamUrl);

      if (isCancelled()) throw _DownloadCancelled();
      client = http.Client();
      _activeClients[song.id] = client;

      final request = http.Request('GET', uri)..maxRedirects = 100;
      final response = await client.send(request);

      final contentLength = response.contentLength ?? 0;
      int received = 0;
      final bytes = BytesBuilder(copy: false);

      await for (final chunk in response.stream) {
        if (isCancelled()) throw _DownloadCancelled();
        bytes.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          download.progress = received / contentLength;
          notifyListeners();
        }
      }

      if (isCancelled()) throw _DownloadCancelled();
      await LocalStorageService.writeSongBytes(path, bytes.takeBytes());
      _releaseClient(song.id, client);

      if (isCancelled()) {
        // cancelled while writing. a re-queued attempt overwrites the same
        // path, so only clean up if nothing replaced us
        if (!_downloads.containsKey(song.id)) {
          try {
            await LocalStorageService.deleteSong(path);
          } catch (_) {}
        }
        return;
      }

      download
        ..status = DownloadStatus.done
        ..localPath = path
        ..progress = 1.0;

      await _saveManifest(accountId);
      notifyListeners();
    } catch (e) {
      if (client != null) _releaseClient(song.id, client);
      // a cancelled attempt's client gets closed mid-stream, so any error
      // after cancelling is expected and not worth reporting
      if (isCancelled()) return;
      download
        ..status = DownloadStatus.error
        ..error = e.toString();
      notifyListeners();
    }
  }

  // closes [client] and forgets it, unless a newer attempt has replaced it
  void _releaseClient(String songId, http.Client client) {
    client.close();
    if (identical(_activeClients[songId], client)) {
      _activeClients.remove(songId);
    }
  }

  SongDownload? getDownload(String songId) => _downloads[songId];

  String? getLocalPath(String songId) {
    final d = _downloads[songId];
    return d?.status == DownloadStatus.done ? d?.localPath : null;
  }

  bool isSongDownloaded(String songId) => getLocalPath(songId) != null;

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
      final data = <String, dynamic>{
        for (final MapEntry(key: songId, value: d) in _downloads.entries)
          if (d.status == DownloadStatus.done && d.localPath != null)
            songId: {'localPath': d.localPath, 'song': ?d.songMeta?.toJson()},
      };
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
