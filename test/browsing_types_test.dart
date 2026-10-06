import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('song keeps disc number through json', () {
    final song = Song.fromJson({
      'id': '1',
      'title': 'x',
      'track': 3,
      'discNumber': 2,
    });
    expect(song.discNumber, 2);
    expect(song.track, 3);
    expect(Song.fromJson(song.toJson()).discNumber, 2);
  });

  test('song keeps artist id through json', () {
    final song = Song.fromJson({'id': '1', 'title': 'x', 'artistId': 'ar-1'});
    expect(song.artistId, 'ar-1');
    expect(Song.fromJson(song.toJson()).artistId, 'ar-1');
  });

  test('artist detail parses albums and image', () {
    final artist = ArtistDetail.fromJson({
      'id': 'ar-1',
      'name': 'artist',
      'coverArt': 'ar-1',
      'artistImageUrl': ' ',
      'musicBrainzId': 'mb-1',
      'starred': '2026-01-01T00:00:00Z',
      'album': [
        {'id': 'a', 'name': 'one', 'year': 2020},
        {'id': 'b', 'name': 'two', 'year': 2024},
      ],
    });
    expect(artist.albumCount, 2);
    expect(artist.albums.map((a) => a.id), ['a', 'b']);
    expect(artist.artistImageUrl, isNull);
    expect(artist.musicBrainzId, 'mb-1');
    expect(artist.starred, isNotNull);
  });

  test('artist info accepts a single similar artist', () {
    final info = ArtistInfo.fromJson({
      'biography': 'bio',
      'mediumImageUrl': 'http://img',
      'similarArtist': {'id': 'ar-2', 'name': 'other'},
    });
    expect(info.imageUrl, 'http://img');
    expect(info.similarArtists.single.id, 'ar-2');
  });

  test('album detail parses disc titles', () {
    final album = AlbumDetail.fromJson({
      'id': 'a',
      'name': 'album',
      'songCount': 2,
      'duration': 100,
      'discTitles': [
        {'disc': 1, 'title': 'Side A'},
        {'disc': 2, 'title': 'Side B'},
        {'disc': 3, 'title': ''},
      ],
      'song': [
        {'id': '1', 'title': 'one', 'discNumber': 1, 'track': 1},
        {'id': '2', 'title': 'two', 'discNumber': 2, 'track': 1},
      ],
    });
    expect(album.discTitles, {1: 'Side A', 2: 'Side B'});
    expect(album.songs.map((s) => s.discNumber), [1, 2]);
    final json = album.toJson();
    expect(AlbumDetail.fromJson(json).discTitles, album.discTitles);
  });
}
