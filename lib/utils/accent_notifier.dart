import 'package:flutter/material.dart';

/// shared notifier for main_layout to listen for accent colour changes (and animate)
final ValueNotifier<Color?> accentColorNotifier = ValueNotifier(null);
