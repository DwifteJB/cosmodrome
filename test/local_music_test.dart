import 'dart:io';

import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/subsonic-user.dart';
import 'package:cosmodrome/providers/subsonic_account.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/services/local_music/local_music_service.dart';
import 'package:cosmodrome/services/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'fakes/fake_path_provider.dart';

// fake server playlist entry
Song server(String id) => Song(id: id, title: 'server $id', albumId: 'a');

// fake playlist
PlaylistDetail playlist(List<Song> songs) => PlaylistDetail(
  id: 'p1',
  name: 'mix',
  songCount: songs.length,
  duration: 0,
  owner: 'tester',
  songs: songs,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String musicDir;
  late LocalMusicService local;
  late SubsonicProvider subsonic;
  late String accountId;

  // test helper to write file in local music dir
  Future<void> writeFile(String name) async {
    final file = File('$musicDir/$name');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List.filled(64, 0));
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('cosmodrome-local');
    PathProviderPlatform.instance = FakePathProvider(tempDir.path);
    await LocalStorageService.init();
    musicDir = LocalStorageService.localMusicDirectory!;
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    final dir = Directory(musicDir);
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    subsonic = SubsonicProvider()
      // use a fake server that returns empty playlists and no songs
      ..debugUseAccount(
        SubsonicAccount(
          baseUrl: '127.0.0.1:9',
          username: 'tester',
          password: 'pw',
          user: SubsonicUser(username: 'tester'),
          loginMethod: SubsonicLoginMethod.token,
        ),
      );
    accountId = subsonic.activeAccount!.id;
    await LocalStorageService.clearAccountCache(accountId);
    local = LocalMusicService()..bind(subsonic);
    await local.init();
  });

  // test that local files find songs and not random files
  test('scan picks up files and falls back to folder names', () async {
    await writeFile('Some Artist/Some Album/03 - First Song.mp3');
    await writeFile('notes.txt');
    await local.scan();

    expect(local.count, 1);
    final song = local.songs.single;
    expect(song.title, 'First Song');
    expect(song.artist, 'Some Artist');
    expect(song.album, 'Some Album');
    expect(song.track, 3);
    expect(song.albumId, localFilesAlbumId);
    expect(isLocalSongId(song.id), isTrue);
  });

  test('rescan drops removed files and keeps ids stable', () async {
    await writeFile('a.mp3');
    await writeFile('b.flac');
    await local.scan();
    final ids = local.songs.map((s) => s.id).toSet();

    await File('$musicDir/b.flac').delete();
    await local.scan();

    expect(local.count, 1);
    expect(ids.contains(local.songs.single.id), isTrue);
  });

  // make sure the local files album is created and has all the songs in it
  test('local files album lists every local song', () async {
    await writeFile('x.mp3');
    await writeFile('y.mp3');
    await local.scan();

    final album = local.localFilesAlbum();
    expect(album.id, localFilesAlbumId);
    expect(album.name, 'Local Files');
    expect(album.songs.length, 2);
    expect(album.songs.map((s) => s.track), [1, 2]);
  });

  // ensure that local songs can be merged into remote playlists
  test('local songs merge into playlists at their position', () async {
    await writeFile('local.mp3');
    await local.scan();
    final localId = local.songs.single.id;
    final songs = [server('s0'), server('s1'), server('s2')];

    await local.addToPlaylist(accountId, 'p1', localId, 2);
    var merged = await local.mergePlaylist(accountId, playlist(songs));
    expect(merged.songs.map((s) => s.id), ['s0', 's1', localId, 's2']);
    expect(merged.songCount, 4);

    final serverIndex = await local.removeFromPlaylist(
      accountId,
      'p1',
      0,
      songs.length,
    );
    expect(serverIndex, 0);
    merged = await local.mergePlaylist(
      accountId,
      playlist([server('s1'), server('s2')]),
    );
    expect(merged.songs.map((s) => s.id), ['s1', localId, 's2']);

    final serverIds = await local.reorderPlaylist(accountId, 'p1', [
      localId,
      's2',
      's1',
    ]);
    expect(serverIds, ['s2', 's1']);
    merged = await local.mergePlaylist(
      accountId,
      playlist([server('s2'), server('s1')]),
    );
    expect(merged.songs.map((s) => s.id), [localId, 's2', 's1']);

    final handledLocally = await local.removeFromPlaylist(
      accountId,
      'p1',
      0,
      2,
    );
    expect(handledLocally, isNull);
    merged = await local.mergePlaylist(
      accountId,
      playlist([server('s2'), server('s1')]),
    );
    expect(merged.songs.map((s) => s.id), ['s2', 's1']);
  });

  // ensure that the local songs dont change pos
  test('playlist entries persist across service instances', () async {
    await writeFile('keep.mp3');
    await local.scan();
    final localId = local.songs.single.id;
    await local.addToPlaylist(accountId, 'p1', localId, 0);

    final again = LocalMusicService()..bind(subsonic);
    await again.init();
    final merged = await again.mergePlaylist(
      accountId,
      playlist([server('s0')]),
    );
    expect(merged.songs.map((s) => s.id), [localId, 's0']);
  });
}
