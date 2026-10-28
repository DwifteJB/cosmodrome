import 'dart:io';

import 'package:cosmodrome/services/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'fakes/fake_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ensure that old downloads r moved to new downloads dir
  test('old downloads move into the downloaded folder', () async {
    final tempDir = await Directory.systemTemp.createTemp('cosmodrome-migrate');
    addTearDown(() => tempDir.delete(recursive: true));

    const accountId = 'tester@host';
    final legacy = File('${tempDir.path}/cosmodrome/$accountId/songs/abc.mp3');
    await legacy.create(recursive: true);
    await legacy.writeAsString('audio');
    final meta = File('${tempDir.path}/cosmodrome/$accountId/cache/x.json');
    await meta.create(recursive: true);

    PathProviderPlatform.instance = FakePathProvider(tempDir.path);
    await LocalStorageService.init();

    final moved = LocalStorageService.songPath(accountId, 'abc', 'mp3');
    expect(moved, startsWith(LocalStorageService.downloadsDirectory!));
    expect(await File(moved).readAsString(), 'audio');
    expect(await legacy.exists(), isFalse);
    expect(
      await File(LocalStorageService.metaPath(accountId, 'x')).exists(),
      isTrue,
    );
  });
}
