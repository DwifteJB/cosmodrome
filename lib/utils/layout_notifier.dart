import 'package:flutter/material.dart';

class TopbarButton {
  final IconData icon;
  final VoidCallback onPressed;

  const TopbarButton({required this.onPressed, required this.icon});
}

class LayoutConfig {
  final String? title;
  final List<TopbarButton> buttons;
  final Widget Function(BuildContext)? topBarBuilder;
  final Widget Function(BuildContext)? mainPillBuilder;
  final Widget Function(BuildContext)? searchPillBuilder;
  final bool hidePill;

  const LayoutConfig({
    this.title,
    this.buttons = const [],
    this.topBarBuilder,
    this.mainPillBuilder,
    this.searchPillBuilder,
    this.hidePill = false,
  });

  static const empty = LayoutConfig();
}

final ValueNotifier<LayoutConfig> layoutConfig = ValueNotifier(
  LayoutConfig.empty,
);
