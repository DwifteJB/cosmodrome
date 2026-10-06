import 'dart:io';

import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/subsonic-user.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_account.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/services/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'fakes/fake_just_audio.dart';
import 'fakes/fake_path_provider.dart';

Song song(String id) => Song(id: id, title: 'song $id', albumId: 'album');

List<String> ids(Iterable<Song> songs) => songs.map((s) => s.id).toList();

Future<void> settle([int ms = 60]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeJustAudio platform;
  late PlayerProvider player;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('cosmodrome-test');
    PathProviderPlatform.instance = FakePathProvider(tempDir.path);
    await LocalStorageService.init();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  setUp(() {
    platform = FakeJustAudio();
    JustAudioPlatform.instance = platform;
    final subsonic = SubsonicProvider()
      ..debugUseAccount(
        SubsonicAccount(
          baseUrl: '127.0.0.1:9',
          username: 'tester',
          password: 'pw',
          user: SubsonicUser(username: 'tester'),
          loginMethod: SubsonicLoginMethod.token,
        ),
      );
    player = PlayerProvider(
      player: AudioPlayer(
        handleAudioSessionActivation: false,
        androidApplyAudioAttributes: false,
      ),
    )..update(subsonic);
  });

  tearDown(() async {
    player.dispose();
    await settle();
  });

  FakeAudioPlayer native() => platform.last!;

  test('playAlbum loads the whole album at the chosen track', () async {
    await player.playAlbum([song('a'), song('b'), song('c')], startIndex: 1);
    await settle();
    expect(native().songIds, ['a', 'b', 'c']);
    expect(native().currentIndex, 1);
    expect(player.currentSong?.id, 'b');
    expect(native().playing, isTrue);
  });

  test('adding to the queue appends without reloading', () async {
    await player.playAlbum([song('a'), song('b')]);
    await settle();
    await player.addBulkToQueue([song('c'), song('d')]);
    await settle();
    expect(native().loads, 1);
    expect(native().songIds, ['a', 'b', 'c', 'd']);
    expect(ids(player.queue), ['a', 'b', 'c', 'd']);
  });

  test(
    'removing before the current song keeps the same song current',
    () async {
      await player.playAlbum([song('a'), song('b'), song('c')], startIndex: 2);
      await settle();
      await player.removeFromQueue(0);
      await settle();
      expect(ids(player.queue), ['b', 'c']);
      expect(native().songIds, ['b', 'c']);
      expect(player.currentSong?.id, 'c');
      expect(native().currentIndex, 1);
      expect(native().loads, 1);
    },
  );

  test('reordering mirrors into the player playlist', () async {
    await player.playAlbum([song('a'), song('b'), song('c'), song('d')]);
    await settle();
    player.reorderQueue(3, 1);
    await settle();
    expect(ids(player.queue), ['a', 'd', 'b', 'c']);
    expect(native().songIds, ['a', 'd', 'b', 'c']);
    expect(player.currentSong?.id, 'a');
    expect(native().currentIndex, 0);
  });

  test('shuffle physically reorders and restores', () async {
    final songs = [for (var i = 0; i < 8; i++) song('$i')];
    await player.playAlbum(songs, startIndex: 3);
    await settle();
    await player.toggleShuffle();
    await settle();
    expect(player.shuffle, isTrue);
    expect(player.currentSong?.id, '3');
    expect(player.currentIndex, 0);
    expect(ids(player.queue).toSet(), ids(songs).toSet());
    expect(native().songIds, ids(player.queue));
    expect(native().currentIndex, 0);
    expect(native().loads, 1);

    await player.toggleShuffle();
    await settle();
    expect(player.shuffle, isFalse);
    expect(ids(player.queue), ids(songs));
    expect(native().songIds, ids(songs));
    expect(player.currentSong?.id, '3');
    expect(native().currentIndex, 3);
  });

  test('a track change during a queue edit is not lost', () async {
    await player.playAlbum([song('a'), song('b')]);
    await settle();
    final pending = player.addBulkToQueue([
      for (var i = 0; i < 20; i++) song('x$i'),
    ]);
    native().advance();
    await pending;
    await settle();
    expect(player.currentSong?.id, 'b');
    expect(player.currentIndex, 1);
  });

  test('playNow inserts before the current song and switches to it', () async {
    await player.playAlbum([song('a'), song('b'), song('c')], startIndex: 1);
    await settle();
    await player.playNow(song('n'));
    await settle();
    expect(ids(player.queue), ['a', 'n', 'b', 'c']);
    expect(native().songIds, ['a', 'n', 'b', 'c']);
    expect(player.currentSong?.id, 'n');
    expect(native().currentIndex, 1);
    expect(native().playing, isTrue);
    expect(native().loads, 1);
  });

  test('skipNext and skipToQueueIndex move the player', () async {
    await player.playAlbum([song('a'), song('b'), song('c')]);
    await settle();
    await player.skipNext();
    await settle();
    expect(player.currentSong?.id, 'b');
    expect(native().currentIndex, 1);
    await player.skipToQueueIndex(2);
    await settle();
    expect(player.currentSong?.id, 'c');
    expect(native().currentIndex, 2);
  });

  test('repeat wraps to the first song at the end', () async {
    await player.playAlbum([song('a'), song('b')], startIndex: 1);
    await settle();
    await player.toggleRepeat();
    await player.toggleRepeat();
    expect(player.repeatMode, LoopMode.all);
    await player.skipNext();
    await settle();
    expect(player.currentSong?.id, 'a');
    expect(native().currentIndex, 0);
  });

  test('removing the current song plays what took its place', () async {
    await player.playAlbum([song('a'), song('b'), song('c')], startIndex: 1);
    await settle();
    await player.removeFromQueue(1);
    await settle();
    expect(ids(player.queue), ['a', 'c']);
    expect(player.currentSong?.id, 'c');
    expect(native().songIds, ['a', 'c']);
    expect(native().currentIndex, 1);
  });

  test('resetQueue clears everything', () async {
    await player.playAlbum([song('a'), song('b')]);
    await settle();
    await player.resetQueue();
    expect(player.queue, isEmpty);
    expect(player.currentSong, isNull);
    await player.playNow(song('z'));
    await settle();
    expect(player.currentSong?.id, 'z');
    expect(native().songIds, ['z']);
  });
}
