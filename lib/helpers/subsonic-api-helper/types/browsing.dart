// TYPES FOR BROWSING-RELATED SUBSONIC API RESPONSES
class Index {
  String name;
  List<IndexArtist> artists;

  Index({required this.name, required this.artists});

  factory Index.fromJson(Map<String, dynamic> json) {
    final artistsJson = json['artist'] as List<dynamic>? ?? [];
    final artists = artistsJson
        .map(
          (artistJson) =>
              IndexArtist.fromJson(artistJson as Map<String, dynamic>),
        )
        .toList();
    return Index(name: json['name'] as String, artists: artists);
  }
}

class IndexArtist {
  String id;
  String name;
  DateTime? starred;

  IndexArtist({required this.id, required this.name, this.starred});

  factory IndexArtist.fromJson(Map<String, dynamic> json) {
    return IndexArtist(
      id: json['id'] as String,
      name: json['name'] as String,
      starred: json.containsKey('starred')
          ? DateTime.parse(json['starred'] as String)
          : null,
    );
  }
}


class IndexesResponse {
  List<Index> indexes;
  List<MusicFolder> musicFolders;

  IndexesResponse({required this.indexes, required this.musicFolders});

  factory IndexesResponse.fromJson(Map<String, dynamic> json) {
    final indexesJson = json['indexes']['index'] as List<dynamic>? ?? [];
    final indexes = indexesJson
        .map((indexJson) => Index.fromJson(indexJson as Map<String, dynamic>))
        .toList();

    final musicFoldersJson =
        json['musicFolders']['musicFolder'] as List<dynamic>? ?? [];
    final musicFolders = musicFoldersJson
        .map(
          (folderJson) =>
              MusicFolder.fromJson(folderJson as Map<String, dynamic>),
        )
        .toList();

    return IndexesResponse(indexes: indexes, musicFolders: musicFolders);
  }
}

class MusicFolder {
  int id;
  String name;

  MusicFolder({required this.id, required this.name});

  factory MusicFolder.fromJson(Map<String, dynamic> json) {
    return MusicFolder(id: json['id'] as int, name: json['name'] as String);
  }
}

class Shortcut {
  int id;
  String name;

  Shortcut({required this.id, required this.name});

  factory Shortcut.fromJson(Map<String, dynamic> json) {
    return Shortcut(id: json['id'] as int, name: json['name'] as String);
  }
}

class Album {
  final String id;
  final String name;
  final String artist;
  final String? artistId;
  final String? coverArt;
  final int songCount;
  final int duration;
  final int? year;
  final String? genre;
  final DateTime? starred;

  Album({
    required this.id,
    required this.name,
    required this.artist,
    this.artistId,
    this.coverArt,
    required this.songCount,
    required this.duration,
    this.year,
    this.genre,
    this.starred,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as String,
      name: json['name'] as String,
      artist: json['artist'] as String? ?? '',
      artistId: json['artistId'] as String?,
      coverArt: json['coverArt'] as String?,
      songCount: (json['songCount'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt(),
      genre: json['genre'] as String?,
      starred: json['starred'] != null
          ? DateTime.tryParse(json['starred'] as String)
          : null,
    );
  }
}

class Song {
  final String id;
  final String title;
  final String? artist;
  final String? album;
  final int? track;
  final int? duration;
  final String? coverArt;

  Song({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.track,
    this.duration,
    this.coverArt,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      track: (json['track'] as num?)?.toInt(),
      duration: (json['duration'] as num?)?.toInt(),
      coverArt: json['coverArt'] as String?,
    );
  }
}

class AlbumDetail extends Album {
  final List<Song> songs;

  AlbumDetail({
    required super.id,
    required super.name,
    required super.artist,
    super.artistId,
    super.coverArt,
    required super.songCount,
    required super.duration,
    super.year,
    super.genre,
    super.starred,
    required this.songs,
  });

  factory AlbumDetail.fromJson(Map<String, dynamic> json) {
    final songsJson = json['song'] as List<dynamic>? ?? [];
    final songs = songsJson
        .map((s) => Song.fromJson(s as Map<String, dynamic>))
        .toList();
    return AlbumDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      artist: json['artist'] as String? ?? '',
      artistId: json['artistId'] as String?,
      coverArt: json['coverArt'] as String?,
      songCount: (json['songCount'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt(),
      genre: json['genre'] as String?,
      starred: json['starred'] != null
          ? DateTime.tryParse(json['starred'] as String)
          : null,
      songs: songs,
    );
  }
}
