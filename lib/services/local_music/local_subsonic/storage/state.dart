part of '../master_subsonic.dart';

extension _State on MasterSubsonic {
  Future<void> _load() async {
    try {
      final raw = await LocalStorageService.readJsonMeta(_store, _stateKey);
      if (raw == null) return;
      for (final item in raw['playlists'] as List<dynamic>? ?? const []) {
        final playlist = _LocalPlaylist.fromJson(item as Map<String, dynamic>);
        _playlists[playlist.id] = playlist;
      }
      final starred = raw['starred'] as Map<String, dynamic>? ?? const {};
      for (final MapEntry(:key, :value) in starred.entries) {
        final date = DateTime.tryParse(value as String);
        if (date != null) _starred[key] = date;
      }
    } catch (e) {
      loggerPrint('MasterSubsonic: failed to load state: $e');
    }
  }

  Future<void> _save() async {
    try {
      await LocalStorageService.ensureDirs(_store);
      await LocalStorageService.writeJsonMeta(_store, _stateKey, {
        'playlists': [for (final p in _playlists.values) p.toJson()],
        'starred': {
          for (final e in _starred.entries) e.key: e.value.toIso8601String(),
        },
      });
    } catch (e) {
      loggerPrint('MasterSubsonic: failed to save state: $e');
    }
  }
}
