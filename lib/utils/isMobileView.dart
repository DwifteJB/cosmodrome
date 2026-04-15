import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool isMobile(BuildContext context) {
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    return true;
  }
  return isMobileView(context);
}

bool isMobileView(BuildContext context) {
  return MediaQuery.of(context).size.width < 768;
}
