import 'dart:async';
import 'dart:math';

import 'package:cosmodrome/helpers/subsonic-api-helper/errors.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/subsonic-user.dart';
import 'package:cosmodrome/services/local_music/local_music_service.dart';
import 'package:cosmodrome/services/local_storage_service.dart';
import 'package:cosmodrome/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';

// alll the components
part 'api/browsing.dart';
part 'api/playlists.dart';
part 'api/search.dart';
part 'api/starring.dart';
part 'api/system.dart';
part 'json/responses.dart';
part 'models/args.dart';
part 'models/library_index.dart';
part 'models/playlist.dart';
part 'storage/state.dart';

const localBaseUrl = 'device';
const localUsername = 'Local Files';
const localServerName = 'This Device';

const _store = 'local';
const _stateKey = 'account';
const _notFound = 70;
const _missingParameter = 10;

// instead of http, this just reads from local music service
class MasterSubsonic extends Subsonic {
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

  MasterSubsonic()
    : super(baseUrl: localBaseUrl, username: localUsername, password: '') {
    loginMethod = SubsonicLoginMethod.token;
    localMusicService.addListener(_invalidate);
  }

  @override
  bool get isLocal => true;

  _LocalIndex get _library => _index ??= _LocalIndex.build();

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
      'getLicense' => _license(),
      'getUser' => {'user': user.toJson()},
      'getScanStatus' => _scanStatus(),
      'startScan' => _startScan(),
      'getOpenSubsonicExtensions' => {'openSubsonicExtensions': const []},
      'getLyricsBySongId' => {'lyricsList': const <String, dynamic>{}},
      'getLyrics' => {'lyrics': const <String, dynamic>{}},
      'getMusicFolders' => _musicFolders(),
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
      'getPlaylists' => _playlistsJson(),
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

  void _invalidate() => _index = null;
}
