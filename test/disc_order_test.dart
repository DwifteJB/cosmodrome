import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/utils/disc_order.dart';
import 'package:flutter_test/flutter_test.dart';

Song song(String id, {int? track, int? disc}) =>
    Song(id: id, title: id, track: track, discNumber: disc);

void main() {
  test('orders by disc then track', () {
    final songs = [
      song('d2t1', track: 1, disc: 2),
      song('d1t2', track: 2, disc: 1),
      song('d2t2', track: 2, disc: 2),
      song('d1t1', track: 1, disc: 1),
    ];
    orderSongsByDisc(songs);
    expect(songs.map((s) => s.id), ['d1t1', 'd1t2', 'd2t1', 'd2t2']);
  });

  test('keeps server order when nothing is numbered', () {
    final songs = [song('c'), song('a'), song('b')];
    orderSongsByDisc(songs);
    expect(songs.map((s) => s.id), ['c', 'a', 'b']);
  });

  test('single disc albums are left alone', () {
    final songs = [
      song('a', track: 1),
      song('b', track: 2),
      song('c', track: 3),
    ];
    orderSongsByDisc(songs);
    expect(songs.map((s) => s.id), ['a', 'b', 'c']);
    expect(hasMultipleDiscs(songs), isFalse);
  });

  test('detects multiple discs', () {
    expect(hasMultipleDiscs([song('a', disc: 1), song('b', disc: 2)]), isTrue);
    expect(hasMultipleDiscs([song('a'), song('b', disc: 1)]), isFalse);
  });
}
