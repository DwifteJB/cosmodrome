import 'package:flutter/foundation.dart';

final ValueNotifier<int> playlistsSidebarVersion = ValueNotifier(0);
final ValueNotifier<int> starredSidebarVersion = ValueNotifier(0);

void notifyPlaylistsChanged() => playlistsSidebarVersion.value++;
void notifyStarredChanged() => starredSidebarVersion.value++;
