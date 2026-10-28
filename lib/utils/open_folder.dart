// hacky as web cannot open folders, ios needs special url scheme

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

bool get canOpenFolders =>
    !kIsWeb &&
    (Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows ||
        Platform.isLinux);

Future<bool> openFolder(String path) async {
  if (!canOpenFolders) return false;
  try {
    await Directory(path).create(recursive: true);
    final uri = Platform.isIOS
        ? Uri.parse('shareddocuments://${Uri.directory(path).path}')
        : Uri.directory(path);
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
