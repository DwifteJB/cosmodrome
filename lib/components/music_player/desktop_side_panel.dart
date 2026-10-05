import 'dart:io';

import 'package:cosmodrome/components/desktop/desktop_titlebar.dart';
import 'package:cosmodrome/components/music_player/desktop_lyrics_panel.dart';
import 'package:cosmodrome/components/music_player/desktop_queue_panel.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

enum DesktopSidePanelMode { queue, lyrics }

class DesktopSidePanel extends StatelessWidget {
  static const double width = 360;

  final DesktopSidePanelMode mode;
  final VoidCallback onClose;
  final double bottomInset;

  const DesktopSidePanel({
    super.key,
    required this.mode,
    required this.onClose,
    this.bottomInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final isMacOS = !kIsWeb && Platform.isMacOS;
    final accent =
        context.select<PlayerProvider, Color?>((p) => p.accentColor) ??
        colors.primary;
    final showGradient = mode == DesktopSidePanelMode.lyrics;

    return Material(
      color: AppColors.sidebar,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: colors.border, width: 1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      FIcons.x,
                      size: 14,
                      color: colors.mutedForeground,
                    ),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  const Spacer(),
                  // window controls move here while the panel is open
                  if (!kIsWeb && !isMacOS) ...[
                    DesktopWindowButton(
                      icon: FIcons.minus,
                      iconSize: 16,
                      onPressed: windowManager.minimize,
                      hoverColor: colors.secondary,
                    ),
                    DesktopWindowButton(
                      icon: FIcons.square,
                      iconSize: 14,
                      onPressed: windowManager.maximize,
                      hoverColor: colors.secondary,
                    ),
                    DesktopWindowButton(
                      icon: FIcons.x,
                      iconSize: 16,
                      onPressed: windowManager.close,
                      hoverColor: colors.destructive,
                      hoverIconColor: Colors.white,
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            accent.withValues(alpha: showGradient ? 0.10 : 0.0),
                            accent.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.6],
                        ),
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    layoutBuilder: _stackedLayout,
                    child: switch (mode) {
                      DesktopSidePanelMode.queue => DesktopQueuePanel(
                        key: const ValueKey(DesktopSidePanelMode.queue),
                        bottomInset: bottomInset,
                      ),
                      DesktopSidePanelMode.lyrics => DesktopLyricsPanel(
                        key: const ValueKey(DesktopSidePanelMode.lyrics),
                        bottomInset: bottomInset,
                      ),
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _stackedLayout(
    Widget? currentChild,
    List<Widget> previousChildren,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [...previousChildren, ?currentChild],
    );
  }
}
