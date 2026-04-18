import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
// desktop platforms only, bundled in
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;

class RpcBridge extends ChangeNotifier {
  static final bool _kIsDesktop =
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  Process? _process;
  bool _connected = false;

  String? _connectedUser;
  Timer? _debounce;
  String? _lastSongId;
  bool? _lastIsPlaying;
  bool _lastSendHadZeroDuration = false;
  final Map<String, String> _coverBase64Cache = {}; // coverArtId → base64
  String? get connectedUser => _connectedUser;

  bool get isConnected => _connected;

  String get _executableName =>
      Platform.isWindows ? 'cosmodrome-rpc.exe' : 'cosmodrome-rpc';

  @override
  void dispose() {
    shutdown();
    super.dispose();
  }

  // finds and launches the subprocess, and starts listening for its output
  Future<void> init() async {
    loggerPrint("RPC START!");
    if (!_kIsDesktop) return;
    try {
      final bin = File(_getExecutablePath() ?? '');

      if (!bin.existsSync()) {
        loggerError(
          'RPC bridge executable not found. Expected at: ${bin.path}',
        );
        return;
      }

      loggerPrint('Attempting to launch RPC bridge at ${bin.path}');
      if (!bin.existsSync()) return;

      _process = await Process.start(
        bin.path,
        [],
        workingDirectory: p.dirname(bin.path),
        mode: ProcessStartMode.detachedWithStdio,
      );

      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_onOutput, onError: (_) {});
    } catch (_) {
      _process = null;
    }
  }

  // update is a bit weird for a setactivity :shrug:
  void setActivity(PlayerProvider player) => update(player);

  // sends a stop message and kills the subprocess
  Future<void> shutdown() async {
    _debounce?.cancel();
    if (_process == null) return;
    _write({'type': 'STOP'});
    // waits for it to be cleaned up, if it still exists, KILL it.
    await Future.delayed(const Duration(milliseconds: 1000));
    _process?.kill();
    _process = null;
    _connected = false;
  }

  // called by player provider listener. updates status
  void update(PlayerProvider player) {
    if (_process == null) return;

    final song = player.currentSong;
    final playing = player.isPlaying;

    final songChanged = song?.id != _lastSongId;
    final stateChanged = playing != _lastIsPlaying;

    final durationReady =
        _lastSendHadZeroDuration && player.duration.inSeconds > 0;

    // song has changed, we should update!
    if (songChanged || stateChanged || durationReady) {
      _debounce?.cancel();
      _doSend(song, player, playing);
    }
  }

  // actual sender
  Future<void> _doSend(Song? song, PlayerProvider player, bool playing) async {
    if (_process == null) return;

    if (song == null) {
      loggerPrint("[rpc:bridge]: No song, clearing activity");
      _write({'type': 'CLEAR_ACTIVITY'});
      _lastSongId = null;
      _lastIsPlaying = null;
      return;
    }

    String coverBase64 = '';
    final artId = song.coverArt ?? '';
    if (artId.isNotEmpty) {
      if (_coverBase64Cache.containsKey(artId)) {
        coverBase64 = _coverBase64Cache[artId]!;
      } else {
        final coverUrl = player.currentCoverArtUrl;
        if (coverUrl != null && coverUrl.isNotEmpty) {
          try {
            final res = await http.get(Uri.parse(coverUrl));
            if (res.statusCode == 200) {
              coverBase64 = base64Encode(res.bodyBytes);
              _coverBase64Cache[artId] = coverBase64;
            }
          } catch (_) {}
        }
      }
    }

    var activity = {
      'type': 'SET_ACTIVITY',
      'title': song.title,
      'artist': song.artist ?? '',
      'album': song.album ?? '',
      'coverBase64': coverBase64,
      'coverArtId': artId,
      'elapsed': player.position.inSeconds,
      'duration': player.duration.inSeconds,
      'paused': !playing,
    };

    loggerPrint("[rpc:bridge]: Sending activity update: $activity");

    _write(activity);
    _lastSongId = song.id;
    _lastIsPlaying = playing;
    _lastSendHadZeroDuration = player.duration.inSeconds == 0;
  }

  String? _getExecutablePath() {
    final candidates = <String>[];

    if (Platform.isWindows) {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      candidates.addAll([
        p.join(exeDir, _executableName),
        p.join(exeDir, 'data', 'flutter_assets', 'assets', _executableName),
        p.join(exeDir, 'bin', _executableName),
      ]);
    } else if (Platform.isMacOS) {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final resourcesDir = p.join(exeDir, '..', 'Resources');
      candidates.addAll([
        p.join(resourcesDir, _executableName),
        p.join(exeDir, _executableName),
        '/Applications/cosmodrome.app/Contents/Resources/$_executableName',
      ]);
    } else if (Platform.isLinux) {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      candidates.addAll([
        p.join(exeDir, _executableName),
        p.join(exeDir, 'lib', _executableName),
        p.join(exeDir, 'data', _executableName),
        '/usr/lib/cosmodrome/$_executableName',
        '/opt/cosmodrome/$_executableName',
      ]);
    }

    for (final path in candidates) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    return null;
  }

  void _onOutput(String line) {
    try {
      final data = jsonDecode(line) as Map<String, dynamic>;
      final type = data['type'] as String?;

      loggerPrint('[rpc:bridge]: $data');
      switch (type) {
        case 'CONNECTED':
        case 'RECONNECTED':
          _connected = true;
          _connectedUser = data['user'] as String?;
          notifyListeners();
        case 'DISCONNECTED':
          _connected = false;
          _connectedUser = null;
          notifyListeners();
        case 'ERROR':
          _connected = false;
          notifyListeners();
      }
    } catch (_) {}
  }

  void _write(Map<String, dynamic> msg) {
    try {
      _process?.stdin.writeln(jsonEncode(msg));
    } catch (_) {}
  }
}
