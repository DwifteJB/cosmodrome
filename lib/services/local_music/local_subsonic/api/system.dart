part of '../master_subsonic.dart';

extension _SystemApi on MasterSubsonic {
  Map<String, dynamic> _license() => {
    'license': {'valid': 'true'},
  };

  Map<String, dynamic> _musicFolders() => {
    'musicFolders': {
      'musicFolder': [
        {'id': 1, 'name': localUsername},
      ],
    },
  };

  Map<String, dynamic> _scanStatus() => {
    'scanStatus': {
      'scanning': localMusicService.isScanning,
      'count': localMusicService.count,
    },
  };

  Map<String, dynamic> _startScan() {
    unawaited(localMusicService.scan());
    return _scanStatus();
  }
}
