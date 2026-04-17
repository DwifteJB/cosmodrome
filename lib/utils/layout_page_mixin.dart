import 'package:flutter/material.dart';
import 'package:cosmodrome/utils/layout_notifier.dart';

int _layoutGeneration = 0;

// mixin for the layout to replace elements
mixin LayoutPageMixin<T extends StatefulWidget> on State<T> {
  String? get pageTitle => null;
  List<TopbarButton> get pageButtons => const [];
  Widget Function(BuildContext)? get topBarBuilder => null;
  Widget Function(BuildContext)? get mainPillBuilder => null;
  Widget Function(BuildContext)? get searchPillBuilder => null;
  bool get hidePill => false;

  int _myGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _myGeneration = ++_layoutGeneration;
      layoutConfig.value = LayoutConfig(
        title: pageTitle,
        buttons: pageButtons,
        topBarBuilder: topBarBuilder,
        mainPillBuilder: mainPillBuilder,
        searchPillBuilder: searchPillBuilder,
        hidePill: hidePill,
      );
    });
  }

  @override
  void dispose() {
    final gen = _myGeneration;
    super.dispose();
    // only reset if we haven't already been replaced by another page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_layoutGeneration == gen) {
        layoutConfig.value = LayoutConfig.empty;
        _layoutGeneration = 0;
      }
    });
  }
}
