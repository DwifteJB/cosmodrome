import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/utils/isProduction.dart';
import 'package:cosmodrome/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
// desktop platforms only, bundled in
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;

class RpcBridge extends ChangeNotifier {
  static final bool _kIsDesktop =
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  Process? _process;
  String? _lastSongId;
  bool? _lastIsPlaying;
  bool _lastSendHadZeroDuration = false;
  final Map<String, String> _coverBase64Cache =
      {}; // coverArtId -> base64-encoded image (remote or local)
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
        // running flutter run usually means theres not a rpc{.exe} file in the bundle
        if (!isProduction()) {
          loggerPrint(
            "RPC bridge executable not found, this is expected in development mode",
          );
        } else {
          loggerError(
            'RPC bridge executable not found. Expected at: ${bin.path}',
          );
        }

        return;
      }

      loggerPrint('Attempting to launch RPC bridge at ${bin.path}');

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

  // sends a stop message and kills the subprocess
  Future<void> shutdown() async {
    if (_process == null) return;
    _write({'type': 'STOP'});
    // waits for it to be cleaned up, if it still exists, KILL it.
    await Future.delayed(const Duration(milliseconds: 1000));
    _process?.kill();
    _process = null;
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

    final artId = song.coverArt ?? '';
    var coverBase64 = _coverBase64Cache[artId] ?? '';
    final candidate = player.currentCoverArtUrl;
    if (artId.isNotEmpty &&
        coverBase64.isEmpty &&
        candidate != null &&
        candidate.isNotEmpty) {
      final bytes = await _loadCoverBytes(candidate);
      if (bytes != null && bytes.isNotEmpty) {
        coverBase64 = _coverBase64Cache[artId] = base64Encode(bytes);
      }
    }

    final activity = {
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

    loggerPrint("[rpc:bridge]: Sending activity update");

    _write(activity);
    _lastSongId = song.id;
    _lastIsPlaying = playing;
    _lastSendHadZeroDuration = player.duration.inSeconds == 0;
  }

  String? _getExecutablePath() {
    final candidates = <String>[];
    final exeDir = p.dirname(Platform.resolvedExecutable);

    if (Platform.isWindows) {
      candidates.addAll([
        p.join(exeDir, _executableName),
        p.join(exeDir, 'data', 'flutter_assets', 'assets', _executableName),
        p.join(exeDir, 'bin', _executableName),
      ]);
    } else if (Platform.isMacOS) {
      // exeDir is the same as Contents/MacOS/
      final resourcesDir = p.join(
        exeDir,
        '..',
        'Resources',
      ); // same as Contents/Resources/
      candidates.addAll([
        p.join(resourcesDir, _executableName),
        p.join(exeDir, _executableName),
        '/Applications/cosmodrome.app/Contents/Resources/$_executableName',
        '/Applications/cosmodrome.app/Contents/MacOS/$_executableName',
      ]);
    } else if (Platform.isLinux) {
      candidates.addAll([
        p.join(exeDir, _executableName),
        p.join(exeDir, 'lib', _executableName),
        p.join(exeDir, 'data', _executableName),
        '/usr/lib/cosmodrome/$_executableName',
        '/opt/cosmodrome/$_executableName',
      ]);
    }

    return candidates.where((path) => File(path).existsSync()).firstOrNull;
  }

  // the bridge only reports connection status, which nothing consumes yet, so just log it
  void _onOutput(String line) => loggerPrint('[rpc:bridge]: $line');

  Future<List<int>?> _loadCoverBytes(String candidate) async {
    final parsed = Uri.tryParse(candidate);
    final isRemoteHttp =
        parsed != null && (parsed.scheme == 'http' || parsed.scheme == 'https');

    if (isRemoteHttp) {
      try {
        final client = HttpClient();
        try {
          final request = await client.getUrl(parsed);
          final response = await request.close();
          if (response.statusCode != 200) return null;
          return await consolidateHttpClientResponseBytes(response);
        } finally {
          client.close();
        }
      } catch (_) {
        return null;
      }
    }

    final file = _resolveLocalImageFile(candidate);
    if (file != null && await file.exists()) {
      try {
        return await file.readAsBytes();
      } catch (_) {}
    }
    return null;
  }

  File? _resolveLocalImageFile(String candidate) {
    final parsed = Uri.tryParse(candidate);
    if (parsed == null || parsed.scheme.isEmpty) return File(candidate);
    if (parsed.scheme == 'file') return File.fromUri(parsed);
    return null;
  }

  void _write(Map<String, dynamic> msg) {
    try {
      _process?.stdin.writeln(jsonEncode(msg));
    } catch (_) {}
  }
}
