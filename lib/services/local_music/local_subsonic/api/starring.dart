part of '../master_subsonic.dart';

extension _StarringApi on MasterSubsonic {
  Map<String, dynamic> _starredJson() => {
    'artist': [
      for (final a in _library.sortedArtists)
        if (_starred.containsKey(a.id)) _artistJson(a),
    ],
    'album': [
      for (final a in _library.albums.values)
        if (_starred.containsKey(a.id)) _albumJson(a),
    ],
    'song': [
      for (final t in _library.tracks)
        if (_starred.containsKey(t.song.id)) _songJson(t),
    ],
  };

  Future<Map<String, dynamic>> _setStarred(_Args args, bool starred) async {
    final ids = [
      ...args.list('id'),
      ...args.list('albumId'),
      ...args.list('artistId'),
    ];
    if (ids.isEmpty) throw args.missing('id');
    final now = DateTime.now();
    for (final id in ids) {
      if (starred) {
        _starred[id] = now;
      } else {
        _starred.remove(id);
      }
    }
    await _save();
    return const {};
  }
}
