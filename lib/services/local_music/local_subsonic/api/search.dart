part of '../master_subsonic.dart';

extension _SearchApi on MasterSubsonic {
  Map<String, dynamic> _search(_Args args) {
    final query = (args.get('query') ?? '')
        .replaceAll('"', '')
        .trim()
        .toLowerCase();
    bool matches(String? value) =>
        query.isEmpty || (value?.toLowerCase().contains(query) ?? false);

    final artists = _library.sortedArtists.where((a) => matches(a.name));
    final albums = _library.albums.values.where(
      (a) => matches(a.name) || matches(a.artist),
    );
    final songs = _library.tracks.where(
      (t) =>
          matches(t.song.title) ||
          matches(t.song.artist) ||
          matches(t.song.album),
    );

    return {
      'artist': [
        for (final a in _page(
          artists,
          args.integer('artistOffset', 0),
          args.integer('artistCount', 20),
        ))
          _artistJson(a),
      ],
      'album': [
        for (final a in _page(
          albums,
          args.integer('albumOffset', 0),
          args.integer('albumCount', 20),
        ))
          _albumJson(a),
      ],
      'song': [
        for (final t in _page(
          songs,
          args.integer('songOffset', 0),
          args.integer('songCount', 20),
        ))
          _songJson(t),
      ],
    };
  }
}
