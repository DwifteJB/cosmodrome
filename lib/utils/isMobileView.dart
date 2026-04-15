import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool isMobile(BuildContext context) {
  return isMobileView(context);
}

bool isMobileView(BuildContext context) {
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    return true;
  }

  return MediaQuery.of(context).size.width < 768;
}
