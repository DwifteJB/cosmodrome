import 'dart:async';

import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/services/local_storage_service.dart';
import 'package:cosmodrome/services/offline_cache_service.dart';
import 'package:cosmodrome/utils/logger.dart';
import 'package:http/http.dart' as http;

const _coverArtManifestKey = 'cover_art_manifest';
const _coverArtTTL = Duration(days: 1);
String? _coverArtActiveAccountId;
final _coverArtLocalUriCache = <String, _CachedCoverArtLocal>{};
final _coverArtManifestByAccount = <String, Map<String, dynamic>>{};

// app wide cache for coverUrls, since they are deterministic based on token
// not good, sicne lot of redraws
final _coverArtUrlCache = <String, String>{};
final _coverArtWarmInFlight = <String, Future<void>>{};
final _coverArtInitFutureByAccount = <String, Future<void>>{};

void clearCoverArtCache() {
  _coverArtUrlCache.clear();
  _coverArtLocalUriCache.clear();
  _coverArtWarmInFlight.clear();
  _coverArtManifestByAccount.clear();
  _coverArtInitFutureByAccount.clear();
  _coverArtActiveAccountId = null;
}

class _CachedCoverArtLocal {
  final String uri;
  final int size;

  const _CachedCoverArtLocal({required this.uri, required this.size});
}

extension SubsonicBrowsingApi on Subsonic {
  String get _accountId => '${auth.username}@$baseUrl';

  /// returns a remote URL if no local cache is available, and starts warming the
  /// local cache in the background for next time. Note that the remote URL is
  /// deterministic based on token, but the password seems to make it keep
  /// refreshing, so caching is ESSENTIAL... :)

  String cachedCoverArtUrl(String id, {int size = 300}) {
    final accountId = _accountId;
    if (_coverArtActiveAccountId != accountId) {
      _coverArtUrlCache.clear();
      _coverArtLocalUriCache.clear();
      _coverArtActiveAccountId = accountId;
      _coverArtInitFutureByAccount[accountId] = initCoverArtCacheForAccount();
    }

    final local = _coverArtLocalUriCache['$accountId|$id'];
    // try get a local one that is better or the same size, or else we can get shitty looking images
    if (local != null && local.size >= size) {
      return local.uri;
    }

    final key = '$accountId|$id|$size';
    final remote = _coverArtUrlCache.putIfAbsent(
      key,
      () => coverArtUrl(id, size: size),
    );
    unawaited(_warmCoverArtCache(id, size: size));
    return remote;
  }

  // https://www.subsonic.org/pages/api.jsp#getIndexes
  /// Builds a raw remote cover-art URL without making an HTTP request.
  ///
  /// Prefer [cachedCoverArtUrl] in UI paths so offline/local URI fallbacks can
  /// be used when available.
  String coverArtUrl(String id, {int size = 300}) {
    final tok = auth.generateToken();
    final query = {
      'u': auth.username,
      't': tok.token,
      's': tok.salt,
      'v': '1.16.1',
      'c': 'cosmodrome',
      'id': id,
      'size': '$size',
    };
    return Uri.http(baseUrl, '/rest/getCoverArt', query).toString();
  }

  // creates a new empty playlist and returns the new playlist id.
  Future<String?> createNewPlaylist(String name) async {
    try {
      final response = await apiRequest(
        'createPlaylist',
        params: {'name': name},
      );
      final playlist = response['playlist'] as Map<String, dynamic>?;

      // created new playlist, so clear anything that gives us playlist
      clearCacheStartingWith("getPlaylists");

      return playlist?['id'] as String?;
    } catch (e) {
      loggerPrint('Error creating playlist: $e');
      return null;
    }
  }

  // https://www.subsonic.org/pages/api.jsp#getAlbum
  Future<AlbumDetail?> getAlbum(String id) async {
    try {
      final response = await apiRequest('getAlbum', params: {'id': id});
      final albumJson = response['album'] as Map<String, dynamic>?;
      if (albumJson == null) return null;
      final album = AlbumDetail.fromJson(albumJson);
      await _saveAlbumDetailCache(album);
      return album;
    } catch (e) {
      loggerPrint('Error fetching album $id: $e');
      return _loadAlbumDetailFallback(id);
    }
  }

  // https://www.subsonic.org/pages/api.jsp#getAlbumList2
  Future<List<Album>> getAlbumList2(
    String type, {
    int size = 20,
    int offset = 0,
  }) async {
    try {
      final response = await apiRequest(
        'getAlbumList2',
        params: {'type': type, 'size': '$size', 'offset': '$offset'},
      );
      final listJson = response['albumList2'] as Map<String, dynamic>?;
      if (listJson == null) return [];
      final albumsJson = listJson['album'] as List<dynamic>? ?? [];
      return albumsJson
          .map((j) => Album.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      loggerPrint('Error fetching album list ($type): $e');
      return [];
    }
  }

  // https://www.subsonic.org/pages/api.jsp#getArtists
  Future<List<Artist>> getArtists() async {
    try {
      final response = await apiRequest('getArtists');
      final indexes = response['artists']?['index'] as List<dynamic>? ?? [];
      return indexes.expand((index) {
        final artists =
            (index as Map<String, dynamic>)['artist'] as List<dynamic>? ?? [];
        return artists.map((a) => Artist.fromJson(a as Map<String, dynamic>));
      }).toList();
    } catch (e) {
      loggerPrint('Error fetching artists: $e');
      return [];
    }
  }

  /// Gets the list of artists, albums, and songs in the music library.
  /// Can be filtered by music folder and/or by modification date.
  /// [ifModifiedSince] = unix timestamp in ms
  /// [musicFolderId] = id of music folder to filter by (see getMusicFolders)
  Future<List<Index>> getIndexes({
    String musicFolderId = '',
    String ifModifiedSince = '',
  }) async {
    try {
      final response = await apiRequest(
        "getIndexes",
        params: {
          if (musicFolderId.isNotEmpty) 'musicFolderId': musicFolderId,
          if (ifModifiedSince.isNotEmpty) 'ifModifiedSince': ifModifiedSince,
        },
      );

      // get res
      loggerPrint("response: $response");

      final indexesJson =
          (response['indexes'] as Map<String, dynamic>)['index']
              as List<dynamic>;
      return indexesJson
          .map((json) => Index.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      loggerPrint("Error fetching indexes: $e");
      return [];
    }
  }

  // https://www.subsonic.org/pages/inc/api/examples/musicFolders_example_1.xml
  Future<List<MusicFolder>> getMusicFolders() async {
    try {
      final response = await apiRequest("getMusicFolders");

      final musicFoldersJson =
          response['musicFolders']['musicFolder'] as List<dynamic>;

      // log entire response
      loggerPrint("getMusicFolders response: $response");
      return musicFoldersJson
          .map((json) => MusicFolder.fromJson(json))
          .toList();
    } catch (e) {
      loggerPrint("Error fetching music folders: $e");
      return [];
    }
  }

  // https://www.subsonic.org/pages/api.jsp#getPlaylist
  Future<PlaylistDetail?> getPlaylist(String id) async {
    try {
      final response = await apiRequest('getPlaylist', params: {'id': id});
      final json = response['playlist'] as Map<String, dynamic>?;
      if (json == null) return null;
      final playlist = PlaylistDetail.fromJson(json);
      await _savePlaylistDetailCache(playlist);
      return playlist;
    } catch (e) {
      loggerPrint('Error fetching playlist $id: $e');
      return _loadPlaylistDetailFallback(id);
    }
  }

  // https://www.subsonic.org/pages/api.jsp#getPlaylists
  Future<List<Playlist>> getPlaylists() async {
    try {
      final response = await apiRequest('getPlaylists');
      final raw = response['playlists']?['playlist'];
      if (raw == null) return [];
      // Some servers return a single object instead of an array when there's 1
      final list = raw is List ? raw : [raw];
      return list
          .map((p) => Playlist.fromJson(p as Map<String, dynamic>))
          .toList();
    } catch (e) {
      loggerPrint('Error fetching playlists: $e');
      return [];
    }
  }

  // https://www.subsonic.org/pages/api.jsp#getRandomSongs
  Future<List<Song>> getRandomSongs({int count = 10}) async {
    try {
      final root = await apiRequest(
        'getRandomSongs',
        params: {'size': '$count'},
      );
      final songs = root['randomSongs']?['song'] as List<dynamic>? ?? [];
      return songs
          .map((s) => Song.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      loggerPrint('Error fetching random songs: $e');
      return [];
    }
  }

  Future<void> initCoverArtCacheForAccount() async {
    final accountId = _accountId;
    _coverArtActiveAccountId = accountId;
    await LocalStorageService.ensureDirs(accountId);

    final raw = await LocalStorageService.readJsonMeta(
      accountId,
      _coverArtManifestKey,
    );
    final existing =
        (raw?['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final now = DateTime.now();
    final next = <String, dynamic>{};

    for (final entry in existing.entries) {
      final item = entry.value as Map<String, dynamic>?;
      if (item == null) continue;
      final ref = item['ref'] as String?;
      final fetchedAt = DateTime.tryParse(item['fetchedAt'] as String? ?? '');
      final cachedSize = (item['size'] as num?)?.toInt() ?? 0;
      if (ref == null || fetchedAt == null) continue;

      if (now.difference(fetchedAt) > _coverArtTTL) {
        await LocalStorageService.deleteCoverImage(ref);
        continue;
      }

      if (!await LocalStorageService.coverImageExists(ref)) {
        continue;
      }

      final uri = await LocalStorageService.coverImageUriForRef(ref);
      if (uri != null) {
        _coverArtLocalUriCache['$accountId|${entry.key}'] =
            _CachedCoverArtLocal(uri: uri.toString(), size: cachedSize);
        next[entry.key] = {
          'ref': ref,
          'fetchedAt': fetchedAt.toIso8601String(),
          'size': cachedSize,
        };
      }
    }

    _coverArtManifestByAccount[accountId] = next;
    await LocalStorageService.writeJsonMeta(accountId, _coverArtManifestKey, {
      'data': next,
    });
  }

  // replaces all songs with a given list
  Future<void> replacePlaylistSongs(
    String playlistId,
    List<String> songIds,
  ) async {
    try {
      await multiParamRequest(
        'createPlaylist',
        params: {'playlistId': playlistId, 'songId': songIds},
      );
      clearCacheStartingWith("getPlaylist?id=$playlistId");
      clearCacheStartingWith("getPlaylists");
    } catch (e) {
      loggerPrint('Error replacing playlist songs $playlistId: $e');
      rethrow;
    }
  }

  // https://www.subsonic.org/pages/api.jsp#search3
  Future<List<Song>> searchThreeSongs({
    String q = '',
    int count = 200,
    int offset = 0,
  }) async {
    try {
      final response = await apiRequest(
        'search3',
        params: {
          'query': q,
          'songCount': '$count',
          'songOffset': '$offset',
          'artistCount': '0',
          'albumCount': '0',
        },
      );
      final songs = response['searchResult3']?['song'] as List<dynamic>? ?? [];
      return songs
          .map((s) => Song.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      loggerPrint('Error searching songs: $e');
      return [];
    }
  }

  // https://www.subsonic.org/pages/api.jsp#star
  Future<bool> starAlbum(String albumId) async {
    try {
      await apiRequest('star', params: {'albumId': albumId});

      // since we starred, we gotta clear cache cuz everything will be stale now
      clearCacheStartingWith("getAlbum");
      clearCacheStartingWith("getAlbumList2");

      return true;
    } catch (e) {
      loggerPrint('Error starring album $albumId: $e');
      return false;
    }
  }

  Future<bool> starSong(String id) async {
    try {
      await apiRequest('star', params: {'id': id});
      clearCacheStartingWith("getAlbum");
      return true;
    } catch (e) {
      loggerPrint('Error starring song $id: $e');
      return false;
    }
  }

  // https://www.subsonic.org/pages/api.jsp#unstar
  Future<bool> unstarAlbum(String albumId) async {
    try {
      await apiRequest('unstar', params: {'albumId': albumId});

      // since we starred, we gotta clear cache cuz everything will be stale now
      clearCacheStartingWith("getAlbum");
      clearCacheStartingWith("getAlbumList2");
      return true;
    } catch (e) {
      loggerPrint('Error unstarring album $albumId: $e');
      return false;
    }
  }

  Future<bool> unstarSong(String id) async {
    try {
      await apiRequest('unstar', params: {'id': id});
      clearCacheStartingWith("getAlbum");
      return true;
    } catch (e) {
      loggerPrint('Error unstarring song $id: $e');
      return false;
    }
  }

  // https://www.subsonic.org/pages/api.jsp#updatePlaylist
  Future<void> updatePlaylist({
    required String playlistId,
    String? name,
    String? songIdToAdd,
    int? songIndexToRemove,
  }) async {
    try {
      await apiRequest(
        'updatePlaylist',
        params: {
          'playlistId': playlistId,
          'name': ?name,
          'songIdToAdd': ?songIdToAdd,
          if (songIndexToRemove != null)
            'songIndexToRemove': '$songIndexToRemove',
        },
      );
      clearCacheStartingWith("getPlaylist?id=$playlistId");
      clearCacheStartingWith("getPlaylists");
    } catch (e) {
      loggerPrint('Error updating playlist $playlistId: $e');
      rethrow;
    }
  }

  String _extensionForContentType(String? contentType) {
    final normalized = (contentType ?? '').toLowerCase();
    if (normalized.contains('png')) return 'png';
    if (normalized.contains('webp')) return 'webp';
    if (normalized.contains('gif')) return 'gif';
    return 'jpg';
  }

  Future<AlbumDetail?> _loadAlbumDetailFallback(String id) async {
    try {
      return await offlineCacheService.loadAlbumDetail(_accountId, id);
    } catch (_) {
      return null;
    }
  }

  Future<PlaylistDetail?> _loadPlaylistDetailFallback(String id) async {
    try {
      return await offlineCacheService.loadPlaylistDetail(_accountId, id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveAlbumDetailCache(AlbumDetail album) async {
    try {
      await offlineCacheService.saveAlbumDetail(_accountId, album);
    } catch (_) {}
  }

  Future<void> _savePlaylistDetailCache(PlaylistDetail playlist) async {
    try {
      await offlineCacheService.savePlaylistDetail(_accountId, playlist);
    } catch (_) {}
  }

  Future<void> _warmCoverArtCache(String id, {int size = 300}) async {
    final accountId = _accountId;
    final inFlightKey = '$accountId|$id|$size';
    if (_coverArtWarmInFlight.containsKey(inFlightKey)) return;

    _coverArtWarmInFlight[inFlightKey] = Future<void>(() async {
      try {
        // wait for any in-flight init to complete
        // prevents duplicate inits and a ton of un-needed downloads to system
        final initFuture = _coverArtInitFutureByAccount[accountId];
        if (initFuture != null) await initFuture;

        // read manifest only after init is done so we see on-disk entries.
        final manifest = _coverArtManifestByAccount.putIfAbsent(
          accountId,
          () => <String, dynamic>{},
        );
        final prior = manifest[id] as Map<String, dynamic>?;
        final priorRef = prior?['ref'] as String?;
        final priorSize = (prior?['size'] as num?)?.toInt() ?? 0;

        if (priorRef != null && priorSize >= size) {
          return;
        }

        await LocalStorageService.ensureDirs(accountId);
        final response = await http
            .get(Uri.parse(coverArtUrl(id, size: size)))
            .timeout(const Duration(seconds: 6));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) return;

        final extension = _extensionForContentType(
          response.headers['content-type'],
        );
        final ref = LocalStorageService.coverImagePath(
          accountId,
          id,
          extension,
        );

        await LocalStorageService.writeCoverImageBytes(ref, response.bodyBytes);
        final uri = await LocalStorageService.coverImageUriForRef(ref);
        if (uri == null) return;

        _coverArtLocalUriCache['$accountId|$id'] = _CachedCoverArtLocal(
          uri: uri.toString(),
          size: size,
        );

        final currentManifest = _coverArtManifestByAccount.putIfAbsent(
          accountId,
          () => <String, dynamic>{},
        );
        currentManifest[id] = {
          'ref': ref,
          'fetchedAt': DateTime.now().toIso8601String(),
          'size': size,
        };
        if (priorRef != null && priorRef != ref) {
          await LocalStorageService.deleteCoverImage(priorRef);
        }

        await LocalStorageService.writeJsonMeta(
          accountId,
          _coverArtManifestKey,
          {'data': currentManifest},
        );
      } catch (_) {}
    });

    await _coverArtWarmInFlight[inFlightKey];
    _coverArtWarmInFlight.remove(inFlightKey);
  }
}
