// handles the entirety of carplay / android auto integration
// ui is similar, however due to constraints of the platform, the implementation is different

import 'dart:async';
import 'dart:math';

import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/download_provider.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/services/car/car_art.dart';
import 'package:cosmodrome/services/car/car_bridge.dart';
import 'package:cosmodrome/services/car/car_models.dart';
import 'package:cosmodrome/services/offline_cache_service.dart';
import 'package:cosmodrome/utils/format_duration.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

final carService = CarService();

class CarService {
  static const _maxDepth = 5;
  static const _maxCovers = 60;

  CarBridge? _bridge;
  late SubsonicProvider _subsonic;
  late PlayerProvider _player;
  late DownloadProvider _downloads;

  bool _connected = false;
  int _seq = 0;
  int _rootGeneration = 0;
  int _albumOffset = 0;
  String? _rootKey;
  String _playerKey = '';
  String _modesKey = '';
  Timer? _debounce;
  bool _refreshing = false;
  bool _refreshQueued = false;

  CarPage? _home;
  CarPage? _albums;
  CarPage? _playlists;
  CarPage? _search;
  CarPage? _queuePage;

  String get _accountKey =>
      '${_subsonic.activeAccount?.id}|${_subsonic.isOffline}';

  Subsonic? get _api => _subsonic.activeAccount?.subsonic;

  int get _tabDepth => _bridge!.supportsTabs ? 1 : 2;

  // setup the carplay / android auto bridge and start listening for events
  Future<void> init({
    required SubsonicProvider subsonic,
    required PlayerProvider player,
    required DownloadProvider downloads,
  }) async {
    final bridge = CarBridge.create();
    if (bridge == null) return;
    _bridge = bridge;
    _subsonic = subsonic;
    _player = player;
    _downloads = downloads;

    bridge.onConnection = _onConnection;
    bridge.onUpNext = () => _openQueue(bridge.depth + 1);
    bridge.onToggleShuffle = player.toggleShuffle;
    bridge.onToggleRepeat = player.toggleRepeat;
    subsonic.addListener(_onAccountChanged);
    player.addListener(_onPlayerChanged);

    _connected = bridge.connected;
    _syncModes();
    if (_connected || bridge.presetsRoot) await _buildRoot();
    if (!bridge.presetsRoot) _probe(bridge, 30);
  }

  Future<List<CarRow>> _albumRows(List<Album> albums, int depth) async {
    final covers = await _covers(albums.map((a) => a.coverArt));
    return [
      for (final album in albums)
        CarRow(
          title: _text(album.name),
          subtitle: album.artist,
          image: covers[album.coverArt],
          browsable: true,
          onTap: () => _openAlbum(album.id, depth),
        ),
    ];
  }

  // build the root view of the carplay / android auto interface, this is called when the account changes or the connection is established
  Future<void> _buildRoot() async {
    final bridge = _bridge!;
    final generation = ++_rootGeneration;
    _rootKey = _accountKey;
    _albumOffset = 0;
    _queuePage = null;
    if (_connected) await bridge.popToRoot();

    if (_subsonic.activeAccount == null) {
      _home = _albums = _playlists = _search = null;
      await bridge.setRoot([
        CarPage(
          id: _id('signin'),
          title: 'Cosmodrome',
          emptyText: 'Sign in on your phone to start listening',
        ),
      ]);
      return;
    }

    final icons = await Future.wait([
      CarArt.icon(Icons.home_rounded),
      CarArt.icon(Icons.album_rounded),
      CarArt.icon(Icons.queue_music_rounded),
      CarArt.icon(Icons.search_rounded),
    ]);
    final homeSections = await _homeSections();
    if (generation != _rootGeneration) return;

    if (!bridge.supportsTabs) {
      _albums = _playlists = _search = null;
      final home = _home = CarPage(
        id: _id('home'),
        title: 'Cosmodrome',
        sections: homeSections,
      );
      await bridge.setRoot([home]);
      return;
    }

    // main UI for carplay / android auto, this is a tabbed interface with home, albums, playlists, and search
    final home = _home = CarPage(
      id: _id('home'),
      title: 'Home',
      symbol: 'house.fill',
      tabIcon: icons[0],
      sections: homeSections,
    );
    final albums = _albums = CarPage(
      id: _id('albums'),
      title: 'Albums',
      symbol: 'square.stack.fill',
      tabIcon: icons[1],
    );
    final playlists = _playlists = CarPage(
      id: _id('playlists'),
      title: 'Playlists',
      symbol: 'music.note.list',
      tabIcon: icons[2],
    );
    final search = _search = CarPage(
      id: _id('search'),
      title: 'Search',
      symbol: 'magnifyingglass',
      tabIcon: icons[3],
    );

    // set it up, yuh yuh
    await bridge.setRoot([home, albums, playlists, search]);
    if (generation != _rootGeneration) return;
    _run(_loadAlbums);
    _run(_loadPlaylists);
    _run(_loadSearch);
  }

  // cover cache via bridge
  Future<Map<String, String>> _covers(Iterable<String?> ids) async {
    final unique = ids
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .take(_maxCovers)
        .toList();
    final paths = await Future.wait(
      unique.map((id) => CarArt.cover(_coverUrl(id))),
    );
    return {
      for (var i = 0; i < unique.length; i++)
        if (paths[i] != null) unique[i]: paths[i]!,
    };
  }

  // get a url for the cover art, if the api is null or the coverArt is null or empty, return null
  String? _coverUrl(String? coverArt) {
    final api = _api;
    if (api == null || coverArt == null || coverArt.isEmpty) return null;
    return api.cachedCoverArtUrl(coverArt, size: 300);
  }

  // ui / data for home sections
  Future<List<CarSection>> _homeSections() async {
    final song = _player.currentSong;
    final nowPlaying = <CarRow>[];
    if (song != null) {
      nowPlaying.add(
        CarRow(
          title: _text(song.title),
          subtitle: song.artist,
          image: await CarArt.cover(_coverUrl(song.coverArt)),
          playing: _player.isPlaying,
          browsable: true,
          onTap: () => _openNowPlaying(1),
        ),
      );
    }

    return [
      if (nowPlaying.isNotEmpty)
        CarSection(header: 'Now Playing', rows: nowPlaying),
      if (!_bridge!.supportsTabs)
        CarSection(
          header: 'Browse',
          rows: [
            await _iconRow(
              Icons.album_rounded,
              'Albums',
              browsable: true,
              onTap: () => _openSection('Albums'),
            ),
            await _iconRow(
              Icons.queue_music_rounded,
              'Playlists',
              browsable: true,
              onTap: () => _openSection('Playlists'),
            ),
            await _iconRow(
              Icons.person_rounded,
              'Artists',
              browsable: true,
              onTap: _openArtists,
            ),
            await _iconRow(
              Icons.search_rounded,
              'Recent Searches',
              browsable: true,
              onTap: () => _openSection('Recent Searches'),
            ),
          ],
        ),
      CarSection(
        header: 'Library',
        rows: [
          await _iconRow(
            Icons.shuffle_rounded,
            'Shuffle Library',
            onTap: _shuffleLibrary,
          ),
          await _listRow(
            Icons.new_releases_rounded,
            'Recently Added',
            'newest',
          ),
          await _listRow(Icons.history_rounded, 'Recently Played', 'recent'),
          await _listRow(Icons.trending_up_rounded, 'Most Played', 'frequent'),
          await _listRow(Icons.star_rounded, 'Starred', 'starred'),
          await _listRow(Icons.casino_rounded, 'Random Albums', 'random'),
          await _iconRow(
            Icons.download_done_rounded,
            'Downloads',
            browsable: true,
            onTap: _openDownloads,
          ),
        ],
      ),
    ];
  }

  // useful reusable icon row
  Future<CarRow> _iconRow(
    IconData icon,
    String title, {
    String? subtitle,
    bool browsable = false,
    Future<void> Function()? onTap,
  }) async => CarRow(
    title: title,
    subtitle: subtitle,
    image: await CarArt.icon(icon),
    icon: true,
    browsable: browsable,
    onTap: onTap,
  );

  String _id(String name) => '$name-${_seq++}';

  Future<CarRow> _listRow(IconData icon, String title, String type) => _iconRow(
    icon,
    title,
    browsable: true,
    onTap: () => _openAlbumList(title, type),
  );

  Future<void> _loadAlbums() async {
    final page = _albums;
    final api = _api;
    if (page == null || api == null) return;
    final size = _bridge!.rowLimit - 2;
    final offset = _albumOffset;
    final albums = await api.getAlbumList2(
      'alphabeticalByName',
      size: size,
      offset: offset,
    );
    final rows = await _albumRows(albums, _tabDepth);
    if (!identical(page, _albums) || offset != _albumOffset) return;
    page.sections = [
      CarSection(
        rows: [
          if (offset > 0)
            await _iconRow(
              Icons.arrow_upward_rounded,
              'Previous Albums',
              onTap: () => _pageAlbums(-size),
            ),
          ...rows,
          if (albums.length >= size)
            await _iconRow(
              Icons.arrow_downward_rounded,
              'More Albums',
              onTap: () => _pageAlbums(size),
            ),
          if (rows.isEmpty) const CarRow(title: 'No albums found'),
        ],
      ),
    ];
    await _bridge!.update(page);
  }

  Future<void> _loadPlaylists() async {
    final page = _playlists;
    final api = _api;
    if (page == null || api == null) return;
    final playlists = await api.getPlaylists();
    final covers = await _covers(playlists.map((p) => p.coverArt));
    if (!identical(page, _playlists)) return;
    page.sections = [
      CarSection(
        rows: [
          for (final playlist in playlists)
            CarRow(
              title: _text(playlist.name),
              subtitle: _songCount(playlist.songCount),
              image: covers[playlist.coverArt],
              browsable: true,
              onTap: () => _openPlaylist(playlist.id, _tabDepth),
            ),
          if (playlists.isEmpty) const CarRow(title: 'No playlists found'),
        ],
      ),
    ];
    await _bridge!.update(page);
  }

  Future<void> _loadSearch() async {
    final page = _search;
    final account = _subsonic.activeAccount;
    if (page == null || account == null) return;
    final recents =
        (await offlineCacheService.loadRecentSearches(account.id) ??
                const <RecentSearch>[])
            .take(20)
            .toList();
    final covers = await _covers(recents.map((r) => r.artId));
    if (!identical(page, _search)) return;
    page.sections = [
      if (_bridge!.supportsTabs)
        CarSection(
          header: 'Browse',
          rows: [
            await _iconRow(
              Icons.person_rounded,
              'Artists',
              browsable: true,
              onTap: _openArtists,
            ),
          ],
        ),
      CarSection(
        header: 'Recent Searches',
        rows: [
          for (final recent in recents)
            CarRow(
              title: _text(recent.title),
              subtitle: recent.subtitle,
              image: covers[recent.artId],
              browsable: recent.type != RecentSearchEnum.song,
              onTap: () => _openRecent(recent),
            ),
          if (recents.isEmpty)
            const CarRow(
              title: 'No recent searches',
              subtitle: 'Search on your phone to find it here',
            ),
        ],
      ),
    ];
    await _bridge!.update(page);
  }

  // for small text / msgs
  CarSection _note(String text) => CarSection(rows: [CarRow(title: text)]);

  void _onAccountChanged() {
    final bridge = _bridge;
    if (bridge == null || _accountKey == _rootKey) return;
    if (_connected || bridge.presetsRoot) _run(_buildRoot);
  }

  void _onConnection(bool connected) {
    final wasConnected = _connected;
    _connected = connected;
    if (!connected) {
      _queuePage = null;
      return;
    }
    if (!wasConnected) _run(_buildRoot);
  }

  void _onPlayerChanged() {
    if (!_connected) return;
    final key =
        '${_player.currentSong?.id}|${_player.isPlaying}|${_player.shuffle}|'
        '${_player.repeatMode}|${_player.queueVersion}';
    if (key != _playerKey) {
      _playerKey = key;
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(milliseconds: 150),
        () => _run(_refreshPlayerViews),
      );
    }
    _syncModes();
  }

  Future<void> _openAlbum(String id, int depth) async {
    final album = await _api?.getAlbum(id);
    if (album == null) return;
    await _pushTracks(
      title: album.name,
      header: album.artist,
      songs: album.songs,
      depth: depth,
    );
  }

  Future<void> _openAlbumList(String title, String type) async {
    final api = _api;
    if (api == null) return;
    final albums = await api.getAlbumList2(
      type,
      size: 50,
      forceRefresh: type == 'random',
    );
    await _push(
      CarPage(
        id: _id('list'),
        title: title,
        emptyText: 'No albums found',
        sections: [CarSection(rows: await _albumRows(albums, 2))],
      ),
      1,
    );
  }

  Future<void> _openArtist(String id, String name, int depth) async {
    final api = _api;
    if (api == null) return;
    final albums = await api.getArtist(id);
    await _push(
      CarPage(
        id: _id('artist'),
        title: _text(name),
        emptyText: 'No albums found',
        sections: [CarSection(rows: await _albumRows(albums, depth + 1))],
      ),
      depth,
    );
  }

  Future<void> _openArtists() async {
    final api = _api;
    if (api == null) return;
    final artists = await api.getArtists();
    final limit = _bridge!.rowLimit;
    if (artists.length <= limit) {
      await _pushArtists('Artists', artists, 1);
      return;
    }

    final groups = <String, List<Artist>>{};
    for (final artist in artists) {
      final initial = artist.name.trim().isEmpty
          ? '#'
          : artist.name.trim()[0].toUpperCase();
      final letter = RegExp(r'[A-Z]').hasMatch(initial) ? initial : '#';
      groups.putIfAbsent(letter, () => []).add(artist);
    }
    final letters = groups.keys.toList()..sort();
    await _push(
      CarPage(
        id: _id('letters'),
        title: 'Artists',
        sections: [
          CarSection(
            rows: [
              for (final letter in letters)
                CarRow(
                  title: letter,
                  subtitle: '${groups[letter]!.length} artists',
                  browsable: true,
                  onTap: () => _pushArtists(letter, groups[letter]!, 2),
                ),
            ],
          ),
        ],
      ),
      1,
    );
  }

  Future<void> _openDownloads() async {
    final songs = _downloads.completedDownloads
        .map((d) => d.songMeta)
        .whereType<Song>()
        .toList();
    await _pushTracks(
      title: 'Downloads',
      header: 'On this device',
      songs: songs,
      depth: 1,
      perSongArt: true,
    );
  }

  // needs the bridge as there are custom UI for
  // auto or carplay that we cannot replicate in flutter_carplay
  Future<void> _openNowPlaying(int depth) async {
    final bridge = _bridge!;
    if (_player.currentSong == null) return;
    if (depth >= _maxDepth) await bridge.popToRoot();
    await bridge.showNowPlaying();
  }

  Future<void> _openPlaylist(String id, int depth) async {
    final playlist = await _api?.getPlaylist(id);
    if (playlist == null) return;
    await _pushTracks(
      title: playlist.name,
      header: 'Playlist',
      songs: playlist.songs,
      depth: depth,
      perSongArt: true,
    );
  }

  Future<void> _openQueue(int depth) async {
    final page = CarPage(
      id: _id('queue'),
      title: 'Queue',
      sections: _queueSections(),
    );
    if (await _push(page, depth)) _queuePage = page;
  }

  Future<void> _openRecent(RecentSearch recent) async {
    switch (recent.type) {
      case RecentSearchEnum.album:
        await _openAlbum(recent.id, _tabDepth);
      case RecentSearchEnum.artist:
        await _openArtist(recent.id, recent.title, _tabDepth);
      case RecentSearchEnum.playlist:
        await _openPlaylist(recent.id, _tabDepth);
      case RecentSearchEnum.song:
        final song = await _api?.getSong(recent.id);
        if (song == null) return;
        unawaited(_player.playNow(song));
        await _openNowPlaying(_tabDepth);
    }
  }

  Future<void> _openSection(String title) async {
    final page = CarPage(id: _id('section'), title: title);
    switch (title) {
      case 'Albums':
        _albumOffset = 0;
        _albums = page;
        await _loadAlbums();
      case 'Playlists':
        _playlists = page;
        await _loadPlaylists();
      default:
        _search = page;
        await _loadSearch();
    }
    await _push(page, 1);
  }

  Future<void> _pageAlbums(int delta) async {
    _albumOffset = max(0, _albumOffset + delta);
    await _loadAlbums();
  }

  Future<void> _play(
    List<Song> songs,
    int depth, {
    Song? from,
    bool shuffle = false,
  }) async {
    final playable = _player.playableSongs(songs);
    if (playable.isEmpty) return;
    final index = from == null
        ? 0
        : playable.indexWhere((song) => song.id == from.id);
    if (index < 0) return;
    unawaited(_player.playAlbum(playable, shuffle: shuffle, startIndex: index));
    await _openNowPlaying(depth);
  }

  void _probe(CarBridge bridge, int attempts) {
    if (_connected || attempts <= 0) return;
    Timer(const Duration(seconds: 1), () async {
      if (_connected) return;
      if (await bridge.probe()) {
        _onConnection(true);
      } else {
        _probe(bridge, attempts - 1);
      }
    });
  }

  Future<bool> _push(CarPage page, int depth) async {
    if (depth >= _maxDepth) return false;
    return _bridge!.push(page);
  }

  Future<void> _pushArtists(String title, List<Artist> all, int depth) async {
    final artists = all.take(_bridge!.rowLimit).toList();
    final covers = await _covers(artists.map((a) => a.coverArt));
    await _push(
      CarPage(
        id: _id('artists'),
        title: title,
        emptyText: 'No artists found',
        sections: [
          CarSection(
            rows: [
              for (final artist in artists)
                CarRow(
                  title: _text(artist.name),
                  subtitle: '${artist.albumCount} albums',
                  image: covers[artist.coverArt],
                  browsable: true,
                  onTap: () => _openArtist(artist.id, artist.name, depth + 1),
                ),
            ],
          ),
        ],
      ),
      depth,
    );
  }

  Future<void> _pushTracks({
    required String title,
    required String header,
    required List<Song> songs,
    required int depth,
    bool perSongArt = false,
  }) async {
    final next = depth + 1;
    final covers = perSongArt
        ? await _covers(songs.map((s) => s.coverArt))
        : const <String, String>{};
    await _push(
      CarPage(
        id: _id('tracks'),
        title: _text(title),
        emptyText: 'No songs found',
        sections: songs.isEmpty
            ? const []
            : [
                CarSection(
                  header: _text(header),
                  rows: [
                    await _iconRow(
                      Icons.play_arrow_rounded,
                      'Play',
                      onTap: () => _play(songs, next),
                    ),
                    await _iconRow(
                      Icons.shuffle_rounded,
                      'Shuffle',
                      onTap: () => _play(songs, next, shuffle: true),
                    ),
                  ],
                ),
                CarSection(
                  header: _songCount(songs.length),
                  rows: [
                    for (final song in songs)
                      CarRow(
                        title: _text(song.title),
                        subtitle: [
                          song.artist,
                          if (song.duration != null)
                            formatTrackDuration(song.duration!),
                        ].whereType<String>().join(' · '),
                        image: covers[song.coverArt],
                        onTap: _player.isSongPlayable(song)
                            ? () => _play(songs, next, from: song)
                            : null,
                      ),
                  ],
                ),
              ],
      ),
      depth,
    );
  }

  // queue is a little weird
  List<CarSection> _queueSections() {
    final queue = _player.visibleQueue;
    final start = _player.visibleQueueStartIndex;
    if (queue.isEmpty) return [_note('The queue is empty')];
    return [
      CarSection(
        rows: [
          for (var i = 0; i < queue.length; i++)
            CarRow(
              title: _text(queue[i].title),
              subtitle: queue[i].artist,
              playing: i == 0,
              onTap: () async => unawaited(_player.skipToQueueIndex(start + i)),
            ),
        ],
      ),
    ];
  }

  Future<void> _refreshPlayerViews() async {
    final bridge = _bridge;
    if (bridge == null || !_connected) return;
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    try {
      final home = _home;
      if (home != null) {
        home.sections = await _homeSections();
        await bridge.update(home);
      }

      final queue = _queuePage;
      if (queue != null && bridge.isOpen(queue)) {
        queue.sections = _queueSections();
        await bridge.update(queue);
      } else {
        _queuePage = null;
      }
    } finally {
      _refreshing = false;
      if (_refreshQueued) {
        _refreshQueued = false;
        _run(_refreshPlayerViews);
      }
    }
  }

  // helper to run a task and ignore errors, used for background tasks that don't need to be awaited
  void _run(Future<void> Function() task) =>
      unawaited(task().catchError((Object _) {}));

  // shuffle properly
  Future<void> _shuffleLibrary() async {
    final api = _api;
    if (api == null) return;
    final songs = _subsonic.isOffline
        ? _downloads.completedDownloads
              .map((d) => d.songMeta)
              .whereType<Song>()
              .toList()
        : await api.getRandomSongs(count: 50);
    await _play(songs, 1, shuffle: true);
  }

  String _songCount(int count) => count == 1 ? '1 song' : '$count songs';

  // ensure the shuffle and repeat modes are synced with the carplay / android auto interface, this is called whenever the player state changes
  void _syncModes() {
    final repeat = switch (_player.repeatMode) {
      LoopMode.off => 'off',
      LoopMode.one => 'one',
      LoopMode.all => 'all',
    };
    final key = '${_player.shuffle}|$repeat';
    if (key == _modesKey) return;
    _modesKey = key;
    unawaited(_bridge!.setModes(shuffle: _player.shuffle, repeat: repeat));
  }

  String _text(String value) => value.trim().isEmpty ? 'Unknown' : value;
}
