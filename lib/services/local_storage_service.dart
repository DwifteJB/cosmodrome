import 'dart:io';
import 'package:cosmodrome/utils/logger.dart';
import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  static String? _basePath;

  static Future<void> init() async {
    // base directory
    // on linux this is XDG_DOCUMENTS_DIR
    // windows usually %USERPROFILE%\Documents
    // ios is NSDocumentDirectory
    // macos also NSDocumentDirectory
    // android it is /data/data/me.rmfosho.cosmodrome/
    
    final dir = await getApplicationDocumentsDirectory();
    loggerPrint("STORAGE: using directory ${dir.path} for local storage");
    _basePath = '${dir.path}/cosmodrome';
  }

  static String get _base {
    assert(_basePath != null, 'LocalStorageService.init() not called');
    return _basePath!;
  }

  static String songPath(String accountId, String songId, String suffix) =>
      '$_base/$accountId/songs/$songId.$suffix';

  static String metaPath(String accountId, String key) =>
      '$_base/$accountId/cache/$key.json';

  static Future<void> ensureDirs(String accountId) async {
    await Directory('$_base/$accountId/songs').create(recursive: true);
    await Directory('$_base/$accountId/cache').create(recursive: true);
  }

  static Future<int> accountStorageBytes(String accountId) async {
    final dir = Directory('$_base/$accountId/songs');
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }
}
