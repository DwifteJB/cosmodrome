import 'package:cosmodrome/components/album_card.dart';
import 'package:cosmodrome/components/music-pages/track_tile.dart';
import 'package:cosmodrome/main.dart' as app;
import 'package:cosmodrome/pages/album_page.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
  String what = 'condition',
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) fail('timed out waiting for $what');
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('browse an album, resize, play and skip', (tester) async {
    app.main();
    await tester.pump(const Duration(seconds: 2));

    await pumpUntil(
      tester,
      () => find
          .byWidgetPredicate(
            (w) => w is AlbumCard && !w.album.id.startsWith('fake_'),
          )
          .evaluate()
          .isNotEmpty,
      what: 'an album on the home page (is an account signed in?)',
    );

    final card = find.byWidgetPredicate(
      (w) => w is AlbumCard && !w.album.id.startsWith('fake_'),
    );
    final albumId = (tester.widget(card.first) as AlbumCard).album.id;
    app.router.push('/library/album/$albumId');
    await tester.pump(const Duration(milliseconds: 500));

    await pumpUntil(
      tester,
      () => find.byType(MusicPageDesktopTrackTile).evaluate().isNotEmpty,
      what: 'album tracks',
    );

    // the crash from the report: constraints changing under the album page
    final size = await windowManager.getSize();
    await windowManager.setSize(Size(size.width + 200, size.height));
    await tester.pump(const Duration(seconds: 1));
    await windowManager.setSize(Size(size.width - 100, size.height));
    await tester.pump(const Duration(seconds: 1));
    await windowManager.setSize(size);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    final context = tester.element(find.byType(AlbumPage));
    final player = Provider.of<PlayerProvider>(context, listen: false);

    final tile = find.byType(MusicPageDesktopTrackTile).first;
    await tester.ensureVisible(tile);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(tile);
    await tester.pump(const Duration(milliseconds: 500));
    expect(player.currentSong, isNotNull);
    final first = player.currentSong!.id;

    await pumpUntil(
      tester,
      () => player.isPlaying && player.position > const Duration(seconds: 1),
      timeout: const Duration(seconds: 120),
      what: 'the first track to start playing',
    );

    await player.skipNext();
    await pumpUntil(
      tester,
      () =>
          player.currentSong != null &&
          player.currentSong!.id != first &&
          player.isPlaying &&
          player.position > const Duration(seconds: 1),
      timeout: const Duration(seconds: 120),
      what: 'the second track to start playing',
    );

    expect(player.currentIndex, 1);
    expect(tester.takeException(), isNull);
  });
}
