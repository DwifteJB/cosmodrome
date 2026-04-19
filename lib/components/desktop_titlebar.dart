import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:window_manager/window_manager.dart';

class DesktopTitlebar extends StatefulWidget {
  final bool showWindowControls;
  final bool canGoBack;
  final VoidCallback? onBack;
  final bool queueOpen;
  final VoidCallback? onToggleQueue;

  const DesktopTitlebar({
    super.key,
    this.showWindowControls = true,
    this.canGoBack = false,
    this.onBack,
    this.queueOpen = false,
    this.onToggleQueue,
  });

  @override
  State<DesktopTitlebar> createState() => _DesktopTitlebarState();
}

class _DesktopTitlebarState extends State<DesktopTitlebar> with WindowListener {
  bool _isMaximized = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final isMacOS = !kIsWeb && Platform.isMacOS;

    return Container(
      height: 32,
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
            ),
          ),

          // back button (to change?)
          if (widget.canGoBack)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _TitlebarButton(
                  icon: FIcons.chevronLeft,
                  onPressed: widget.onBack ?? () {},
                ),
              ),
            ),

          // on the right, queue & window controls
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // queue toggle top right
                _TitlebarButton(
                  icon: FIcons.listMusic,
                  onPressed: widget.onToggleQueue ?? () {},
                  active: widget.queueOpen,
                ),
                if (!isMacOS && widget.showWindowControls) ...[
                  DesktopWindowButton(
                    icon: FIcons.minus,
                    iconSize: 16,
                    onPressed: () => windowManager.minimize(),
                    hoverColor: theme.colors.secondary,
                  ),
                  DesktopWindowButton(
                    icon: _isMaximized ? FIcons.copy : FIcons.square,
                    iconSize: 14,
                    onPressed: () async {
                      if (await windowManager.isMaximized()) {
                        windowManager.unmaximize();
                      } else {
                        windowManager.maximize();
                      }
                    },
                    hoverColor: theme.colors.secondary,
                  ),
                  DesktopWindowButton(
                    icon: FIcons.x,
                    iconSize: 16,
                    onPressed: () => windowManager.close(),
                    hoverColor: theme.colors.destructive,
                    hoverIconColor: Colors.white,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _init();
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  Future<void> _init() async {
    _isMaximized = await windowManager.isMaximized();
    setState(() {});
  }
}

/// Small icon button for titlebar actions (back, queue toggle).
class _TitlebarButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;

  const _TitlebarButton({
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  @override
  State<_TitlebarButton> createState() => _TitlebarButtonState();
}

class _TitlebarButtonState extends State<_TitlebarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final color = widget.active
        ? theme.colors.primary
        : (_isHovered ? theme.colors.foreground : theme.colors.mutedForeground);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
          width: 36,
          height: 32,
          color: Colors.transparent,
          child: Center(child: Icon(widget.icon, size: 16, color: color)),
        ),
      ),
    );
  }
}

class DesktopWindowButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback onPressed;
  final Color hoverColor;
  final Color? hoverIconColor;

  const DesktopWindowButton({
    super.key,
    required this.icon,
    required this.iconSize,
    required this.onPressed,
    required this.hoverColor,
    this.hoverIconColor,
  });

  @override
  State<DesktopWindowButton> createState() => _DesktopWindowButtonState();
}

class _DesktopWindowButtonState extends State<DesktopWindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 40,
          color: _isHovered ? widget.hoverColor : Colors.transparent,
          child: Center(
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: _isHovered && widget.hoverIconColor != null
                  ? widget.hoverIconColor
                  : theme.colors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}
