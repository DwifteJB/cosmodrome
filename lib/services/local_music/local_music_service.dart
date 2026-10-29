import 'dart:async';
import 'dart:convert';

import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/services/local_music/local_tags.dart';
import 'package:cosmodrome/services/local_music/tag_reader.dart';
import 'package:cosmodrome/services/local_music/tag_writer.dart';
import 'package:cosmodrome/services/local_storage_service.dart';
import 'package:cosmodrome/utils/logger/logger.dart';
import 'package:cosmodrome/utils/notifiers/sidebar_notifier.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

const localIdPrefix = 'local-';
const localArtPrefix = 'local-art-';
const localArtScheme = 'local-art';
const localFilesAlbumId = 'local-files';
const localAlbumPrefix = 'local-album-';
const localArtistPrefix = 'local-artist-';
const localPlaylistPrefix = 'local-playlist-';

// todo: l10n?
const localFilesAlbumName = 'Local Files';

const _store = 'local';
const _indexKey = 'library';
const _indexVersion = 2;
const _matchesKey = 'local_album_matches';
const _playlistsKey = 'local_playlist_entries';
const _editsKey = 'tag_edits';
const _noArt = 'none';
const _editableSuffixes = {'mp3', 'm4a', 'mp4', 'flac', 'ape'};

bool isLocalSongId(String id) =>
    id.startsWith(localIdPrefix) &&
    !id.startsWith(localArtPrefix) &&
    !id.startsWith(localAlbumPrefix) &&
    !id.startsWith(localArtistPrefix) &&
    !id.startsWith(localPlaylistPrefix) &&
    id != localFilesAlbumId;

String _hash(String value) => md5.convert(utf8.encode(value)).toString();

bool isLocalArtId(String id) => id.startsWith(localArtPrefix);

final localMusicService = LocalMusicService();

// app needs to know when this changes
class LocalMusicService extends ChangeNotifier {
  final Map<String, LocalTrack> _tracks = {};
  final Map<String, Map<String, dynamic>> _edits = {};
  Map<String, Song>? _resolved;

  SubsonicProvider? _provider;
  String? _accountId;
  Map<String, _AlbumMatch> _matches = {};
  Map<String, List<_PlaylistEntry>> _playlists = {};
  final Set<String> _attempted = {};
  bool _matching = false;

  bool _localMode = false;

  Future<void>? _loading;
  Future<void>? _scanning;
  Future<void>? _accountLoading;

  bool get isScanning => _scanning != null;
  int get count => _tracks.length;

  bool get canOpenFolder => !kIsWeb && musicDirectory != null;
  String? get musicDirectory => LocalStorageService.localMusicDirectory;

  List<Song> get songs => _sorted(_resolvedSongs.values);

  LocalTrack? track(String id) => _tracks[id];

  Map<String, Song> get _resolvedSongs => _resolved ??= {
    for (final track in _tracks.values) track.song.id: _resolve(track),
  };

  void bind(SubsonicProvider provider) {
    _provider = provider;
    provider.addListener(_onProviderChanged);
    _onProviderChanged();
  }

  Future<void> init() => _loading ??= _loadIndex();

  Song? song(String id) => _resolvedSongs[id];

  // easily get all local songs 4 an album
  List<Song> songsForAlbum(String albumId) => _sorted(
    _resolvedSongs.values.where((s) => s.albumId == albumId),
    keepTracks: true,
  );

  // search local songs
  List<Song> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return songs;
    return songs
        .where(
          (s) =>
              s.title.toLowerCase().contains(q) ||
              (s.artist?.toLowerCase().contains(q) ?? false) ||
              (s.album?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  // for info page
  Album get localFilesSummary {
    final album = localFilesAlbum();
    return Album(
      id: album.id,
      name: album.name,
      artist: album.artist,
      coverArt: album.coverArt,
      songCount: album.songCount,
      duration: album.duration,
    );
  }

  // all local files -> 1 album
  AlbumDetail localFilesAlbum() {
    final list = songs;
    final numbered = [
      for (final (i, s) in list.indexed)
        Song.fromJson({...s.toJson(), 'track': i + 1}..remove('discNumber')),
    ];
    return AlbumDetail(
      id: localFilesAlbumId,
      name: localFilesAlbumName,
      artist: 'On This Device',
      coverArt: list
          .map((s) => s.coverArt)
          .firstWhere((c) => c != null && isLocalArtId(c), orElse: () => null),
      songCount: list.length,
      duration: list.fold(0, (sum, s) => sum + (s.duration ?? 0)),
      songs: numbered,
    );
  }

  AlbumDetail mergeIntoAlbum(String accountId, AlbumDetail album) {
    if (accountId != _accountId) return album;
    final locals = songsForAlbum(album.id);
    if (locals.isEmpty) return album;

    final taken = {
      for (final s in album.songs)
        if (s.track != null) '${s.discNumber ?? 1}:${s.track}',
    };
    final extra = locals
        .where((s) => s.track == null || !taken.contains(_slotKey(s)))
        .toList();
    if (extra.isEmpty) return album;

    final merged = [...album.songs, ...extra].indexed.toList()
      ..sort((a, b) {
        final disc = (a.$2.discNumber ?? 1).compareTo(b.$2.discNumber ?? 1);
        if (disc != 0) return disc;
        final track = (a.$2.track ?? 1 << 20).compareTo(b.$2.track ?? 1 << 20);
        return track != 0 ? track : a.$1.compareTo(b.$1);
      });
    final songs = merged.map((e) => e.$2).toList();

    return AlbumDetail(
      id: album.id,
      name: album.name,
      artist: album.artist,
      artistId: album.artistId,
      coverArt: album.coverArt,
      songCount: songs.length,
      duration: songs.fold(0, (sum, s) => sum + (s.duration ?? 0)),
      year: album.year,
      genre: album.genre,
      starred: album.starred,
      songs: songs,
      discTitles: album.discTitles,
    );
  }

  String _slotKey(Song s) => '${s.discNumber ?? 1}:${s.track}';

  Future<Uri?> playableUri(Song song) async {
    final track = _tracks[song.id];
    if (track == null) return null;
    return LocalStorageService.playableUriForSongRef(track.ref);
  }

  Future<Uint8List?> artBytes(String artId) async {
    final bytes = await LocalStorageService.readCoverImageBytes(_artRef(artId));
    if (bytes == null || bytes.isEmpty) return null;
    return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  }

  Uri? artFileUri(String artId) => kIsWeb ? null : Uri.file(_artRef(artId));

  String _artRef(String artId) =>
      LocalStorageService.coverImagePath(_store, artId, 'img');

  Future<void> scan() async {
    final running = _scanning;
    if (running != null) return running;
    final future = _scan();
    _scanning = future;
    notifyListeners();
    try {
      await future;
    } finally {
      _scanning = null;
      notifyListeners();
    }
  }

  // scan local files and update the index
  Future<void> _scan() async {
    await init();
    final List<LocalMusicFile> files;
    try {
      files = await LocalStorageService.listLocalMusic();
    } catch (e) {
      loggerPrint('LocalMusic: failed to list files: $e');
      return;
    }

    final byName = {for (final t in _tracks.values) t.name: t};
    final next = <String, LocalTrack>{};
    var changed = false;

    for (final file in files) {
      final existing = byName.remove(file.name);
      if (existing != null &&
          existing.size == file.size &&
          existing.modified == file.modified) {
        next[existing.song.id] = existing.ref == file.ref
            ? existing
            : existing.withRef(file.ref);
        if (existing.ref != file.ref) changed = true;
        continue;
      }
      final track = await _readTrack(file);
      next[track.song.id] = track;
      changed = true;
      final oldArt = existing?.song.coverArt;
      if (oldArt != track.song.coverArt) await _deleteArt(oldArt);
    }

    var editsChanged = false;
    for (final gone in byName.values) {
      changed = true;
      await _deleteArt(gone.song.coverArt);
      if (_edits.remove(gone.name) != null) editsChanged = true;
    }
    if (editsChanged) await _saveEdits();

    if (changed) {
      _tracks
        ..clear()
        ..addAll(next);
      _resolved = null;
      await _saveIndex();
      notifyListeners();
      notifyLibraryChanged();
      loggerPrint('LocalMusic: ${_tracks.length} local files');
    }

    unawaited(_matchAlbums());
  }

  Future<void> _deleteArt(String? art) async {
    if (art == null || !isLocalArtId(art)) return;
    PaintingBinding.instance.imageCache.evict('$localArtScheme:$art');
    try {
      await LocalStorageService.deleteCoverImage(_artRef(art));
    } catch (_) {}
  }

  // get id3 tags & parse
  Future<LocalTrack> _readTrack(LocalMusicFile file) async {
    final hash = _hash(file.name);
    final id = '$localIdPrefix$hash';
    final read = await readLocalTags(file.ref) ?? _tagsFromName(file.name);
    final edit = _edits[file.name];
    final tags = edit == null ? read : LocalTagEdit.fromJson(edit).apply(read);
    final editedArt = edit?['art'] as String?;

    String? coverArt;
    final picture = tags.picture;
    if (editedArt != null) {
      coverArt = editedArt == _noArt ? null : editedArt;
    } else if (picture != null && picture.isNotEmpty) {
      final artId =
          '$localArtPrefix$hash-${md5.convert(picture).toString().substring(0, 8)}';
      try {
        await LocalStorageService.ensureDirs(_store);
        await LocalStorageService.writeCoverImageBytes(_artRef(artId), picture);
        coverArt = artId;
      } catch (_) {}
    }

    final fallback = _tagsFromName(file.name);
    final dot = file.name.lastIndexOf('.');
    final song = Song(
      id: id,
      title: tags.title ?? fallback.title ?? file.name,
      artist: tags.artist ?? tags.albumArtist ?? fallback.artist,
      album: tags.album ?? fallback.album,
      albumId: localFilesAlbumId,
      track: tags.track ?? fallback.track,
      discNumber: tags.disc,
      duration: tags.duration,
      coverArt: coverArt,
      bitRate: tags.bitRate,
      samplingRate: tags.sampleRate,
      suffix: dot >= 0 ? file.name.substring(dot + 1).toLowerCase() : null,
    );

    return LocalTrack(
      name: file.name,
      ref: file.ref,
      size: file.size,
      modified: file.modified,
      albumArtist: tags.albumArtist,
      year: tags.year,
      genre: tags.genre,
      song: song,
    );
  }

  LocalTags _tagsFromName(String name) {
    final parts = name.split('/');
    var stem = parts.last;
    final dot = stem.lastIndexOf('.');
    if (dot > 0) stem = stem.substring(0, dot);

    int? track;
    final numbered = RegExp(r'^(\d{1,3})[\s._-]+(.+)$').firstMatch(stem);
    if (numbered != null) {
      track = int.tryParse(numbered.group(1)!);
      stem = numbered.group(2)!;
    }

    String? artist;
    var title = stem.trim();
    final split = title.indexOf(' - ');
    if (split > 0) {
      artist = title.substring(0, split).trim();
      title = title.substring(split + 3).trim();
    }

    return LocalTags(
      title: title.isEmpty ? null : title,
      artist: artist ?? (parts.length >= 3 ? parts[parts.length - 3] : null),
      album: parts.length >= 2 ? parts[parts.length - 2] : null,
      track: track,
    );
  }

  Future<int> importFiles() async {
    final List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(
        dialogTitle: 'Import music',
        type: FileType.custom,
        allowedExtensions: localMusicExtensions.toList(),
      );
    } catch (e) {
      loggerPrint('LocalMusic: picker failed: $e');
      return 0;
    }

    var imported = 0;
    for (final file in picked) {
      if (!isLocalMusicName(file.name)) continue;
      try {
        final path = kIsWeb ? null : file.path;
        final ref = await LocalStorageService.importLocalMusic(
          file.name,
          sourcePath: path,
          bytes: path == null ? await file.readAsBytes() : null,
        );
        if (ref != null) imported++;
      } catch (e) {
        loggerPrint('LocalMusic: failed to import ${file.name}: $e');
      }
    }

    if (imported > 0) await scan();
    return imported;
  }

  bool canEditTags(Song song) => _tracks.containsKey(song.id);

  bool _canWriteFile(LocalTrack track) {
    final dot = track.name.lastIndexOf('.');
    return canWriteLocalTags &&
        dot >= 0 &&
        _editableSuffixes.contains(track.name.substring(dot + 1).toLowerCase());
  }

  Future<bool> editTags(Song song, LocalTagEdit edit) async {
    await _scanning;
    final track = _tracks[song.id];
    if (track == null) return false;

    if (_canWriteFile(track) && await writeLocalTags(track.ref, edit)) {
      if (_edits.remove(track.name) != null) await _saveEdits();
      await scan();
      return true;
    }

    var art = _edits[track.name]?['art'] as String?;
    if (edit.pictureChanged) {
      final picture = edit.picture;
      if (picture == null || picture.isEmpty) {
        art = _noArt;
      } else {
        art =
            '$localArtPrefix${_hash(track.name)}-${md5.convert(picture).toString().substring(0, 8)}';
        try {
          await LocalStorageService.ensureDirs(_store);
          await LocalStorageService.writeCoverImageBytes(_artRef(art), picture);
        } catch (e) {
          loggerPrint('LocalMusic: failed to save artwork: $e');
          return false;
        }
      }
    }

    _edits[track.name] = {...edit.toJson(), 'art': ?art};
    if (!await _saveEdits()) return false;
    await _reread(track);
    return true;
  }

  Future<void> _reread(LocalTrack track) async {
    final updated = await _readTrack(
      LocalMusicFile(
        ref: track.ref,
        name: track.name,
        size: track.size,
        modified: track.modified,
      ),
    );
    if (updated.song.coverArt != track.song.coverArt) {
      await _deleteArt(track.song.coverArt);
    }
    _tracks[updated.song.id] = updated;
    _resolved = null;
    await _saveIndex();
    notifyListeners();
    notifyLibraryChanged();
    unawaited(_matchAlbums());
  }

  Future<void> delete(Song song) async {
    final track = _tracks[song.id];
    if (track == null) return;
    await LocalStorageService.deleteLocalMusic(track.ref);
    await scan();
  }

  Song _resolve(LocalTrack track) {
    if (_localMode) {
      return Song.fromJson({
        ...track.song.toJson(),
        'albumId': track.localAlbumId,
        'artistId': track.localArtistId,
      });
    }
    final key = track.albumKey;
    final match = key == null ? null : _matches[key];
    if (match == null) return track.song;
    return Song.fromJson({
      ...track.song.toJson(),
      'albumId': match.id,
      'coverArt': ?(match.coverArt ?? track.song.coverArt),
    });
  }

  List<Song> _sorted(Iterable<Song> source, {bool keepTracks = false}) {
    String lower(String? v) => v?.toLowerCase() ?? '';
    final list = source.toList()
      ..sort((a, b) {
        if (!keepTracks) {
          final artist = lower(a.artist).compareTo(lower(b.artist));
          if (artist != 0) return artist;
          final album = lower(a.album).compareTo(lower(b.album));
          if (album != 0) return album;
        }
        final disc = (a.discNumber ?? 1).compareTo(b.discNumber ?? 1);
        if (disc != 0) return disc;
        final track = (a.track ?? 1 << 20).compareTo(b.track ?? 1 << 20);
        if (track != 0) return track;
        final title = lower(a.title).compareTo(lower(b.title));
        return title != 0 ? title : a.id.compareTo(b.id);
      });
    return list;
  }

  void _onProviderChanged() {
    final provider = _provider;
    if (provider == null) return;
    final account = provider.activeAccount;
    final localMode = account?.isLocal ?? false;
    final accountId = localMode ? null : account?.id;
    if (accountId != _accountId || localMode != _localMode) {
      _accountId = accountId;
      _localMode = localMode;
      _matches = {};
      _playlists = {};
      _attempted.clear();
      _resolved = null;
      _accountLoading = accountId == null ? null : _loadAccount(accountId);
      notifyListeners();
      return;
    }
    if (!provider.isOffline) unawaited(_matchAlbums());
  }

  Future<void> _ensureAccount(String accountId) async {
    if (accountId != _accountId) return;
    await _accountLoading;
  }

  Future<void> _loadAccount(String accountId) async {
    try {
      final matches = await LocalStorageService.readJsonMeta(
        accountId,
        _matchesKey,
      );
      final playlists = await LocalStorageService.readJsonMeta(
        accountId,
        _playlistsKey,
      );
      if (_accountId != accountId) return;
      _matches = {
        for (final e in (matches ?? const {}).entries)
          e.key: _AlbumMatch.fromJson(e.value as Map<String, dynamic>),
      };
      _playlists = {
        for (final e in (playlists ?? const {}).entries)
          e.key: [
            for (final entry in e.value as List<dynamic>)
              _PlaylistEntry.fromJson(entry as Map<String, dynamic>),
          ],
      };
      _resolved = null;
      notifyListeners();
    } catch (e) {
      loggerPrint('LocalMusic: failed to load account data: $e');
    }
    unawaited(_matchAlbums());
  }

  Future<void> _matchAlbums() async {
    final provider = _provider;
    final accountId = _accountId;
    if (provider == null || accountId == null || _matching) return;
    if (provider.isOffline || provider.activeAccount?.id != accountId) return;
    await _accountLoading;
    if (_accountId != accountId) return;

    final pending = <String, LocalTrack>{};
    for (final track in _tracks.values) {
      final key = track.albumKey;
      if (key == null || _matches.containsKey(key)) continue;
      if (_attempted.contains(key)) continue;
      pending[key] ??= track;
    }
    if (pending.isEmpty) return;

    _matching = true;
    var changed = false;
    try {
      final api = provider.subsonic;
      for (final MapEntry(key: key, value: track) in pending.entries) {
        if (_accountId != accountId || provider.isOffline) return;
        _attempted.add(key);
        final album = track.song.album!;
        final result = await api.search3(
          album,
          artistCount: 0,
          albumCount: 20,
          songCount: 0,
        );
        final artist = (track.albumArtist ?? track.song.artist ?? '')
            .toLowerCase();
        final hit = result.albums.where((a) {
          if (a.name.trim().toLowerCase() != album.toLowerCase()) return false;
          final other = a.artist.trim().toLowerCase();
          if (artist.isEmpty || other.isEmpty) return true;
          return other == artist ||
              other.contains(artist) ||
              artist.contains(other);
        }).firstOrNull;
        if (hit == null) continue;
        _matches[key] = _AlbumMatch(
          hit.id,
          hit.coverArt.isEmpty ? null : hit.coverArt,
        );
        changed = true;
      }
    } catch (e) {
      loggerPrint('LocalMusic: album matching failed: $e');
    } finally {
      _matching = false;
    }

    if (changed && _accountId == accountId) {
      _resolved = null;
      await _saveMatches(accountId);
      notifyListeners();
    }
  }

  bool hasPlaylistEntries(String accountId, String playlistId) =>
      accountId == _accountId && (_playlists[playlistId]?.isNotEmpty ?? false);

  Future<PlaylistDetail> mergePlaylist(
    String accountId,
    PlaylistDetail playlist,
  ) async {
    await _ensureAccount(accountId);
    if (!hasPlaylistEntries(accountId, playlist.id)) return playlist;

    final songs = [
      for (final slot in _slots(playlist.id, playlist.songs.length))
        slot.entry != null
            ? song(slot.entry!.id)!
            : playlist.songs[slot.server!],
    ];

    return PlaylistDetail(
      id: playlist.id,
      name: playlist.name,
      comment: playlist.comment,
      songCount: songs.length,
      duration: songs.fold(0, (sum, s) => sum + (s.duration ?? 0)),
      coverArt: playlist.coverArt,
      owner: playlist.owner,
      public: playlist.public,
      songs: songs,
    );
  }

  Future<List<Playlist>> adjustPlaylists(
    String accountId,
    List<Playlist> playlists,
  ) async {
    await _ensureAccount(accountId);
    if (accountId != _accountId || _playlists.isEmpty) return playlists;
    return [
      for (final p in playlists)
        if (_presentEntries(p.id) case final extra when extra.isNotEmpty)
          Playlist(
            id: p.id,
            name: p.name,
            comment: p.comment,
            songCount: p.songCount + extra.length,
            duration:
                p.duration + extra.fold(0, (sum, s) => sum + (s.duration ?? 0)),
            coverArt: p.coverArt,
            owner: p.owner,
            public: p.public,
          )
        else
          p,
    ];
  }

  List<Song> _presentEntries(String playlistId) => [
    for (final entry in _playlists[playlistId] ?? const <_PlaylistEntry>[])
      ?song(entry.id),
  ];

  Future<void> addToPlaylist(
    String accountId,
    String playlistId,
    String songId,
    int serverCount,
  ) async {
    await _ensureAccount(accountId);
    if (accountId != _accountId) return;
    final entries = _playlists.putIfAbsent(playlistId, () => []);
    entries.add(_PlaylistEntry(songId, serverCount));
    await _savePlaylists(accountId);
  }

  Future<int?> removeFromPlaylist(
    String accountId,
    String playlistId,
    int index,
    int serverCount,
  ) async {
    await _ensureAccount(accountId);
    if (!hasPlaylistEntries(accountId, playlistId)) return index;

    final slots = _slots(playlistId, serverCount);
    if (index < 0 || index >= slots.length) return null;
    final slot = slots[index];
    final entries = _playlists[playlistId]!;

    if (slot.entry != null) {
      entries.remove(slot.entry);
      await _savePlaylists(accountId);
      return null;
    }

    final serverIndex = slot.server!;
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].after > serverIndex) {
        entries[i] = _PlaylistEntry(entries[i].id, entries[i].after - 1);
      }
    }
    await _savePlaylists(accountId);
    return serverIndex;
  }

  Future<List<String>> reorderPlaylist(
    String accountId,
    String playlistId,
    List<String> ids,
  ) async {
    await _ensureAccount(accountId);
    final hasLocal = ids.any(isLocalSongId);
    if (!hasLocal && !hasPlaylistEntries(accountId, playlistId)) return ids;
    if (accountId != _accountId) {
      return ids.where((id) => !isLocalSongId(id)).toList();
    }

    final serverIds = <String>[];
    final entries = <_PlaylistEntry>[];
    for (final id in ids) {
      if (isLocalSongId(id)) {
        entries.add(_PlaylistEntry(id, serverIds.length));
      } else {
        serverIds.add(id);
      }
    }
    for (final old in _playlists[playlistId] ?? const <_PlaylistEntry>[]) {
      if (song(old.id) != null) continue;
      entries.add(
        _PlaylistEntry(old.id, old.after.clamp(0, serverIds.length).toInt()),
      );
    }
    final ordered = entries.indexed.toList()
      ..sort((a, b) {
        final after = a.$2.after.compareTo(b.$2.after);
        return after != 0 ? after : a.$1.compareTo(b.$1);
      });
    _playlists[playlistId] = ordered.map((e) => e.$2).toList();
    await _savePlaylists(accountId);
    return serverIds;
  }

  List<_Slot> _slots(String playlistId, int serverCount) {
    final entries = [
      for (final e in _playlists[playlistId] ?? const <_PlaylistEntry>[])
        if (song(e.id) != null) e,
    ];
    final slots = <_Slot>[];
    var e = 0;
    for (var i = 0; i <= serverCount; i++) {
      while (e < entries.length && entries[e].after <= i) {
        slots.add(_Slot.entry(entries[e++]));
      }
      if (i < serverCount) slots.add(_Slot.server(i));
    }
    while (e < entries.length) {
      slots.add(_Slot.entry(entries[e++]));
    }
    return slots;
  }

  Future<void> _loadIndex() async {
    try {
      final edits = await LocalStorageService.readJsonMeta(_store, _editsKey);
      edits?.forEach((name, edit) {
        if (edit is Map<String, dynamic>) _edits[name] = edit;
      });
    } catch (e) {
      loggerPrint('LocalMusic: failed to load edits: $e');
    }
    try {
      final raw = await LocalStorageService.readJsonMeta(_store, _indexKey);
      if (raw == null || raw['version'] != _indexVersion) return;
      for (final item in raw['tracks'] as List<dynamic>) {
        final track = LocalTrack.fromJson(item as Map<String, dynamic>);
        _tracks[track.song.id] = track;
      }
      _resolved = null;
    } catch (e) {
      loggerPrint('LocalMusic: failed to load index: $e');
    }
  }

  Future<void> _saveIndex() async {
    try {
      await LocalStorageService.ensureDirs(_store);
      await LocalStorageService.writeJsonMeta(_store, _indexKey, {
        'version': _indexVersion,
        'tracks': [for (final t in _tracks.values) t.toJson()],
      });
    } catch (e) {
      loggerPrint('LocalMusic: failed to save index: $e');
    }
  }

  Future<bool> _saveEdits() async {
    try {
      await LocalStorageService.ensureDirs(_store);
      await LocalStorageService.writeJsonMeta(_store, _editsKey, _edits);
      return true;
    } catch (e) {
      loggerPrint('LocalMusic: failed to save edits: $e');
      return false;
    }
  }

  Future<void> _saveMatches(String accountId) async {
    try {
      await LocalStorageService.ensureDirs(accountId);
      await LocalStorageService.writeJsonMeta(accountId, _matchesKey, {
        for (final e in _matches.entries) e.key: e.value.toJson(),
      });
    } catch (_) {}
  }

  Future<void> _savePlaylists(String accountId) async {
    _playlists.removeWhere((_, entries) => entries.isEmpty);
    try {
      await LocalStorageService.ensureDirs(accountId);
      await LocalStorageService.writeJsonMeta(accountId, _playlistsKey, {
        for (final e in _playlists.entries)
          e.key: [for (final entry in e.value) entry.toJson()],
      });
    } catch (_) {}
    notifyListeners();
  }
}

class LocalTrack {
  final String name;
  final String ref;
  final int size;
  final int modified;
  final String? albumArtist;
  final int? year;
  final String? genre;
  final Song song;

  const LocalTrack({
    required this.name,
    required this.ref,
    required this.size,
    required this.modified,
    required this.song,
    this.albumArtist,
    this.year,
    this.genre,
  });

  factory LocalTrack.fromJson(Map<String, dynamic> json) => LocalTrack(
    name: json['name'] as String,
    ref: json['ref'] as String,
    size: (json['size'] as num).toInt(),
    modified: (json['modified'] as num).toInt(),
    albumArtist: json['albumArtist'] as String?,
    year: (json['year'] as num?)?.toInt(),
    genre: json['genre'] as String?,
    song: Song.fromJson(json['song'] as Map<String, dynamic>),
  );

  String get albumName => _text(song.album) ?? 'Unknown Album';

  String get albumArtistName =>
      _text(albumArtist) ?? _text(song.artist) ?? 'Unknown Artist';

  String get localAlbumId =>
      '$localAlbumPrefix${_hash('${albumArtistName.toLowerCase()}|${albumName.toLowerCase()}')}';

  String get localArtistId =>
      '$localArtistPrefix${_hash(albumArtistName.toLowerCase())}';

  static String? _text(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String? get albumKey {
    final album = song.album?.trim().toLowerCase();
    if (album == null || album.isEmpty) return null;
    final artist = (albumArtist ?? song.artist ?? '').trim().toLowerCase();
    return '$artist|$album';
  }

  LocalTrack withRef(String ref) => LocalTrack(
    name: name,
    ref: ref,
    size: size,
    modified: modified,
    albumArtist: albumArtist,
    year: year,
    genre: genre,
    song: song,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'ref': ref,
    'size': size,
    'modified': modified,
    'albumArtist': ?albumArtist,
    'year': ?year,
    'genre': ?genre,
    'song': song.toJson(),
  };
}

class _AlbumMatch {
  final String id;
  final String? coverArt;

  const _AlbumMatch(this.id, this.coverArt);

  factory _AlbumMatch.fromJson(Map<String, dynamic> json) =>
      _AlbumMatch(json['id'] as String, json['coverArt'] as String?);

  Map<String, dynamic> toJson() => {'id': id, 'coverArt': ?coverArt};
}

class _PlaylistEntry {
  final String id;
  final int after;

  const _PlaylistEntry(this.id, this.after);

  factory _PlaylistEntry.fromJson(Map<String, dynamic> json) =>
      _PlaylistEntry(json['id'] as String, (json['after'] as num).toInt());

  Map<String, dynamic> toJson() => {'id': id, 'after': after};
}

class _Slot {
  final _PlaylistEntry? entry;
  final int? server;

  const _Slot.entry(this.entry) : server = null;
  const _Slot.server(this.server) : entry = null;
}
