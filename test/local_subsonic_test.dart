import 'dart:io';

import 'package:cosmodrome/helpers/subsonic-api-helper/api/basic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/providers/subsonic_account.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/services/local_music/local_music_service.dart';
import 'package:cosmodrome/services/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'fakes/fake_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String musicDir;
  late SubsonicProvider provider;

  Subsonic api() => provider.subsonic;

  Future<void> writeFile(String name) async {
    final file = File('$musicDir/$name');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List.filled(64, 0));
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('cosmodrome-local-api');
    PathProviderPlatform.instance = FakePathProvider(tempDir.path);
    await LocalStorageService.init();
    musicDir = LocalStorageService.localMusicDirectory!;
    provider = SubsonicProvider()..debugUseAccount(SubsonicAccount.local());
    await localMusicService.init();
    localMusicService.bind(provider);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    final dir = Directory(musicDir);
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    await LocalStorageService.clearAccountCache('local');
    provider.debugUseAccount(SubsonicAccount.local());
    await writeFile('Band/First Album/01 - Opener.mp3');
    await writeFile('Band/First Album/02 - Closer.mp3');
    await writeFile('Singer/Solo/01 - Alone.mp3');
    await localMusicService.scan();
  });

  test('local account answers like a server', () async {
    expect((await api().ping()).success, isTrue);
    expect(api().isLocal, isTrue);
    expect(provider.activeAccount!.isLocal, isTrue);
  });

  test('groups local files into albums and artists', () async {
    final artists = await api().getArtists();
    expect(artists.map((a) => a.name), ['Band', 'Singer']);

    final albums = await api().getArtist(artists.first.id);
    expect(albums.single.name, 'First Album');

    final album = await api().getAlbum(albums.single.id);
    expect(album!.songs.map((s) => s.title), ['Opener', 'Closer']);
    expect(album.songs.every((s) => s.albumId == album.id), isTrue);

    final song = localMusicService.song(album.songs.first.id)!;
    expect(song.albumId, album.id);
  });

  test('album lists, search and random songs', () async {
    final all = await api().getAlbumList2('alphabeticalByName', size: 10);
    expect(all.map((a) => a.name), ['First Album', 'Solo']);

    final result = await api().search3('alone');
    expect(result.songs.single.title, 'Alone');
    expect(result.albums, isEmpty);

    final songs = await api().searchThreeSongs();
    expect(songs.length, 3);

    expect((await api().getRandomSongs(count: 2)).length, 2);
  });

  test('playlists live inside the local account', () async {
    final songs = await api().searchThreeSongs();
    final id = await api().createNewPlaylist('mix');
    expect(id, startsWith(localPlaylistPrefix));

    for (final song in songs) {
      await api().updatePlaylist(playlistId: id!, songIdToAdd: song.id);
    }
    await api().updatePlaylist(playlistId: id!, songIndexToRemove: 0);
    var playlist = await api().getPlaylist(id);
    expect(playlist!.songs.map((s) => s.id), songs.skip(1).map((s) => s.id));

    await api().replacePlaylistSongs(id, [songs.first.id, songs.last.id]);
    await api().updatePlaylist(playlistId: id, name: 'renamed');

    provider.debugUseAccount(SubsonicAccount.local());
    playlist = await api().getPlaylist(id);
    expect(playlist!.name, 'renamed');
    expect(playlist.songs.map((s) => s.id), [songs.first.id, songs.last.id]);
    expect((await api().getPlaylists()).single.songCount, 2);
  });

  test('stars songs and albums', () async {
    final album = (await api().getAlbumList2('newest')).first;
    final song = (await api().getAlbum(album.id))!.songs.first;

    expect(await api().starAlbum(album.id), isTrue);
    expect(await api().starSong(song.id), isTrue);

    final starred = await api().getAlbumList2('starred');
    expect(starred.single.id, album.id);
    expect((await api().getSong(song.id))!.starred, isNotNull);

    expect(await api().unstarSong(song.id), isTrue);
    expect((await api().getSong(song.id))!.starred, isNull);
  });
}
