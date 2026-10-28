part of '../master_subsonic.dart';

extension _PlaylistsApi on MasterSubsonic {
  _LocalPlaylist _playlist(_Args args, String key) {
    final playlist = _playlists[args.require(key)];
    if (playlist == null) throw args.notFound('playlist');
    return playlist;
  }

  Map<String, dynamic> _playlistsJson() => {
    'playlists': {
      'playlist': [for (final p in _playlists.values) _playlistJson(p)],
    },
  };

  Future<Map<String, dynamic>> _createPlaylist(_Args args) async {
    final existing = args.get('playlistId');
    final songs = args.list('songId');
    final now = DateTime.now();

    final _LocalPlaylist playlist;
    if (existing != null) {
      playlist = _playlist(args, 'playlistId');
      playlist.songs
        ..clear()
        ..addAll(songs);
      playlist.name = args.get('name') ?? playlist.name;
      playlist.changed = now;
    } else {
      playlist = _LocalPlaylist(
        id: '$localPlaylistPrefix${now.microsecondsSinceEpoch.toRadixString(36)}',
        name: args.require('name'),
        created: now,
        changed: now,
        songs: songs,
      );
      _playlists[playlist.id] = playlist;
    }

    await _save();
    return {'playlist': _playlistJson(playlist, entries: true)};
  }

  Future<Map<String, dynamic>> _updatePlaylist(_Args args) async {
    final playlist = _playlist(args, 'playlistId');
    playlist.name = args.get('name') ?? playlist.name;
    if (args.get('comment') case final comment?) playlist.comment = comment;

    final visible = [
      for (final (i, id) in playlist.songs.indexed)
        if (localMusicService.track(id) != null) i,
    ];
    final remove =
        args
            .list('songIndexToRemove')
            .map(int.tryParse)
            .nonNulls
            .where((i) => i >= 0 && i < visible.length)
            .map((i) => visible[i])
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    for (final i in remove) {
      playlist.songs.removeAt(i);
    }
    playlist.songs.addAll(args.list('songIdToAdd'));
    playlist.changed = DateTime.now();

    await _save();
    return const {};
  }

  Future<Map<String, dynamic>> _deletePlaylist(_Args args) async {
    if (_playlists.remove(args.require('id')) == null) {
      throw args.notFound('playlist');
    }
    await _save();
    return const {};
  }
}
