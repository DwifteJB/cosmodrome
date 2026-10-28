part of '../master_subsonic.dart';

extension _BrowsingApi on MasterSubsonic {
  LocalTrack _track(_Args args) {
    final track = localMusicService.track(args.require('id'));
    if (track == null) throw args.notFound('song');
    return track;
  }

  _LocalAlbum _album(_Args args) {
    final album = _library.albums[args.require('id')];
    if (album == null) throw args.notFound('album');
    return album;
  }

  _LocalArtist _artist(_Args args) {
    final artist = _library.artists[args.require('id')];
    if (artist == null) throw args.notFound('artist');
    return artist;
  }

  List<Map<String, dynamic>> _artistIndex() {
    final groups = <String, List<_LocalArtist>>{};
    for (final artist in _library.sortedArtists) {
      final first = artist.name.substring(0, 1).toUpperCase();
      final key = RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
      groups.putIfAbsent(key, () => []).add(artist);
    }
    final keys = groups.keys.toList()..sort();
    return [
      for (final key in keys)
        {
          'name': key,
          'artist': [for (final a in groups[key]!) _artistJson(a)],
        },
    ];
  }

  List<Map<String, dynamic>> _albumList(_Args args) {
    final albums = _library.albums.values.toList();
    int byName(_LocalAlbum a, _LocalAlbum b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());

    switch (args.get('type')) {
      case 'random':
        albums.shuffle(_random);
      case 'newest' || 'recent' || 'frequent' || 'highest':
        albums.sort((a, b) => b.created.compareTo(a.created));
      case 'alphabeticalByArtist':
        albums.sort((a, b) {
          final artist = a.artist.toLowerCase().compareTo(
            b.artist.toLowerCase(),
          );
          return artist != 0 ? artist : byName(a, b);
        });
      case 'starred':
        albums
          ..retainWhere((a) => _starred.containsKey(a.id))
          ..sort(byName);
      case 'byYear':
        final from = args.integer('fromYear', 0);
        final to = args.integer('toYear', 9999);
        final low = min(from, to);
        final high = max(from, to);
        albums
          ..retainWhere((a) {
            final year = a.year;
            return year != null && year >= low && year <= high;
          })
          ..sort(
            (a, b) => from <= to
                ? a.year!.compareTo(b.year!)
                : b.year!.compareTo(a.year!),
          );
      case 'byGenre':
        final genre = args.get('genre')?.toLowerCase();
        albums
          ..retainWhere((a) => a.genres.contains(genre))
          ..sort(byName);
      default:
        albums.sort(byName);
    }

    return [
      for (final album in _page(
        albums,
        args.integer('offset', 0),
        args.integer('size', 10),
      ))
        _albumJson(album),
    ];
  }

  List<Map<String, dynamic>> _genres() {
    final songs = <String, int>{};
    final albums = <String, int>{};
    final names = <String, String>{};
    for (final album in _library.albums.values) {
      for (final track in album.tracks) {
        final genre = track.genre?.trim();
        if (genre == null || genre.isEmpty) continue;
        final key = genre.toLowerCase();
        names.putIfAbsent(key, () => genre);
        songs[key] = (songs[key] ?? 0) + 1;
      }
      for (final key in album.genres) {
        albums[key] = (albums[key] ?? 0) + 1;
      }
    }
    return [
      for (final key in names.keys)
        {
          'value': names[key],
          'songCount': songs[key] ?? 0,
          'albumCount': albums[key] ?? 0,
        },
    ];
  }

  List<Map<String, dynamic>> _randomSongs(_Args args) {
    final tracks = _library.tracks.toList()..shuffle(_random);
    return [
      for (final track in tracks.take(args.integer('size', 10)))
        _songJson(track),
    ];
  }

  List<Map<String, dynamic>> _topSongs(_Args args) {
    final name = args.require('artist').toLowerCase();
    return [
      for (final track in _library.tracks.where(
        (t) =>
            t.albumArtistName.toLowerCase() == name ||
            t.song.artist?.toLowerCase() == name,
      ))
        _songJson(track),
    ].take(args.integer('count', 50)).toList();
  }
}
