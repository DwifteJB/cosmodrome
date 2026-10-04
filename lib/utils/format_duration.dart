/// Formats a track length as `m:ss`, e.g. `3:07`.
String formatTrackDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
