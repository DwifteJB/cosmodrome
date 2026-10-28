import 'dart:async';
import 'dart:math';

import 'package:cosmodrome/helpers/subsonic-api-helper/errors.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/subsonic-user.dart';
import 'package:cosmodrome/services/local_music/local_music_service.dart';
import 'package:cosmodrome/services/local_storage_service.dart';
import 'package:cosmodrome/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';

const localBaseUrl = 'device';
const localUsername = 'Local Files';
const localServerName = 'This Device';

const _store = 'local';
const _stateKey = 'account';
const _notFound = 70;
const _missingParameter = 10;

// instead of http, this just reads from local music service
class LocalSubsonic extends Subsonic {
  final SubsonicUser user = SubsonicUser(
    username: localUsername,
    adminRole: true,
    settingsRole: true,
    downloadRole: true,
    playlistRole: true,
    coverArtRole: true,
    streamRole: true,
  );

  final Map<String, _LocalPlaylist> _playlists = {};
  final Map<String, DateTime> _starred = {};
  final _random = Random();
  Future<void>? _loading;
  _LocalIndex? _index;

  LocalSubsonic()
    : super(baseUrl: localBaseUrl, username: localUsername, password: '') {
    loginMethod = SubsonicLoginMethod.token;
    localMusicService.addListener(_invalidate);
  }

  @override
  bool get isLocal => true;

  @override
  Future<Map<String, dynamic>> apiRequest(
    String endpoint, {
    Map<String, String> params = const {},
    int? timeoutSeconds,
    bool forceRefresh = false,
  }) => _handle(endpoint, params);

  @override
  Future<Uint8List> bytesApiRequest(
    String endpoint, {
    Map<String, String> params = const {},
  }) async {
    if (endpoint != 'getCoverArt') return Uint8List(0);
    final id = params['id'];
    final bytes = id == null ? null : await localMusicService.artBytes(id);
    if (bytes == null) {
      throw SubsonicApiException(endpoint, _notFound, 'cover art not found');
    }
    return bytes;
  }

  @override
  Future<SubsonicLoginMethod> determineLoginMethod() async => loginMethod;

  @override
  Future<Map<String, dynamic>> multiParamRequest(
    String endpoint, {
    Map<String, dynamic> params = const {},
  }) => _handle(endpoint, params);

  @override
  String streamUrl(String id) => 'local:$id';

  @override
  Future<void> warmStream(String id) async {}

  Future<Map<String, dynamic>> _handle(
    String endpoint,
    Map<String, dynamic> params,
  ) async {
    await localMusicService.init();
    await (_loading ??= _load());

    final name = endpoint.endsWith('.view')
        ? endpoint.substring(0, endpoint.length - 5)
        : endpoint;
    final args = _Args(endpoint, params);

    final body = switch (name) {
      'ping' || 'scrobble' => const <String, dynamic>{},
      'getLicense' => {
        'license': {'valid': 'true'},
      },
      'getUser' => {'user': user.toJson()},
      'getScanStatus' => _scanStatus(),
      'startScan' => _startScan(),
      'getOpenSubsonicExtensions' => {'openSubsonicExtensions': const []},
      'getLyricsBySongId' => {'lyricsList': const <String, dynamic>{}},
      'getLyrics' => {'lyrics': const <String, dynamic>{}},
      'getMusicFolders' => {
        'musicFolders': {
          'musicFolder': [
            {'id': 1, 'name': localUsername},
          ],
        },
      },
      'getIndexes' => {
        'indexes': {'index': _artistIndex()},
      },
      'getArtists' => {
        'artists': {'index': _artistIndex()},
      },
      'getArtist' => {'artist': _artistJson(_artist(args), albums: true)},
      'getArtistInfo2' => {'artistInfo2': const <String, dynamic>{}},
      'getAlbum' => {'album': _albumJson(_album(args), songs: true)},
      'getAlbumList2' => {
        'albumList2': {'album': _albumList(args)},
      },
      'getGenres' => {
        'genres': {'genre': _genres()},
      },
      'getSong' => {'song': _songJson(_track(args))},
      'getRandomSongs' => {
        'randomSongs': {'song': _randomSongs(args)},
      },
      'getTopSongs' => {
        'topSongs': {'song': _topSongs(args)},
      },
      'search2' || 'search3' => {'searchResult3': _search(args)},
      'getStarred' || 'getStarred2' => {'starred2': _starredJson()},
      'star' => await _setStarred(args, true),
      'unstar' => await _setStarred(args, false),
      'getPlaylists' => {
        'playlists': {
          'playlist': [for (final p in _playlists.values) _playlistJson(p)],
        },
      },
      'getPlaylist' => {
        'playlist': _playlistJson(_playlist(args, 'id'), entries: true),
      },
      'createPlaylist' => await _createPlaylist(args),
      'updatePlaylist' => await _updatePlaylist(args),
      'deletePlaylist' => await _deletePlaylist(args),
      _ => throw SubsonicApiException(
        endpoint,
        0,
        'not supported for local files',
      ),
    };

    return {'status': 'ok', 'version': '1.16.1', ...body};
  }

  _LocalIndex get _library => _index ??= _LocalIndex.build();

  void _invalidate() => _index = null;

  Map<String, dynamic> _scanStatus() => {
    'scanStatus': {
      'scanning': localMusicService.isScanning,
      'count': localMusicService.count,
    },
  };

  Map<String, dynamic> _startScan() {
    unawaited(localMusicService.scan());
    return _scanStatus();
  }

  LocalTrack _track(_Args args) {
    final track = localMusicService.track(args.require('id'));
    if (track == null) throw args.notFound('song');
    return track;
  }

  _LocalAlbum _album(_Args args) {
    final album = _library.albums[args.require('id')];
    if (album == null) throw args.notFound('album');
    return album;
  }

  _LocalArtist _artist(_Args args) {
    final artist = _library.artists[args.require('id')];
    if (artist == null) throw args.notFound('artist');
    return artist;
  }

  _LocalPlaylist _playlist(_Args args, String key) {
    final playlist = _playlists[args.require(key)];
    if (playlist == null) throw args.notFound('playlist');
    return playlist;
  }

  List<Map<String, dynamic>> _artistIndex() {
    final groups = <String, List<_LocalArtist>>{};
    for (final artist in _library.sortedArtists) {
      final first = artist.name.substring(0, 1).toUpperCase();
      final key = RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
      groups.putIfAbsent(key, () => []).add(artist);
    }
    final keys = groups.keys.toList()..sort();
    return [
      for (final key in keys)
        {
          'name': key,
          'artist': [for (final a in groups[key]!) _artistJson(a)],
        },
    ];
  }

  List<Map<String, dynamic>> _albumList(_Args args) {
    final albums = _library.albums.values.toList();
    int byName(_LocalAlbum a, _LocalAlbum b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());

    switch (args.get('type')) {
      case 'random':
        albums.shuffle(_random);
      case 'newest' || 'recent' || 'frequent' || 'highest':
        albums.sort((a, b) => b.created.compareTo(a.created));
      case 'alphabeticalByArtist':
        albums.sort((a, b) {
          final artist = a.artist.toLowerCase().compareTo(
            b.artist.toLowerCase(),
          );
          return artist != 0 ? artist : byName(a, b);
        });
      case 'starred':
        albums
          ..retainWhere((a) => _starred.containsKey(a.id))
          ..sort(byName);
      case 'byYear':
        final from = args.integer('fromYear', 0);
        final to = args.integer('toYear', 9999);
        final low = min(from, to);
        final high = max(from, to);
        albums
          ..retainWhere((a) {
            final year = a.year;
            return year != null && year >= low && year <= high;
          })
          ..sort(
            (a, b) => from <= to
                ? a.year!.compareTo(b.year!)
                : b.year!.compareTo(a.year!),
          );
      case 'byGenre':
        final genre = args.get('genre')?.toLowerCase();
        albums
          ..retainWhere((a) => a.genres.contains(genre))
          ..sort(byName);
      default:
        albums.sort(byName);
    }

    return [
      for (final album in _page(
        albums,
        args.integer('offset', 0),
        args.integer('size', 10),
      ))
        _albumJson(album),
    ];
  }

  List<Map<String, dynamic>> _genres() {
    final songs = <String, int>{};
    final albums = <String, int>{};
    final names = <String, String>{};
    for (final album in _library.albums.values) {
      for (final track in album.tracks) {
        final genre = track.genre?.trim();
        if (genre == null || genre.isEmpty) continue;
        final key = genre.toLowerCase();
        names.putIfAbsent(key, () => genre);
        songs[key] = (songs[key] ?? 0) + 1;
      }
      for (final key in album.genres) {
        albums[key] = (albums[key] ?? 0) + 1;
      }
    }
    return [
      for (final key in names.keys)
        {
          'value': names[key],
          'songCount': songs[key] ?? 0,
          'albumCount': albums[key] ?? 0,
        },
    ];
  }

  List<Map<String, dynamic>> _randomSongs(_Args args) {
    final tracks = _library.tracks.toList()..shuffle(_random);
    return [
      for (final track in tracks.take(args.integer('size', 10)))
        _songJson(track),
    ];
  }

  List<Map<String, dynamic>> _topSongs(_Args args) {
    final name = args.require('artist').toLowerCase();
    return [
      for (final track in _library.tracks.where(
        (t) =>
            t.albumArtistName.toLowerCase() == name ||
            t.song.artist?.toLowerCase() == name,
      ))
        _songJson(track),
    ].take(args.integer('count', 50)).toList();
  }

  Map<String, dynamic> _search(_Args args) {
    final query = (args.get('query') ?? '')
        .replaceAll('"', '')
        .trim()
        .toLowerCase();
    bool matches(String? value) =>
        query.isEmpty || (value?.toLowerCase().contains(query) ?? false);

    final artists = _library.sortedArtists.where((a) => matches(a.name));
    final albums = _library.albums.values.where(
      (a) => matches(a.name) || matches(a.artist),
    );
    final songs = _library.tracks.where(
      (t) =>
          matches(t.song.title) ||
          matches(t.song.artist) ||
          matches(t.song.album),
    );

    return {
      'artist': [
        for (final a in _page(
          artists,
          args.integer('artistOffset', 0),
          args.integer('artistCount', 20),
        ))
          _artistJson(a),
      ],
      'album': [
        for (final a in _page(
          albums,
          args.integer('albumOffset', 0),
          args.integer('albumCount', 20),
        ))
          _albumJson(a),
      ],
      'song': [
        for (final t in _page(
          songs,
          args.integer('songOffset', 0),
          args.integer('songCount', 20),
        ))
          _songJson(t),
      ],
    };
  }

  Map<String, dynamic> _starredJson() => {
    'artist': [
      for (final a in _library.sortedArtists)
        if (_starred.containsKey(a.id)) _artistJson(a),
    ],
    'album': [
      for (final a in _library.albums.values)
        if (_starred.containsKey(a.id)) _albumJson(a),
    ],
    'song': [
      for (final t in _library.tracks)
        if (_starred.containsKey(t.song.id)) _songJson(t),
    ],
  };

  Future<Map<String, dynamic>> _setStarred(_Args args, bool starred) async {
    final ids = [
      ...args.list('id'),
      ...args.list('albumId'),
      ...args.list('artistId'),
    ];
    if (ids.isEmpty) throw args.missing('id');
    final now = DateTime.now();
    for (final id in ids) {
      if (starred) {
        _starred[id] = now;
      } else {
        _starred.remove(id);
      }
    }
    await _save();
    return const {};
  }

  Future<Map<String, dynamic>> _createPlaylist(_Args args) async {
    final existing = args.get('playlistId');
    final songs = args.list('songId');
    final now = DateTime.now();

    final _LocalPlaylist playlist;
    if (existing != null) {
      playlist = _playlist(args, 'playlistId');
      playlist.songs
        ..clear()
        ..addAll(songs);
      playlist.name = args.get('name') ?? playlist.name;
      playlist.changed = now;
    } else {
      playlist = _LocalPlaylist(
        id: '$localPlaylistPrefix${now.microsecondsSinceEpoch.toRadixString(36)}',
        name: args.require('name'),
        created: now,
        changed: now,
        songs: songs,
      );
      _playlists[playlist.id] = playlist;
    }

    await _save();
    return {'playlist': _playlistJson(playlist, entries: true)};
  }

  Future<Map<String, dynamic>> _updatePlaylist(_Args args) async {
    final playlist = _playlist(args, 'playlistId');
    playlist.name = args.get('name') ?? playlist.name;
    if (args.get('comment') case final comment?) playlist.comment = comment;

    final visible = [
      for (final (i, id) in playlist.songs.indexed)
        if (localMusicService.track(id) != null) i,
    ];
    final remove =
        args
            .list('songIndexToRemove')
            .map(int.tryParse)
            .nonNulls
            .where((i) => i >= 0 && i < visible.length)
            .map((i) => visible[i])
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    for (final i in remove) {
      playlist.songs.removeAt(i);
    }
    playlist.songs.addAll(args.list('songIdToAdd'));
    playlist.changed = DateTime.now();

    await _save();
    return const {};
  }

  Future<Map<String, dynamic>> _deletePlaylist(_Args args) async {
    if (_playlists.remove(args.require('id')) == null) {
      throw args.notFound('playlist');
    }
    await _save();
    return const {};
  }

  Map<String, dynamic> _songJson(LocalTrack track) => {
    ...track.song.toJson(),
    'album': track.albumName,
    'albumId': track.localAlbumId,
    'artist': track.song.artist ?? track.albumArtistName,
    'artistId': track.localArtistId,
    'year': ?track.year,
    'genre': ?track.genre,
    'size': track.size,
    'created': _date(track.modified),
    'starred': ?_starred[track.song.id]?.toIso8601String(),
    'isDir': false,
    'type': 'music',
  };

  Map<String, dynamic> _albumJson(_LocalAlbum album, {bool songs = false}) => {
    'id': album.id,
    'name': album.name,
    'artist': album.artist,
    'artistId': album.artistId,
    'coverArt': ?album.coverArt,
    'songCount': album.tracks.length,
    'duration': album.duration,
    'year': ?album.year,
    'genre': ?album.genre,
    'created': _date(album.created),
    'starred': ?_starred[album.id]?.toIso8601String(),
    if (songs) 'song': [for (final t in album.tracks) _songJson(t)],
  };

  Map<String, dynamic> _artistJson(
    _LocalArtist artist, {
    bool albums = false,
  }) => {
    'id': artist.id,
    'name': artist.name,
    'albumCount': artist.albums.length,
    'coverArt': ?artist.coverArt,
    'starred': ?_starred[artist.id]?.toIso8601String(),
    if (albums) 'album': [for (final a in artist.albums) _albumJson(a)],
  };

  Map<String, dynamic> _playlistJson(
    _LocalPlaylist playlist, {
    bool entries = false,
  }) {
    final tracks = [
      for (final id in playlist.songs) ?localMusicService.track(id),
    ];
    return {
      'id': playlist.id,
      'name': playlist.name,
      'comment': ?playlist.comment,
      'owner': localUsername,
      'public': false,
      'songCount': tracks.length,
      'duration': tracks.fold(0, (sum, t) => sum + (t.song.duration ?? 0)),
      'created': playlist.created.toIso8601String(),
      'changed': playlist.changed.toIso8601String(),
      'coverArt': ?tracks
          .map((t) => t.song.coverArt)
          .firstWhere((c) => c != null, orElse: () => null),
      if (entries) 'entry': [for (final t in tracks) _songJson(t)],
    };
  }

  Iterable<T> _page<T>(Iterable<T> items, int offset, int size) =>
      items.skip(max(0, offset)).take(max(0, size));

  String _date(int millis) =>
      DateTime.fromMillisecondsSinceEpoch(millis).toIso8601String();

  Future<void> _load() async {
    try {
      final raw = await LocalStorageService.readJsonMeta(_store, _stateKey);
      if (raw == null) return;
      for (final item in raw['playlists'] as List<dynamic>? ?? const []) {
        final playlist = _LocalPlaylist.fromJson(item as Map<String, dynamic>);
        _playlists[playlist.id] = playlist;
      }
      final starred = raw['starred'] as Map<String, dynamic>? ?? const {};
      for (final MapEntry(:key, :value) in starred.entries) {
        final date = DateTime.tryParse(value as String);
        if (date != null) _starred[key] = date;
      }
    } catch (e) {
      loggerPrint('LocalSubsonic: failed to load state: $e');
    }
  }

  Future<void> _save() async {
    try {
      await LocalStorageService.ensureDirs(_store);
      await LocalStorageService.writeJsonMeta(_store, _stateKey, {
        'playlists': [for (final p in _playlists.values) p.toJson()],
        'starred': {
          for (final e in _starred.entries) e.key: e.value.toIso8601String(),
        },
      });
    } catch (e) {
      loggerPrint('LocalSubsonic: failed to save state: $e');
    }
  }
}

class _Args {
  final String endpoint;
  final Map<String, dynamic> params;

  const _Args(this.endpoint, this.params);

  String? get(String key) {
    final value = params[key];
    if (value is List) return value.isEmpty ? null : '${value.first}';
    return value?.toString();
  }

  int integer(String key, int fallback) =>
      int.tryParse(get(key) ?? '') ?? fallback;

  List<String> list(String key) {
    final value = params[key];
    if (value == null) return [];
    return value is List ? [for (final v in value) '$v'] : ['$value'];
  }

  SubsonicApiException missing(String key) => SubsonicApiException(
    endpoint,
    _missingParameter,
    'required parameter is missing: $key',
  );

  SubsonicApiException notFound(String what) =>
      SubsonicApiException(endpoint, _notFound, '$what not found');

  String require(String key) => get(key) ?? (throw missing(key));
}

class _LocalIndex {
  final Map<String, _LocalAlbum> albums;
  final Map<String, _LocalArtist> artists;
  final List<_LocalArtist> sortedArtists;
  final List<LocalTrack> tracks;

  _LocalIndex(this.albums, this.artists, this.tracks)
    : sortedArtists = artists.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  factory _LocalIndex.build() {
    final tracks = [
      for (final song in localMusicService.songs)
        ?localMusicService.track(song.id),
    ];
    final albums = <String, _LocalAlbum>{};
    for (final track in tracks) {
      albums
          .putIfAbsent(track.localAlbumId, () => _LocalAlbum(track))
          .add(track);
    }
    final artists = <String, _LocalArtist>{};
    for (final album in albums.values) {
      artists
          .putIfAbsent(album.artistId, () => _LocalArtist(album))
          .albums
          .add(album);
    }
    return _LocalIndex(albums, artists, tracks);
  }
}

class _LocalAlbum {
  final String id;
  final String name;
  final String artist;
  final String artistId;
  final List<LocalTrack> tracks = [];

  _LocalAlbum(LocalTrack track)
    : id = track.localAlbumId,
      name = track.albumName,
      artist = track.albumArtistName,
      artistId = track.localArtistId;

  String? get coverArt => tracks
      .map((t) => t.song.coverArt)
      .firstWhere((c) => c != null, orElse: () => null);

  int get created => tracks.fold(0, (latest, t) => max(latest, t.modified));

  int get duration => tracks.fold(0, (sum, t) => sum + (t.song.duration ?? 0));

  String? get genre => tracks
      .map((t) => t.genre)
      .firstWhere((g) => g != null && g.trim().isNotEmpty, orElse: () => null);

  Set<String> get genres => {
    for (final t in tracks)
      if (t.genre?.trim() case final g? when g.isNotEmpty) g.toLowerCase(),
  };

  int? get year => tracks
      .map((t) => t.year)
      .firstWhere((y) => y != null, orElse: () => null);

  void add(LocalTrack track) => tracks.add(track);
}

class _LocalArtist {
  final String id;
  final String name;
  final List<_LocalAlbum> albums = [];

  _LocalArtist(_LocalAlbum album) : id = album.artistId, name = album.artist;

  String? get coverArt => albums
      .map((a) => a.coverArt)
      .firstWhere((c) => c != null, orElse: () => null);
}

class _LocalPlaylist {
  final String id;
  String name;
  String? comment;
  final DateTime created;
  DateTime changed;
  final List<String> songs;

  _LocalPlaylist({
    required this.id,
    required this.name,
    required this.created,
    required this.changed,
    required List<String> songs,
    this.comment,
  }) : songs = [...songs];

  factory _LocalPlaylist.fromJson(Map<String, dynamic> json) {
    final created =
        DateTime.tryParse(json['created'] as String? ?? '') ?? DateTime.now();
    return _LocalPlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      comment: json['comment'] as String?,
      created: created,
      changed: DateTime.tryParse(json['changed'] as String? ?? '') ?? created,
      songs: [for (final id in json['songs'] as List<dynamic>? ?? []) '$id'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'comment': ?comment,
    'created': created.toIso8601String(),
    'changed': changed.toIso8601String(),
    'songs': songs,
  };
}
