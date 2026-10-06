import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/download_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/services/local_storage_service.dart';
import 'package:cosmodrome/services/play_history_service.dart';
import 'package:cosmodrome/utils/cover_art/cover_art_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:palette_generator/palette_generator.dart';

class PlayerProvider extends ChangeNotifier {
  static final Map<LoopMode, LoopMode> _nextRepeatMode = {
    LoopMode.off: LoopMode.one,
    LoopMode.one: LoopMode.all,
    LoopMode.all: LoopMode.off,
  };

  final AudioPlayer _player;
  static final bool _usesMpv =
      !kIsWeb &&
      (Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isLinux ||
          Platform.isWindows);

  List<Song> _songs = [];
  List<Song>? _unshuffled;
  final Set<String> _playedSongIds = <String>{};
  bool _loaded = false;
  int _editing = 0;
  int _switchGen = 0;
  bool _switching = false;
  bool _fetchingRandom = false;

  int _currentIndex = -1;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  SubsonicProvider? _subsonicProvider;
  bool _shuffle = false;
  LoopMode _repeatMode = LoopMode.off;
  double _volume = 1.0;
  int _queueVersion = 0;

  DownloadProvider? _downloadProvider;

  String? _cachedCoverArtUrl;
  String? _cachedSongId;
  final Set<Uri> _ephemeralCachedUris = <Uri>{};

  bool _isFullscreenOpen = false;
  Color? _accentColor;
  Color? _prevAccentColor;
  final Map<String, Color?> _accentCache = {};

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<int?>? _indexSub;

  PlayerProvider({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _positionSub = _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    _durationSub = _player.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });
    _stateSub = _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed &&
          !_player.hasNext) {
        unawaited(skipNext());
      }
      notifyListeners();
    });
    _indexSub = _player.currentIndexStream.listen((index) {
      if (_switching || !_loaded) return;
      if (index == null || index == _currentIndex) return;
      if (index < 0 || index >= _songs.length) return;
      _currentIndex = index;
      if (_editing == 0) _onCurrentIndexChanged();
      notifyListeners();
    });
  }

  Color? get accentColor => _accentColor;
  String? get currentCoverArtUrl => _cachedCoverArtUrl;
  int get currentIndex => _currentIndex;
  Song? get currentSong => _currentIndex >= 0 && _currentIndex < _songs.length
      ? _songs[_currentIndex]
      : null;

  Duration get duration => _duration;

  bool get hasCurrentSong => currentSong != null;

  bool get isFullscreenOpen => _isFullscreenOpen;

  bool get isPlaying => _isPlaying;
  bool get isSwitching => _switching;

  Duration get position => _position;
  Color? get prevAccentColor => _prevAccentColor;
  List<Song> get queue => List.unmodifiable(_songs);
  int get queueVersion => _queueVersion;
  bool get repeat => _repeatMode != LoopMode.off;
  LoopMode get repeatMode => _repeatMode;
  bool get shuffle => _shuffle;
  List<Song> get visibleQueue {
    final start = visibleQueueStartIndex;
    if (start >= _songs.length) return const <Song>[];
    return List.unmodifiable(_songs.sublist(start));
  }

  int get visibleQueueStartIndex => _currentIndex < 0 ? 0 : _currentIndex;
  double get volume => _volume;

  Future<void> addBulkToQueue(List<Song> songs) async {
    final playable = playableSongs(songs);
    if (playable.isEmpty) return;
    _songs.addAll(playable);
    _unshuffled?.addAll(playable);
    _queueVersion++;
    notifyListeners();
    if (!_loaded || _subsonicProvider == null) return;
    await _edit(() async {
      for (final song in playable) {
        await _player.addAudioSource(await _buildSource(song));
      }
    });
  }

  Future<void> addToQueue(Song song) => addBulkToQueue([song]);

  void closeFullscreen() {
    _isFullscreenOpen = false;
    notifyListeners();
  }

  String? coverArtUrlForSong(Song song) {
    if (song.coverArt == null || _subsonicProvider == null) return null;
    try {
      return _subsonicProvider!.subsonic.cachedCoverArtUrl(
        song.coverArt!,
        size: 300,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    unawaited(_clearEphemeralUris());
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _indexSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  bool isSongPlayable(Song song) {
    if (!(_subsonicProvider?.isOffline ?? false)) return true;
    return _downloadProvider?.isSongDownloaded(song.id) ?? false;
  }

  void openFullscreen() {
    _isFullscreenOpen = true;
    notifyListeners();
  }

  List<Song> playableSongs(Iterable<Song> songs) =>
      songs.where(isSongPlayable).toList();

  Future<void> playAlbum(
    List<Song> songs, {
    bool shuffle = false,
    int startIndex = 0,
  }) async {
    final playable = playableSongs(songs);
    if (playable.isEmpty) return;
    _shuffle = shuffle;
    if (shuffle) {
      _unshuffled = List.of(playable);
      final first = playable.length > 1 ? Random().nextInt(playable.length) : 0;
      _songs = _shuffledAfter(playable, playable[first]);
      _currentIndex = 0;
    } else {
      _unshuffled = null;
      _songs = List.of(playable);
      _currentIndex = startIndex.clamp(0, _songs.length - 1);
    }
    _playedSongIds
      ..clear()
      ..add(_songs[_currentIndex].id);
    _queueVersion++;
    _updateCoverArtCache();
    notifyListeners();
    await _loadQueue(play: true);
  }

  Future<void> playNow(Song song) async {
    if (!isSongPlayable(song)) return;
    final current = currentSong;
    if (!_loaded || current == null) {
      final pos = _currentIndex.clamp(0, _songs.length);
      _songs.insert(pos, song);
      _unshuffled?.insert(_unshuffled!.length, song);
      _currentIndex = pos;
      _playedSongIds.add(song.id);
      _queueVersion++;
      _updateCoverArtCache();
      notifyListeners();
      await _loadQueue(play: true);
      return;
    }

    if (_switching && identical(current, song)) return;
    final pos = _indexOfIdentical(_songs, current);
    if (pos < 0) return;
    final audio = await _buildSource(song);
    _songs.insert(pos, song);
    if (_unshuffled case final unshuffled?) {
      final at = _indexOfIdentical(unshuffled, current);
      unshuffled.insert(at < 0 ? unshuffled.length : at, song);
    }
    _queueVersion++;
    await _edit(() => _insertSource(pos, audio));
    await _jumpTo(pos);
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _songs.length) return;
    final song = _songs.removeAt(index);
    _playedSongIds.remove(song.id);
    if (_unshuffled case final unshuffled?) {
      final at = _indexOfIdentical(unshuffled, song);
      if (at >= 0) unshuffled.removeAt(at);
    }

    if (_songs.isEmpty) {
      _currentIndex = -1;
      _unshuffled = _shuffle ? [] : null;
      _isFullscreenOpen = false;
      _queueVersion++;
      _loaded = false;
      _updateCoverArtCache();
      await _player.stop();
      notifyListeners();
      return;
    }

    final removedCurrent = index == _currentIndex;
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (removedCurrent && _currentIndex >= _songs.length) {
      _currentIndex = _songs.length - 1;
    }
    _queueVersion++;
    notifyListeners();

    if (removedCurrent) {
      _updateCoverArtCache();
      await _loadQueue(play: true);
    } else if (_loaded) {
      await _edit(() => _player.removeAudioSourceAt(index));
    }
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _songs.length) return;
    if (newIndex < 0 || newIndex > _songs.length) return;
    if (oldIndex < newIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    final song = _songs.removeAt(oldIndex);
    _songs.insert(newIndex, song);
    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }
    _queueVersion++;
    if (_loaded) {
      unawaited(_edit(() => _player.moveAudioSource(oldIndex, newIndex)));
    }
    notifyListeners();
  }

  Future<void> resetQueue() async {
    await _clearEphemeralUris();
    _songs.clear();
    _unshuffled = _shuffle ? [] : null;
    _playedSongIds.clear();
    _currentIndex = -1;
    _loaded = false;
    _isFullscreenOpen = false;
    _queueVersion++;
    _updateCoverArtCache();
    notifyListeners();
    _repeatMode = LoopMode.off;
    await _player.setLoopMode(LoopMode.off);
    await _player.stop();
  }

  Future<void> seekTo(Duration pos) async {
    await _player.seek(pos);
  }

  void setDownloadProvider(DownloadProvider dp) {
    _downloadProvider = dp;
  }

  Future<void> setVolume(double v) async {
    await _player.setVolume(v);
    _volume = v;
    notifyListeners();
  }

  Future<void> skipNext() async {
    if (!_loaded || _songs.isEmpty) return;
    if (_currentIndex + 1 >= _songs.length) {
      if (_repeatMode != LoopMode.off) {
        await _jumpTo(0);
        return;
      }
      await _fetchAndAppendRandom();
    }
    if (_currentIndex + 1 < _songs.length) {
      await _jumpTo(_currentIndex + 1);
    }
  }

  Future<void> skipPrevious() async {
    // restart the current song if we're a few seconds in
    if (_position.inSeconds > 3 || _currentIndex <= 0) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }
    await _jumpTo(_currentIndex - 1);
  }

  Future<void> skipToQueueIndex(int index) async {
    if (index < 0 || index >= _songs.length) return;
    if (!_loaded) {
      _currentIndex = index;
      _updateCoverArtCache();
      notifyListeners();
      await _loadQueue(play: true);
      return;
    }
    await _jumpTo(index);
  }

  Future<void> togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> toggleRepeat() async {
    _repeatMode = _nextRepeatMode[_repeatMode] ?? LoopMode.off;
    await _player.setLoopMode(_repeatMode);
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    if (_songs.isEmpty) return;
    final current = currentSong;

    List<Song> target;
    if (!_shuffle) {
      _shuffle = true;
      _unshuffled = List.of(_songs);
      target = _shuffledAfter(_songs, current ?? _songs.first);
    } else {
      _shuffle = false;
      final present = _songs.toSet();
      final restored = [
        for (final song in _unshuffled ?? const <Song>[])
          if (present.contains(song)) song,
      ];
      final seen = restored.toSet();
      target = [
        ...restored,
        for (final song in _songs)
          if (!seen.contains(song)) song,
      ];
      _unshuffled = null;
    }

    _queueVersion++;
    notifyListeners();
    await _applyOrder(target, current);
    _updateCoverArtCache();
    notifyListeners();
  }

  void update(SubsonicProvider s) {
    _subsonicProvider = s;
    _updateCoverArtCache();
  }

  Future<void> _applyOrder(List<Song> target, Song? current) async {
    await _edit(() async {
      for (var i = 0; i < target.length; i++) {
        var j = i;
        while (j < _songs.length && !identical(_songs[j], target[i])) {
          j++;
        }
        if (j >= _songs.length || j == i) continue;
        _songs.insert(i, _songs.removeAt(j));
        if (_loaded) await _player.moveAudioSource(j, i);
      }
      _currentIndex = current == null
          ? (_songs.isEmpty ? -1 : 0)
          : _indexOfIdentical(_songs, current);
    });
  }

  Future<AudioSource> _buildSource(Song song) async {
    final subsonic = _subsonicProvider!.subsonic;
    final localPath = _downloadProvider?.getLocalPath(song.id);
    final uri = localPath != null
        ? await LocalStorageService.playableUriForSongRef(localPath)
        : null;
    final resolvedUri = uri ?? Uri.parse(subsonic.streamUrl(song.id));
    if (uri != null && uri.scheme == 'blob') {
      _ephemeralCachedUris.add(uri);
    }
    return AudioSource.uri(
      resolvedUri,
      tag: MediaItem(
        id: song.id,
        duration: Duration(seconds: song.duration ?? 0),
        title: song.title,
        album: song.album,
        artist: song.artist,
        artUri: song.coverArt != null
            ? Uri.parse(subsonic.cachedCoverArtUrl(song.coverArt!, size: 300))
            : null,
      ),
    );
  }

  Future<void> _clearEphemeralUris() async {
    if (_ephemeralCachedUris.isEmpty) return;
    final uris = List<Uri>.from(_ephemeralCachedUris);
    _ephemeralCachedUris.clear();
    for (final uri in uris) {
      await LocalStorageService.releasePlayableUri(uri);
    }
  }

  Future<void> _edit(Future<void> Function() action) async {
    final before = currentSong;
    _editing++;
    try {
      await action();
    } catch (_) {
    } finally {
      _editing--;
    }
    if (_editing == 0 && !identical(currentSong, before)) {
      _onCurrentIndexChanged();
      notifyListeners();
    }
  }

  // only called once the song is known to have cover art & a subsonic provider
  Future<void> _extractAccentColor(Song song) async {
    try {
      final coverUrl = _subsonicProvider!.subsonic.cachedCoverArtUrl(
        song.coverArt!,
        size: 300,
      );

      final generator = await PaletteGenerator.fromImageProvider(
        coverArtProvider(coverUrl),
        size: const Size(200, 200),
      );

      // Discard if a different song became current while we were waiting
      if (currentSong?.id != song.id) return;

      final raw =
          generator.vibrantColor?.color ??
          generator.lightVibrantColor?.color ??
          generator.mutedColor?.color ??
          generator.lightMutedColor?.color ??
          generator.dominantColor?.color;

      Color? color;
      if (raw != null) {
        final hsl = HSLColor.fromColor(raw);
        color = hsl.lightness < 0.25 ? hsl.withLightness(0.35).toColor() : raw;
      }

      _accentCache[song.id] = color;
      _setAccentColor(color);
    } catch (_) {}
  }

  Future<void> _fetchAndAppendRandom() async {
    final provider = _subsonicProvider;
    if (provider == null || provider.isOffline || _fetchingRandom) return;
    _fetchingRandom = true;
    try {
      final songs = await provider.subsonic.getRandomSongs(count: 10);
      await addBulkToQueue(songs);
    } catch (_) {
    } finally {
      _fetchingRandom = false;
    }
  }

  int _indexOfIdentical(List<Song> list, Song song) {
    for (var i = 0; i < list.length; i++) {
      if (identical(list[i], song)) return i;
    }
    return -1;
  }

  Future<void> _insertSource(int index, AudioSource audio) async {
    await _player.addAudioSource(audio);
    final last = _player.audioSources.length - 1;
    if (index < last) await _player.moveAudioSource(last, index);
  }

  Future<void> _loadQueue({
    bool play = false,
    Duration position = Duration.zero,
  }) async {
    if (_subsonicProvider == null) return;
    if (_songs.isEmpty || _currentIndex < 0 || _currentIndex >= _songs.length) {
      return;
    }
    await _player.pause();
    if (_usesMpv) await _warm(_songs[_currentIndex]);
    await _edit(() async {
      await _clearEphemeralUris();
      final sources = <AudioSource>[
        for (final song in _songs) await _buildSource(song),
      ];
      _loaded = true;
      await _player
          .setAudioSources(
            sources,
            initialIndex: _currentIndex,
            initialPosition: position,
          )
          .timeout(const Duration(seconds: 60));
      await _player.setLoopMode(_repeatMode);
    });
    if (play || _player.playing) {
      await _player.play();
    }
    _maybeTopUp();
    _warmNext();
  }

  void _maybeExtractAccentColor(Song song) {
    if (_accentCache.containsKey(song.id)) {
      _setAccentColor(_accentCache[song.id]);
      return;
    }
    unawaited(_extractAccentColor(song));
  }

  void _maybeTopUp() {
    if (_repeatMode == LoopMode.off && _currentIndex == _songs.length - 1) {
      unawaited(_fetchAndAppendRandom());
    }
  }

  void _onCurrentIndexChanged() {
    if (_currentIndex >= 0 && _currentIndex < _songs.length) {
      _playedSongIds.add(_songs[_currentIndex].id);
    }
    _updateCoverArtCache();
    _maybeTopUp();
    _warmNext();
  }

  void _setAccentColor(Color? color) {
    _prevAccentColor = _accentColor;
    _accentColor = color;
    notifyListeners();
  }

  List<Song> _shuffledAfter(List<Song> songs, Song first) {
    final rest = [
      for (final song in songs)
        if (!identical(song, first)) song,
    ]..shuffle(Random());
    return [first, ...rest];
  }

  Future<void> _warm(Song song) async {
    final subsonic = _subsonicProvider?.subsonic;
    if (subsonic == null) return;
    if (_downloadProvider?.getLocalPath(song.id) != null) return;
    await subsonic.warmStream(song.id);
  }

  // show the chosen song right away, then wait for the server to have it
  // before moving the player. mpv gives up on a slow open after 5s so on
  // those platforms the wait happens here, paused, instead of inside mpv
  Future<void> _jumpTo(int index) async {
    if (index < 0 || index >= _songs.length) return;
    final song = _songs[index];
    final gen = ++_switchGen;
    _switching = true;
    _currentIndex = index;
    _playedSongIds.add(song.id);
    _updateCoverArtCache();
    notifyListeners();
    try {
      if (_usesMpv) {
        final warm = _warm(song);
        final quick = await Future.any([
          warm.then((_) => true),
          Future<bool>.delayed(const Duration(milliseconds: 250), () => false),
        ]);
        if (!quick) {
          await _player.pause();
          await warm;
        }
      }
      if (gen != _switchGen) return;
      final at = _indexOfIdentical(_songs, song);
      if (at < 0) return;
      _currentIndex = at;
      await _player.seek(Duration.zero, index: at);
      if (gen != _switchGen) return;
      _switching = false;
      await _player.play();
      _maybeTopUp();
      _warmNext();
    } finally {
      if (gen == _switchGen) _switching = false;
    }
  }

  void _warmNext() {
    final next = _currentIndex + 1;
    if (next <= 0 || next >= _songs.length) return;
    unawaited(_warm(_songs[next]));
  }

  void _updateCoverArtCache() {
    final song = currentSong;
    if (song?.id == _cachedSongId) return;
    _cachedSongId = song?.id;
    final accountId = _subsonicProvider?.activeAccount?.id;
    if (song != null && accountId != null) {
      unawaited(playHistoryService.recordSong(accountId, song));
    }
    if (song == null || song.coverArt == null || _subsonicProvider == null) {
      _cachedCoverArtUrl = null;
      return;
    }
    _cachedCoverArtUrl = coverArtUrlForSong(song);
    _maybeExtractAccentColor(song);
  }
}
