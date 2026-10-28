part of '../master_subsonic.dart';

extension _Responses on MasterSubsonic {
  Map<String, dynamic> _songJson(LocalTrack track) => {
    ...track.song.toJson(),
    'album': track.albumName,
    'albumId': track.localAlbumId,
    'artist': track.song.artist ?? track.albumArtistName,
    'artistId': track.localArtistId,
    'year': ?track.year,
    'genre': ?track.genre,
    'size': track.size,
    'created': _date(track.modified),
    'starred': ?_starred[track.song.id]?.toIso8601String(),
    'isDir': false,
    'type': 'music',
  };

  Map<String, dynamic> _albumJson(_LocalAlbum album, {bool songs = false}) => {
    'id': album.id,
    'name': album.name,
    'artist': album.artist,
    'artistId': album.artistId,
    'coverArt': ?album.coverArt,
    'songCount': album.tracks.length,
    'duration': album.duration,
    'year': ?album.year,
    'genre': ?album.genre,
    'created': _date(album.created),
    'starred': ?_starred[album.id]?.toIso8601String(),
    if (songs) 'song': [for (final t in album.tracks) _songJson(t)],
  };

  Map<String, dynamic> _artistJson(
    _LocalArtist artist, {
    bool albums = false,
  }) => {
    'id': artist.id,
    'name': artist.name,
    'albumCount': artist.albums.length,
    'coverArt': ?artist.coverArt,
    'starred': ?_starred[artist.id]?.toIso8601String(),
    if (albums) 'album': [for (final a in artist.albums) _albumJson(a)],
  };

  Map<String, dynamic> _playlistJson(
    _LocalPlaylist playlist, {
    bool entries = false,
  }) {
    final tracks = [
      for (final id in playlist.songs) ?localMusicService.track(id),
    ];
    return {
      'id': playlist.id,
      'name': playlist.name,
      'comment': ?playlist.comment,
      'owner': localUsername,
      'public': false,
      'songCount': tracks.length,
      'duration': tracks.fold(0, (sum, t) => sum + (t.song.duration ?? 0)),
      'created': playlist.created.toIso8601String(),
      'changed': playlist.changed.toIso8601String(),
      'coverArt': ?tracks
          .map((t) => t.song.coverArt)
          .firstWhere((c) => c != null, orElse: () => null),
      if (entries) 'entry': [for (final t in tracks) _songJson(t)],
    };
  }

  Iterable<T> _page<T>(Iterable<T> items, int offset, int size) =>
      items.skip(max(0, offset)).take(max(0, size));

  String _date(int millis) =>
      DateTime.fromMillisecondsSinceEpoch(millis).toIso8601String();
}
