import 'package:flutter/material.dart';
import 'package:cosmodrome/utils/notifiers/layout_notifier.dart';

final _pages = <LayoutPageMixin>[];

// mixin for the layout to replace elements
mixin LayoutPageMixin<T extends StatefulWidget> on State<T> {
  String? get pageTitle => null;
  List<TopbarButton> get pageButtons => const [];
  Widget Function(BuildContext)? get mainPillBuilder => null;
  Widget Function(BuildContext)? get searchPillBuilder => null;
  bool get hidePill => false;
  bool get isScrollable => true;
  bool get ignoreTopSpacing => false;

  LayoutConfig get _config => LayoutConfig(
    title: pageTitle,
    buttons: pageButtons,
    mainPillBuilder: mainPillBuilder,
    searchPillBuilder: searchPillBuilder,
    hidePill: hidePill,
    isScrollable: isScrollable,
    ignoreTopSpacing: ignoreTopSpacing,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pages.add(this);
      layoutConfig.value = _config;
    });
  }

  @override
  void dispose() {
    final wasTop = _pages.isNotEmpty && identical(_pages.last, this);
    _pages.remove(this);
    super.dispose();
    if (!wasTop) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      layoutConfig.value = _pages.isEmpty
          ? LayoutConfig.empty
          : _pages.last._config;
    });
  }
}
