import 'dart:async';

import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  SubsonicProvider? _subsonicProvider;
  bool _shuffle = false;
  bool _repeat = false;
  double _volume = 1.0;

  // Cached once per song so Image.network gets a stable URL.
  String? _cachedCoverArtUrl;
  String? _cachedSongId;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;

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
      if (state.processingState == ProcessingState.completed) {
        skipNext();
      }
      notifyListeners();
    });
  }

  String? get currentCoverArtUrl => _cachedCoverArtUrl;

  Song? get currentSong => _currentIndex >= 0 && _currentIndex < _queue.length
      ? _queue[_currentIndex]
      : null;

  Duration get duration => _duration;
  bool get hasCurrentSong => currentSong != null;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  List<Song> get queue => List.unmodifiable(_queue);
  bool get repeat => _repeat;
  bool get shuffle => _shuffle;
  double get volume => _volume;

  Future<void> addBulkToQueue(List<Song> songs) async {
    _queue.addAll(songs);
    notifyListeners();
  }

  Future<void> addToQueue(Song song) async {
    _queue.add(song);
    notifyListeners();
  }

  String? coverArtUrlForSong(Song song) {
    if (song.coverArt == null || _subsonicProvider == null) return null;
    try {
      return _subsonicProvider!.subsonic.coverArtUrl(song.coverArt!, size: 300);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> playAlbum(List<Song> songs, {bool shuffle = false}) async {
    if (songs.isEmpty) return;
    _queue = List.from(songs);
    if (shuffle) _queue.shuffle();
    _currentIndex = 0;
    _updateCoverArtCache();
    notifyListeners();
    await _playCurrentIndex();
  }

  Future<void> playNow(Song song) async {
    final pos = _currentIndex < 0 ? 0 : _currentIndex;
    _queue.insert(pos, song);
    _currentIndex = pos;
    _updateCoverArtCache();
    notifyListeners();
    await _playCurrentIndex();
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      if (_currentIndex >= _queue.length) {
        _currentIndex = _queue.length - 1;
      }
      if (_currentIndex >= 0) {
        _updateCoverArtCache();
        await _playCurrentIndex();
      }
    }
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);
    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }
    notifyListeners();
  }

  Future<void> resetQueue() async {
    _queue.clear();
    _currentIndex = -1;
    _updateCoverArtCache();
    notifyListeners();
    await _player.stop();
  }

  Future<void> seekTo(Duration pos) async {
    await _player.seek(pos);
  }

  Future<void> setVolume(double v) async {
    await _player.setVolume(v);
    _volume = v;
    notifyListeners();
  }

  Future<void> skipNext() async {
    if (_currentIndex >= _queue.length - 1) {
      if (_repeat) {
        _currentIndex = 0;
        _updateCoverArtCache();
        notifyListeners();
        await _playCurrentIndex();
        return;
      }
      await _fetchAndAppendRandom();
    }
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      _updateCoverArtCache();
      notifyListeners();
      await _playCurrentIndex();
    }
  }

  Future<void> skipPrevious() async {
    if (_position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_currentIndex > 0) {
      _currentIndex--;
      _updateCoverArtCache();
      notifyListeners();
      await _playCurrentIndex();
    }
  }

  Future<void> togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  void toggleRepeat() {
    _repeat = !_repeat;
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    notifyListeners();
  }

  void update(SubsonicProvider s) {
    _subsonicProvider = s;
    _updateCoverArtCache();
  }

  Future<void> _fetchAndAppendRandom() async {
    if (_subsonicProvider == null) return;
    try {
      final songs = await _subsonicProvider!.subsonic.getRandomSongs(count: 10);
      _queue.addAll(songs);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _playCurrentIndex() async {
    if (_subsonicProvider == null) return;
    final song = currentSong;
    if (song == null) return;
    try {
      final url = _subsonicProvider!.subsonic.streamUrl(song.id);

      await _player.setUrl(
        url,
        tag: MediaItem(
          id: song.id,
          duration: Duration(seconds: song.duration ?? 0),
          title: song.title,
          album: song.album,
          artist: song.artist,
          artUri: song.coverArt != null
              ? Uri.parse(
                  _subsonicProvider!.subsonic.coverArtUrl(
                    song.coverArt!,
                    size: 300,
                  ),
                )
              : null,
        ),
      );
      await _player.play();
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
      _cachedCoverArtUrl = _subsonicProvider!.subsonic.coverArtUrl(
        song.coverArt!,
        size: 300,
      );
    } catch (_) {
      _cachedCoverArtUrl = null;
    }
  }
}
