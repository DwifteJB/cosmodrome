import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool isMobile(BuildContext context) {
  return isMobileView(context);
}

bool isMobileView(BuildContext context) {
  if (!kIsWeb && !_isDevelopment() && (Platform.isAndroid || Platform.isIOS)) {
    return true;
  }

  if (!kIsWeb &&
      !_isDevelopment() &&
      (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    return false;
  }

  return MediaQuery.of(context).size.width < 768;
}

bool _isDevelopment() {
  return false;
  // return kDebugMode || kProfileMode;
}
