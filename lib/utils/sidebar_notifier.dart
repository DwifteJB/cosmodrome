import 'package:flutter/foundation.dart';

final ValueNotifier<int> playlistsCountChanged = ValueNotifier(0);
final ValueNotifier<int> starredCountChanged = ValueNotifier(0);

void notifyPlaylistsChanged() => playlistsCountChanged.value++;
void notifyStarredChanged() => starredCountChanged.value++;
