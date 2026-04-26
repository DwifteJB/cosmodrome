import 'dart:async';

import 'package:flutter/foundation.dart';

final ValueNotifier<int> playlistsCountChanged = ValueNotifier(0);
final ValueNotifier<int> starredCountChanged = ValueNotifier(0);
final ValueNotifier<Completer<void>?> homeRefreshNotifier = ValueNotifier(null);

void notifyPlaylistsChanged() => playlistsCountChanged.value++;
void notifyStarredChanged() => starredCountChanged.value++;

Future<void> requestHomeRefresh() {
  final completer = Completer<void>();
  homeRefreshNotifier.value = completer;
  return completer.future;
}
