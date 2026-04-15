/*
indexses
<subsonic-response status="ok" version="1.10.1">
<indexes lastModified="237462836472342" ignoredArticles="The El La Los Las Le Les">
<shortcut id="11" name="Audio books"/>
<shortcut id="10" name="Podcasts"/>
<index name="A">
<artist id="1" name="ABBA"/>
<artist id="2" name="Alanis Morisette"/>
<artist id="3" name="Alphaville" starred="2013-11-02T12:30:00"/>
</index>
<index name="B">
<artist name="Bob Dylan" id="4"/>
</index>
<child id="111" parent="11" title="Dancing Queen" isDir="false" album="Arrival" artist="ABBA" track="7" year="1978" genre="Pop" coverArt="24" size="8421341" contentType="audio/mpeg" suffix="mp3" duration="146" bitRate="128" path="ABBA/Arrival/Dancing Queen.mp3"/>
<child id="112" parent="11" title="Money, Money, Money" isDir="false" album="Arrival" artist="ABBA" track="7" year="1978" genre="Pop" coverArt="25" size="4910028" contentType="audio/flac" suffix="flac" transcodedContentType="audio/mpeg" transcodedSuffix="mp3" duration="208" bitRate="128" path="ABBA/Arrival/Money, Money, Money.mp3"/>
</indexes>
</subsonic-response
*/

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
  String id;
  String name;

  MusicFolder({required this.id, required this.name});

  factory MusicFolder.fromJson(Map<String, dynamic> json) {
    return MusicFolder(id: json['id'] as String, name: json['name'] as String);
  }
}

class Shortcut {
  String id;
  String name;

  Shortcut({required this.id, required this.name});

  factory Shortcut.fromJson(Map<String, dynamic> json) {
    return Shortcut(id: json['id'] as String, name: json['name'] as String);
  }
}
