import 'package:flutter/material.dart';

Color derivedAccentColor(String key) {
  if (key.isEmpty) return const Color(0xFF5B7CFF);

  final hash = key.hashCode & 0x7fffffff;
  final hue = (hash % 360).toDouble();
  final saturation = 0.52 + (((hash >> 8) & 0x1f) / 100.0);
  final lightness = 0.42 + (((hash >> 13) & 0x1f) / 120.0);

  return HSLColor.fromAHSL(
    1.0,
    hue,
    saturation.clamp(0.45, 0.72),
    lightness.clamp(0.35, 0.58),
  ).toColor();
}