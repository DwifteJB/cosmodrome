import 'package:flutter/material.dart';

/// shared notifier for main_layout to listen for accent colour changes (and animate)
final ValueNotifier<Color?> accentColorNotifier = ValueNotifier(null);

/// shared notifier for the current album cover URL (used for desktop blurred background)
final ValueNotifier<String?> coverUrlNotifier = ValueNotifier(null);
