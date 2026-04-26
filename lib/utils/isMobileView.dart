import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool isMobile(BuildContext context) {
  return isMobileView(context);
}

bool isMobileView(BuildContext context) {
  if (kIsWeb && MediaQuery.of(context).size.width < 768) {
    return true;
  }

  // if android/ios always yes
  if (!kIsWeb && !_isDevelopment() && (Platform.isAndroid || Platform.isIOS)) {
    return true;
  }

  // if desktop but small width & not in development, then we are NOT mobile
  if (!kIsWeb &&
      !_isDevelopment() &&
      (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    return false;
  }

  // if web or in development, use width to determine
  return MediaQuery.of(context).size.width < 768;
}

bool _isDevelopment() {
  return false;
  // return kDebugMode || kProfileMode;
}
