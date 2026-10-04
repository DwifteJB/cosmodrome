import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/services/local_storage_service.dart';
import 'package:cosmodrome/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';

final playHistoryService = PlayHistoryService();

class PlayHistoryService extends ChangeNotifier {
  static const _songsKey = 'history_songs';
  static const _playlistsKey = 'history_playlists';
  static const _maxEntries = 30;

  final _songs = <String, List<Song>>{};
  final _playlists = <String, List<Playlist>>{};
  final _loading = <String, Future<void>>{};

  Future<void> ensureLoaded(String accountId) =>
      _loading[accountId] ??= _load(accountId);

  List<Song> songs(String accountId) =>
      List.unmodifiable(_songs[accountId] ?? const <Song>[]);

  List<Playlist> playlists(String accountId) =>
      List.unmodifiable(_playlists[accountId] ?? const <Playlist>[]);

  Future<void> recordSong(String accountId, Song song) async {
    await ensureLoaded(accountId);
    final list = _songs[accountId]!;
    if (list.isNotEmpty && list.first.id == song.id) return;
    _pushFront(list, song, (s) => s.id == song.id);
    notifyListeners();
    await _save(accountId, _songsKey, list.map((s) => s.toJson()).toList());
  }

  Future<void> recordPlaylist(String accountId, Playlist playlist) async {
    await ensureLoaded(accountId);
    final list = _playlists[accountId]!;
    final summary = Playlist(
      id: playlist.id,
      name: playlist.name,
      comment: playlist.comment,
      songCount: playlist.songCount,
      duration: playlist.duration,
      coverArt: playlist.coverArt,
      owner: playlist.owner,
      public: playlist.public,
    );
    _pushFront(list, summary, (p) => p.id == playlist.id);
    notifyListeners();
    await _save(accountId, _playlistsKey, list.map((p) => p.toJson()).toList());
  }

  void _pushFront<T>(List<T> list, T item, bool Function(T) same) {
    list
      ..removeWhere(same)
      ..insert(0, item);
    if (list.length > _maxEntries) list.removeRange(_maxEntries, list.length);
  }

  Future<void> _load(String accountId) async {
    _songs[accountId] = (await _read(
      accountId,
      _songsKey,
    )).map(Song.fromJson).toList();
    _playlists[accountId] = (await _read(
      accountId,
      _playlistsKey,
    )).map(Playlist.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> _read(String accountId, String key) async {
    try {
      final envelope = await LocalStorageService.readJsonMeta(accountId, key);
      final data = envelope?['data'] as List<dynamic>?;
      return data?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      loggerPrint('PlayHistory: failed to read $key for $accountId: $e');
      return [];
    }
  }

  Future<void> _save(
    String accountId,
    String key,
    List<Map<String, dynamic>> data,
  ) async {
    try {
      await LocalStorageService.ensureDirs(accountId);
      await LocalStorageService.writeJsonMeta(accountId, key, {'data': data});
    } catch (e) {
      loggerPrint('PlayHistory: failed to write $key for $accountId: $e');
    }
  }
}
