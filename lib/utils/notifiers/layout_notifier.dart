import 'package:flutter/material.dart';

class TopbarButton {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  const TopbarButton({
    required this.onPressed,
    required this.icon,
    this.color = Colors.white,
  });
}

class LayoutConfig {
  final String? title;
  final List<TopbarButton> buttons;
  final Widget Function(BuildContext)? mainPillBuilder;
  final Widget Function(BuildContext)? searchPillBuilder;
  final bool hidePill;
  // whether the main content should be wrapped in a scroll view (with padding) or not. if false, the page is responsible for its own scrolling and padding.
  final bool isScrollable;

  const LayoutConfig({
    this.title,
    this.buttons = const [],
    this.mainPillBuilder,
    this.searchPillBuilder,
    this.hidePill = false,
    this.isScrollable = true,
  });

  static const empty = LayoutConfig();
}

final ValueNotifier<LayoutConfig> layoutConfig = ValueNotifier(
  LayoutConfig.empty,
);

final ValueNotifier<bool> detailPageActive = ValueNotifier(false);
