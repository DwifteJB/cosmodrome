import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool isMobile(BuildContext context) {
  return isMobileView(context);
}

bool isMobileView(BuildContext context) {
  // forced mobile via --dart-define FORCED_MOBILE=true
  if (const bool.fromEnvironment("FORCED_MOBILE", defaultValue: false)) {
    return true;
  }

  // only depend on MediaQuery when the width actually matters
  bool isNarrow() => MediaQuery.of(context).size.width < 768;

  // if web or in development, use width to determine
  if (kIsWeb || _isDevelopment()) return isNarrow();

  // if android/ios always yes
  if (Platform.isAndroid || Platform.isIOS) return true;

  // if desktop but small width & not in development, then we are NOT mobile
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) return false;

  return isNarrow();
}

bool _isDevelopment() {
  return false;
  // return kDebugMode || kProfileMode;
}
