part of '../master_subsonic.dart';

class _LocalIndex {
  final Map<String, _LocalAlbum> albums;
  final Map<String, _LocalArtist> artists;
  final List<_LocalArtist> sortedArtists;
  final List<LocalTrack> tracks;

  _LocalIndex(this.albums, this.artists, this.tracks)
    : sortedArtists = artists.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  factory _LocalIndex.build() {
    final tracks = [
      for (final song in localMusicService.songs)
        ?localMusicService.track(song.id),
    ];
    final albums = <String, _LocalAlbum>{};
    for (final track in tracks) {
      albums
          .putIfAbsent(track.localAlbumId, () => _LocalAlbum(track))
          .add(track);
    }
    final artists = <String, _LocalArtist>{};
    for (final album in albums.values) {
      artists
          .putIfAbsent(album.artistId, () => _LocalArtist(album))
          .albums
          .add(album);
    }
    return _LocalIndex(albums, artists, tracks);
  }
}

class _LocalAlbum {
  final String id;
  final String name;
  final String artist;
  final String artistId;
  final List<LocalTrack> tracks = [];

  _LocalAlbum(LocalTrack track)
    : id = track.localAlbumId,
      name = track.albumName,
      artist = track.albumArtistName,
      artistId = track.localArtistId;

  String? get coverArt => tracks
      .map((t) => t.song.coverArt)
      .firstWhere((c) => c != null, orElse: () => null);

  int get created => tracks.fold(0, (latest, t) => max(latest, t.modified));

  int get duration => tracks.fold(0, (sum, t) => sum + (t.song.duration ?? 0));

  String? get genre => tracks
      .map((t) => t.genre)
      .firstWhere((g) => g != null && g.trim().isNotEmpty, orElse: () => null);

  Set<String> get genres => {
    for (final t in tracks)
      if (t.genre?.trim() case final g? when g.isNotEmpty) g.toLowerCase(),
  };

  int? get year => tracks
      .map((t) => t.year)
      .firstWhere((y) => y != null, orElse: () => null);

  void add(LocalTrack track) => tracks.add(track);
}

class _LocalArtist {
  final String id;
  final String name;
  final List<_LocalAlbum> albums = [];

  _LocalArtist(_LocalAlbum album) : id = album.artistId, name = album.artist;

  String? get coverArt => albums
      .map((a) => a.coverArt)
      .firstWhere((c) => c != null, orElse: () => null);
}
