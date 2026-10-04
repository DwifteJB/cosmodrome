// simply scan for servers that are real subsonic servers by hitting /rest/ping.view locally

import 'package:cosmodrome/helpers/subsonic-api-helper/api/basic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/utils/logger/logger.dart';

const _scanBatchSize = 50;
const _scanTimeoutSeconds = 2;

List<Subsonic> _knownServers = [];
Future<List<Subsonic>>? _scanInFlight;
final List<void Function(Subsonic server)> _scanListeners = [];

Future<List<Subsonic>> scanForServers({
  void Function(Subsonic server)? onFound,
}) async {
  if (_knownServers.isNotEmpty) {
    if (onFound != null) {
      for (final server in _knownServers) {
        onFound(server);
      }
    }
    loggerPrint(
      'using known servers: ${_knownServers.map((s) => s.baseUrl).join(', ')}',
    );
    return _knownServers;
  }

  if (onFound != null) {
    _scanListeners.add(onFound);
  }

  if (_scanInFlight != null) return _scanInFlight!;

  _scanInFlight = _scanForServersImpl();
  try {
    return await _scanInFlight!;
  } finally {
    _scanInFlight = null;
    _scanListeners.clear();
  }
}

void _emitFoundServer(Subsonic server) {
  for (final listener in List<void Function(Subsonic server)>.from(
    _scanListeners,
  )) {
    listener(server);
  }
}

Future<List<Subsonic>> _scanForServersImpl() async {
  // search for 192.168.1.xxx
  // then also search for 10.0.0.xxx
  // finally, search for tailscale 100.64.xxx.xxx
  final candidates = <Subsonic>[];
  final foundServers = <Subsonic>[];

  Subsonic candidate(String ip) => Subsonic(
    baseUrl: 'http://$ip:4533',
    username: 'dummy',
    password: 'dummy',
  );

  for (var i = 1; i < 255; i++) {
    candidates
      ..add(candidate('192.168.1.$i'))
      // ..add(candidate('10.0.0.$i'))
      ..add(candidate('100.64.0.$i'));
  }

  loggerPrint('searching for servers... (${candidates.length} candidates)');

  // batch send requests
  for (var index = 0; index < candidates.length; index += _scanBatchSize) {
    final batch = candidates.skip(index).take(_scanBatchSize);

    final results = await Future.wait(
      batch.map((server) async {
        final res = await server.ping(timeoutSeconds: _scanTimeoutSeconds);
        return (server: server, success: res.success, errorCode: res.errorCode);
      }),
    );

    // successful is if logins work (pub server?) or if we get a subsonic specific error
    for (final result in results) {
      if (!result.success && result.errorCode == null) continue;
      loggerPrint('found server at ${result.server.baseUrl}');
      foundServers.add(result.server);
      _emitFoundServer(result.server);
    }
  }

  _knownServers = List.unmodifiable(foundServers);
  return _knownServers;
}
