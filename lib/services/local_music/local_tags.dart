import 'dart:typed_data';

// id3 tags of what we can find in a local file
class LocalTags {
  final String? title;
  final String? artist;
  final String? albumArtist;
  final String? album;
  final int? track;
  final int? disc;
  final int? duration;
  final int? year;
  final String? genre;
  final int? bitRate;
  final int? sampleRate;
  final Uint8List? picture;

  const LocalTags({
    this.title,
    this.artist,
    this.albumArtist,
    this.album,
    this.track,
    this.disc,
    this.duration,
    this.year,
    this.genre,
    this.bitRate,
    this.sampleRate,
    this.picture,
  });
}

class LocalTagEdit {
  final String? title;
  final String? artist;
  final String? albumArtist;
  final String? album;
  final int? track;
  final int? disc;
  final int? year;
  final String? genre;
  final Uint8List? picture;
  final bool pictureChanged;

  const LocalTagEdit({
    this.title,
    this.artist,
    this.albumArtist,
    this.album,
    this.track,
    this.disc,
    this.year,
    this.genre,
    this.picture,
    this.pictureChanged = false,
  });

  factory LocalTagEdit.fromJson(Map<String, dynamic> json) => LocalTagEdit(
    title: json['title'] as String?,
    artist: json['artist'] as String?,
    albumArtist: json['albumArtist'] as String?,
    album: json['album'] as String?,
    track: (json['track'] as num?)?.toInt(),
    disc: (json['disc'] as num?)?.toInt(),
    year: (json['year'] as num?)?.toInt(),
    genre: json['genre'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'title': ?title,
    'artist': ?artist,
    'albumArtist': ?albumArtist,
    'album': ?album,
    'track': ?track,
    'disc': ?disc,
    'year': ?year,
    'genre': ?genre,
  };

  LocalTags apply(LocalTags tags) => LocalTags(
    title: title,
    artist: artist,
    albumArtist: albumArtist,
    album: album,
    track: track,
    disc: disc,
    duration: tags.duration,
    year: year,
    genre: genre,
    bitRate: tags.bitRate,
    sampleRate: tags.sampleRate,
    picture: tags.picture,
  );
}
