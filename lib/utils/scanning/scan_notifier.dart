import 'dart:async';

import 'package:cosmodrome/helpers/subsonic-api-helper/api/basic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:flutter/foundation.dart';

final ValueNotifier<bool> isScanningNotifier = ValueNotifier(false);

Timer? _scanPollTimer;

Future<void> startLibraryScan(Subsonic subsonic) async {
  if (isScanningNotifier.value) return;

  final result = await subsonic.startScan();
  if (result.errorMessage != null || !result.scanning) return;

  isScanningNotifier.value = true;
  _scanPollTimer?.cancel();
  _scanPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
    final status = await subsonic.getScanStatus();
    if (!status.scanning) {
      _scanPollTimer?.cancel();
      _scanPollTimer = null;
      isScanningNotifier.value = false;
    }
  });
}
