import 'dart:async';
import 'dart:math';

import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/download_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/services/local_storage_service.dart';
import 'package:cosmodrome/utils/cover_art_provider.dart';
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

  final AudioPlayer _player = AudioPlayer();

  List<Song> _songs = [];
  final Set<String> _playedSongIds = <String>{};
  List<int> _shuffleOrder = [];
  int _shuffleCursor = -1;

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

  PlayerProvider() {
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
      if (index == null || index == _currentIndex) return;
      _currentIndex = index;
      if (_shuffle) {
        final cursor = _shuffleOrder.indexOf(index);
        _shuffleCursor = cursor >= 0 ? cursor : 0;
      }
      if (index >= 0 && index < _songs.length) {
        _playedSongIds.add(_songs[index].id);
      }
      _updateCoverArtCache();
      notifyListeners();
    });
  }

  Color? get accentColor => _accentColor;
  String? get currentCoverArtUrl => _cachedCoverArtUrl;
  bool get isFullscreenOpen => _isFullscreenOpen;
  Color? get prevAccentColor => _prevAccentColor;

  void closeFullscreen() {
    _isFullscreenOpen = false;
    notifyListeners();
  }

  void openFullscreen() {
    _isFullscreenOpen = true;
    notifyListeners();
  }

  int get currentIndex => _currentIndex;

  Song? get currentSong =>
      _displayIndex >= 0 && _displayIndex < _activeQueue.length
      ? _activeQueue[_displayIndex]
      : null;

  Duration get duration => _duration;
  bool get hasCurrentSong => currentSong != null;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  List<Song> get queue => List.unmodifiable(_activeQueue);
  int get queueVersion => _queueVersion;
  bool get repeat => _repeatMode != LoopMode.off;
  LoopMode get repeatMode => _repeatMode;
  bool get shuffle => _shuffle;
  List<Song> get visibleQueue {
    if (_activeQueue.isEmpty) return const <Song>[];
    final start = visibleQueueStartIndex;
    if (start >= _activeQueue.length) return const <Song>[];
    return List.unmodifiable(_activeQueue.sublist(start));
  }

  int get visibleQueueStartIndex => _displayIndex < 0 ? 0 : _displayIndex;
  double get volume => _volume;

  List<Song> get _activeQueue {
    if (!_shuffle || _shuffleOrder.isEmpty) return _songs;
    return _shuffleOrder
        .where((index) => index >= 0 && index < _songs.length)
        .map((index) => _songs[index])
        .toList();
  }

  int get _displayIndex => _shuffle ? _shuffleCursor : _currentIndex;

  Future<void> addBulkToQueue(List<Song> songs) async {
    final playable = playableSongs(songs);
    if (playable.isEmpty) return;
    _songs.addAll(playable);
    if (_shuffle) {
      _rebuildShuffleOrder();
    }
    _queueVersion++;
    await _syncPlayerQueue(preservePosition: true);
    notifyListeners();
  }

  Future<void> addToQueue(Song song) async {
    if (!isSongPlayable(song)) return;
    _songs.add(song);
    if (_shuffle) {
      _rebuildShuffleOrder();
    }
    _queueVersion++;
    await _syncPlayerQueue(preservePosition: true);
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

  List<Song> playableSongs(Iterable<Song> songs) =>
      songs.where(isSongPlayable).toList();

  Future<void> playAlbum(List<Song> songs, {bool shuffle = false}) async {
    final playable = playableSongs(songs);
    if (playable.isEmpty) return;
    _songs = List.from(playable);
    _shuffle = shuffle;
    if (_shuffle) {
      _currentIndex = _songs.length > 1 ? Random().nextInt(_songs.length) : 0;
      _rebuildShuffleOrder();
    } else {
      _currentIndex = 0;
      _shuffleOrder = [];
      _shuffleCursor = -1;
    }
    _playedSongIds
      ..clear()
      ..add(_songs[_currentIndex].id);
    _queueVersion++;
    _updateCoverArtCache();
    notifyListeners();
    await _playCurrentIndex();
  }

  Future<void> playNow(Song song) async {
    if (!isSongPlayable(song)) return;
    final pos = _currentIndex < 0 ? 0 : _currentIndex;
    _songs.insert(pos, song);
    _currentIndex = pos;
    _playedSongIds.add(song.id);
    _queueVersion++;
    _updateCoverArtCache();
    notifyListeners();
    await _playCurrentIndex();
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _activeQueue.length) return;
    final songId = _activeQueue[index].id;
    final songIndex = _songs.indexWhere((song) => song.id == songId);
    if (songIndex == -1) return;

    final removedCurrent = songIndex == _currentIndex;
    _songs.removeAt(songIndex);
    _playedSongIds.remove(songId);

    if (_songs.isEmpty) {
      _currentIndex = -1;
      _shuffleOrder = [];
      _shuffleCursor = -1;
      _isFullscreenOpen = false;
      _queueVersion++;
      _updateCoverArtCache();
      await _player.stop();
      notifyListeners();
      return;
    }

    if (songIndex < _currentIndex) {
      _currentIndex--;
    } else if (removedCurrent && _currentIndex >= _songs.length) {
      _currentIndex = _songs.length - 1;
    }

    if (_shuffle) {
      _rebuildShuffleOrder();
    }

    _queueVersion++;
    if (removedCurrent) {
      _updateCoverArtCache();
      await _playCurrentIndex();
    } else {
      await _syncPlayerQueue(preservePosition: true);
    }
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (_shuffle) return;
    if (oldIndex < 0 || oldIndex >= _songs.length) return;
    if (newIndex < 0 || newIndex > _songs.length) return;
    if (oldIndex < newIndex) newIndex -= 1;
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
    unawaited(_syncPlayerQueue(preservePosition: true));
    notifyListeners();
  }

  Future<void> resetQueue() async {
    await _clearEphemeralUris();
    _songs.clear();
    _playedSongIds.clear();
    _currentIndex = -1;
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
    if (_shuffle && _shuffleOrder.isNotEmpty) {
      if (_shuffleCursor < _shuffleOrder.length - 1) {
        _shuffleCursor++;
        final targetIndex = _shuffleOrder[_shuffleCursor];
        await _player.seek(Duration.zero, index: targetIndex);
        await _player.play();
        return;
      }

      if (_repeatMode != LoopMode.off) {
        _shuffleCursor = 0;
        await _player.seek(Duration.zero, index: _shuffleOrder[_shuffleCursor]);
        await _player.play();
        return;
      }

      await _fetchAndAppendRandom();
      return;
    }

    if (!_player.hasNext) {
      if (_repeatMode != LoopMode.off) {
        _currentIndex = _activeQueue.isEmpty ? -1 : 0;
        _updateCoverArtCache();
        notifyListeners();
        if (_currentIndex >= 0) {
          await _player.seek(Duration.zero, index: _currentIndex);
          await _player.play();
        }
        return;
      }
      await _fetchAndAppendRandom();
    }
    if (_player.hasNext) {
      await _player.seekToNext();
      await _player.play();
    }
  }

  Future<void> skipPrevious() async {
    if (_shuffle && _shuffleOrder.isNotEmpty) {
      if (_position.inSeconds > 3) {
        await _player.seek(Duration.zero);
        return;
      }

      if (_shuffleCursor > 0) {
        _shuffleCursor--;
        final targetIndex = _shuffleOrder[_shuffleCursor];
        await _player.seek(Duration.zero, index: targetIndex);
        await _player.play();
      } else {
        await _player.seek(Duration.zero);
        await _player.play();
      }
      return;
    }

    if (_position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
      await _player.play();
    } else {
      await _player.seek(Duration.zero);
      await _player.play();
    }
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

    if (!_shuffle) {
      _shuffle = true;
      _rebuildShuffleOrder();
      _shuffleCursor = _shuffleOrder.indexOf(_currentIndex);
    } else {
      _shuffle = false;
      _shuffleOrder = [];
      _shuffleCursor = -1;
    }

    _queueVersion++;
    _updateCoverArtCache();
    notifyListeners();
  }

  void update(SubsonicProvider s) {
    _subsonicProvider = s;
    _updateCoverArtCache();
  }

  Future<void> _clearEphemeralUris() async {
    if (_ephemeralCachedUris.isEmpty) return;
    final uris = List<Uri>.from(_ephemeralCachedUris);
    _ephemeralCachedUris.clear();
    for (final uri in uris) {
      await LocalStorageService.releasePlayableUri(uri);
    }
  }

  Future<void> _fetchAndAppendRandom() async {
    if (_subsonicProvider == null) return;
    if (_subsonicProvider!.isOffline) return;
    try {
      final songs = await _subsonicProvider!.subsonic.getRandomSongs(count: 10);
      await addBulkToQueue(songs);
    } catch (_) {}
  }

  Future<void> _playCurrentIndex() async {
    await _syncPlayerQueue(play: true);
  }

  void _rebuildShuffleOrder() {
    if (!_shuffle || _songs.isEmpty) {
      _shuffleOrder = [];
      _shuffleCursor = -1;
      return;
    }

    final indices = List<int>.generate(_songs.length, (index) => index);
    final currentIndex = _currentIndex >= 0 && _currentIndex < _songs.length
        ? _currentIndex
        : 0;

    indices.remove(currentIndex);
    indices.shuffle(Random());

    _shuffleOrder = [currentIndex, ...indices];
    _shuffleCursor = 0;
  }

  Future<void> _syncPlayerQueue({
    bool play = false,
    bool preservePosition = false,
    Duration? position,
  }) async {
    if (_subsonicProvider == null) return;
    if (_songs.isEmpty || _currentIndex < 0 || _currentIndex >= _songs.length) {
      return;
    }

    final seekPosition =
        position ?? (preservePosition ? _player.position : Duration.zero);

    try {
      await _clearEphemeralUris();
      final sources = <AudioSource>[];
      for (final song in _songs) {
        final localPath = _downloadProvider?.getLocalPath(song.id);
        final uri = localPath != null
            ? await LocalStorageService.playableUriForSongRef(localPath)
            : null;
        final resolvedUri =
            uri ?? Uri.parse(_subsonicProvider!.subsonic.streamUrl(song.id));
        if (uri != null && uri.scheme == 'blob') {
          _ephemeralCachedUris.add(uri);
        }
        sources.add(
          AudioSource.uri(
            resolvedUri,
            tag: MediaItem(
              id: song.id,
              duration: Duration(seconds: song.duration ?? 0),
              title: song.title,
              album: song.album,
              artist: song.artist,
              artUri: song.coverArt != null
                  ? Uri.parse(
                      _subsonicProvider!.subsonic.cachedCoverArtUrl(
                        song.coverArt!,
                        size: 300,
                      ),
                    )
                  : null,
            ),
          ),
        );
      }

      await _player.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        initialIndex: _currentIndex,
        initialPosition: seekPosition,
      );
      await _player.setLoopMode(_repeatMode);
      if (play || _player.playing) {
        await _player.play();
      }
    } catch (_) {}
  }

  void _updateCoverArtCache() {
    final song = currentSong;
    if (song?.id == _cachedSongId) return;
    _cachedSongId = song?.id;
    if (song == null || song.coverArt == null || _subsonicProvider == null) {
      _cachedCoverArtUrl = null;
      return;
    }
    try {
      _cachedCoverArtUrl = _subsonicProvider!.subsonic.cachedCoverArtUrl(
        song.coverArt!,
        size: 300,
      );
    } catch (_) {
      _cachedCoverArtUrl = null;
    }
    _maybeExtractAccentColor(song);
  }

  void _maybeExtractAccentColor(Song song) {
    if (_accentCache.containsKey(song.id)) {
      _prevAccentColor = _accentColor;
      _accentColor = _accentCache[song.id];
      notifyListeners();
      return;
    }
    unawaited(_extractAccentColor(song));
  }

  Future<void> _extractAccentColor(Song song) async {
    if (song.coverArt == null || _subsonicProvider == null) {
      _accentCache[song.id] = null;
      _prevAccentColor = _accentColor;
      _accentColor = null;
      notifyListeners();
      return;
    }

    try {
      final coverUrl = _subsonicProvider!.subsonic.cachedCoverArtUrl(
        song.coverArt!,
        size: 1200,
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
        color =
            hsl.lightness < 0.25 ? hsl.withLightness(0.35).toColor() : raw;
      }

      _accentCache[song.id] = color;
      _prevAccentColor = _accentColor;
      _accentColor = color;
      notifyListeners();
    } catch (_) {}
  }
}
