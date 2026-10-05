import 'dart:async';

import 'package:cosmodrome/helpers/subsonic-api-helper/api/lyrics.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/lyrics.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:flutter/foundation.dart';

const int kLyricsNoLine = -1;

class SongLyrics {
  final String songId;

  final StructuredLyrics? main;
  final StructuredLyrics? translation;
  final StructuredLyrics? pronunciation;

  final List<StructuredLyrics> all;

  const SongLyrics({
    required this.songId,
    required this.main,
    required this.translation,
    required this.pronunciation,
    required this.all,
  });

  const SongLyrics.empty(this.songId)
    : main = null,
      translation = null,
      pronunciation = null,
      all = const [];

  bool get hasLyrics => main != null && main!.lines.isNotEmpty;
  bool get synced => main?.synced == true;
  bool get hasTranslation =>
      translation != null && translation!.lines.isNotEmpty;
  bool get hasPronunciation =>
      pronunciation != null && pronunciation!.lines.isNotEmpty;

  List<LyricLine> get lines => main?.lines ?? const [];

  int? lineStartMs(int index) {
    final m = main;
    if (m == null || index < 0 || index >= m.lines.length) return null;
    final start = m.lines[index].start;
    if (start == null) return null;
    return start - m.offset;
  }

  int lineIndexAt(Duration position) {
    final m = main;
    if (m == null || !m.synced || m.lines.isEmpty) return kLyricsNoLine;
    final ms = position.inMilliseconds;
    var lo = 0;
    var hi = m.lines.length - 1;
    var result = kLyricsNoLine;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final start = lineStartMs(mid);
      if (start == null) {
        lo = mid + 1;
        continue;
      }
      if (start <= ms) {
        result = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return result;
  }

  LyricLine? layerLineFor(StructuredLyrics? layer, int index) {
    final m = main;
    if (layer == null || m == null) return null;
    if (index < 0 || index >= m.lines.length) return null;
    if (layer.lines.isEmpty) return null;

    final mainStart = m.lines[index].start;
    if (m.synced && layer.synced && mainStart != null) {
      LyricLine? best;
      var bestDiff = 1 << 30;
      for (final line in layer.lines) {
        final s = line.start;
        if (s == null) continue;
        final diff = (s - mainStart).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          best = line;
        }
        if (s > mainStart && diff > bestDiff) break;
      }
      if (best != null && bestDiff <= 1500) return best;
      return null;
    }

    if (index < layer.lines.length) return layer.lines[index];
    return null;
  }
}

class LyricsProvider extends ChangeNotifier {
  SubsonicProvider? _subsonic;
  PlayerProvider? _player;

  String? _loadedSongId;
  String? _loadingSongId;
  SongLyrics? _lyrics;
  bool _isLoading = false;
  String? _error;

  bool _showTranslation = true;
  bool _showPronunciation = true;

  final Map<String, SongLyrics> _cache = {};

  SongLyrics? get lyrics => _lyrics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLyrics => _lyrics?.hasLyrics == true;

  bool get showTranslation => _showTranslation;
  bool get showPronunciation => _showPronunciation;

  bool get hasSecondaryLayers =>
      _lyrics?.hasTranslation == true || _lyrics?.hasPronunciation == true;

  bool get secondaryLayersVisible =>
      (_showTranslation && _lyrics?.hasTranslation == true) ||
      (_showPronunciation && _lyrics?.hasPronunciation == true);

  void setShowTranslation(bool value) {
    if (_showTranslation == value) return;
    _showTranslation = value;
    notifyListeners();
  }

  void setShowPronunciation(bool value) {
    if (_showPronunciation == value) return;
    _showPronunciation = value;
    notifyListeners();
  }

  void toggleSecondaryLayers() {
    final next = !secondaryLayersVisible;
    _showTranslation = next;
    _showPronunciation = next;
    notifyListeners();
  }

  int lineIndexAt(Duration position) =>
      _lyrics?.lineIndexAt(position) ?? kLyricsNoLine;

  void update(SubsonicProvider subsonic, PlayerProvider player) {
    _subsonic = subsonic;
    if (_player != player) {
      _player?.removeListener(_onPlayerChanged);
      _player = player;
      player.addListener(_onPlayerChanged);
    }
    _onPlayerChanged();
  }

  Future<void> refresh() async {
    final song = _player?.currentSong;
    if (song == null) return;
    _cache.remove(song.id);
    _loadedSongId = null;
    await _load(song);
  }

  @override
  void dispose() {
    _player?.removeListener(_onPlayerChanged);
    super.dispose();
  }

  void _onPlayerChanged() {
    final song = _player?.currentSong;
    if (song == null) {
      if (_lyrics != null || _loadedSongId != null) {
        _lyrics = null;
        _loadedSongId = null;
        _loadingSongId = null;
        _isLoading = false;
        _error = null;
        notifyListeners();
      }
      return;
    }
    if (song.id == _loadedSongId || song.id == _loadingSongId) return;
    unawaited(_load(song));
  }

  Future<void> _load(Song song) async {
    final cached = _cache[song.id];
    if (cached != null) {
      _lyrics = cached;
      _loadedSongId = song.id;
      _loadingSongId = null;
      _isLoading = false;
      _error = null;
      notifyListeners();
      return;
    }

    final subsonic = _subsonic;
    if (subsonic == null || subsonic.activeAccount == null) return;

    _loadingSongId = song.id;
    _isLoading = true;
    _error = null;
    _lyrics = null;
    _loadedSongId = null;
    notifyListeners();

    SongLyrics result;
    try {
      result = await _fetch(subsonic, song);
    } catch (e) {
      result = SongLyrics.empty(song.id);
      _error = e.toString();
    }

    if (_loadingSongId != song.id) return;

    _cache[song.id] = result;
    _lyrics = result;
    _loadedSongId = song.id;
    _loadingSongId = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<SongLyrics> _fetch(SubsonicProvider provider, Song song) async {
    if (provider.isOffline) return SongLyrics.empty(song.id);
    final api = provider.subsonic;

    final version = await api.songLyricsVersion();
    List<StructuredLyrics> entries = const [];

    if (version != null) {
      entries = await api.getLyricsBySongId(song.id, enhanced: version >= 2);
    }

    if (entries.isEmpty) {
      final text = await api.getLyrics(artist: song.artist, title: song.title);
      if (text == null) return SongLyrics.empty(song.id);
      final plain = StructuredLyrics.fromPlainText(
        text,
        artist: song.artist,
        title: song.title,
      );
      return SongLyrics(
        songId: song.id,
        main: plain,
        translation: null,
        pronunciation: null,
        all: [plain],
      );
    }

    return _resolve(song.id, entries);
  }

  SongLyrics _resolve(String songId, List<StructuredLyrics> entries) {
    StructuredLyrics? pick(LyricsKind kind) {
      final ofKind = entries.where((e) => e.kind == kind && e.lines.isNotEmpty);
      if (ofKind.isEmpty) return null;
      return ofKind.firstWhere((e) => e.synced, orElse: () => ofKind.first);
    }

    final main = pick(LyricsKind.main);
    if (main == null) return SongLyrics.empty(songId);

    return SongLyrics(
      songId: songId,
      main: main,
      translation: pick(LyricsKind.translation),
      pronunciation: pick(LyricsKind.pronunciation),
      all: entries,
    );
  }
}
