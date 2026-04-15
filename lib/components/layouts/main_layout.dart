// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:cosmodrome/components/desktop_titlebar.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:cosmodrome/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:gradient_blur/gradient_blur.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

const _navItems = [
  _NavItem(label: 'Home', route: '/home', icon: FIcons.house),
  _NavItem(label: 'Library', route: '/library', icon: FIcons.library),
  _NavItem(label: 'Example', route: '/example1', icon: FIcons.headphones),
  _NavItem(label: 'Search', route: '/search', icon: FIcons.search),
];

class MainLayout extends StatefulWidget {
  final Widget child;
  final String? selectedRoute;

  const MainLayout({super.key, required this.child, this.selectedRoute});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  double _topBlurOpacity = 0.0;

  late AnimationController aniu;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  Widget build(BuildContext context) {
    if (isMobileView(context)) {
      return _buildMobileLayout(context);
    }
    return _buildDesktopLayout(context);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    aniu.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    aniu = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scrollController.addListener(_onScroll);
  }

  Widget _buildBottomNav(BuildContext context) {
    final colors = context.theme.colors;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: 56 + bottomPadding,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _navItems.map((item) {
            final selected = _isSelected(item);
            if (item.route == '/new') {
              return GestureDetector(
                onTap: () => _navigateTo(item.route),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary,
                  ),
                  child: Icon(item.icon, size: 22, color: Colors.white),
                ),
              );
            }
            final color = selected ? colors.primary : colors.mutedForeground;
            return GestureDetector(
              onTap: () => _navigateTo(item.route),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 56,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, size: 22, color: color),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: context.theme.typography.xs.copyWith(color: color),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final colors = context.theme.colors;

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: AppLayout.sidebarWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.sidebar,
                border: Border(
                  right: BorderSide(color: colors.border, width: 1),
                ),
              ),
              child: FSidebar(
                style: .delta(
                  contentPadding: .add(
                    const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                header: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: _isDesktop
                          ? (_) => windowManager.startDragging()
                          : null,
                      onDoubleTap: _isDesktop
                          ? () async {
                              if (await windowManager.isMaximized()) {
                                await windowManager.unmaximize();
                              } else {
                                await windowManager.maximize();
                              }
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
                        child: FTextField(
                          hint: 'Search music...',
                          control: FTextFieldControl.managed(
                            controller: _searchController,
                          ),
                          prefixBuilder: (ctx, style, variants) =>
                              FTextField.prefixIconBuilder(
                                ctx,
                                style,
                                variants,
                                const Icon(FIcons.search),
                              ),
                        ),
                      ),
                    ),
                    const Divider(),
                  ],
                ),
                children: _navItems
                    .map(
                      (item) => FSidebarItem(
                        label: Text(item.label),
                        icon: Icon(item.icon, size: 20),
                        selected: _isSelected(item),
                        onPress: () => _navigateTo(item.route),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isDesktop) const DesktopTitlebar(),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    const navHeight = 80.0;
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Stack(
        children: [
          // actual content
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: (scrollNotification) {
                if (scrollNotification is ScrollUpdateNotification) {
                  _onScroll();
                }
                return true;
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    SizedBox(height: topPadding + 80),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            MediaQuery.of(context).size.height -
                            (topPadding + 80) -
                            (navHeight + bottomPadding),
                      ),
                      child: widget.child,
                    ),
                    SizedBox(height: navHeight + bottomPadding),
                  ],
                ),
              ),
            ),
          ),
          // bottom gradient blur (above content, below nav)
          Positioned(
            left: 0,
            right: 0,
            bottom: -bottomPadding - 10,
            child: GradientBlur(
              maxBlur: 15,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.black],
                stops: const [0.0, 1],
              ),
              child: Container(width: screenWidth, height: navHeight + topPadding, decoration: BoxDecoration(border: .fromLTRB(top: BorderSide(width: 2))),),
            ),
          ),
          // top gradient blur (above content)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: FadeTransition(
                opacity: aniu.drive(CurveTween(curve: Curves.easeOut)),
                child: GradientBlur(
                  maxBlur: 15,
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                      Colors.black,
                    ],
                    stops: const [0, 0.7, 1],
                  ),
                  child: SizedBox(width: screenWidth, height: topPadding + 56),
                ),
              ),
            ),
          ),
          // top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildMobileTopBar(context),
          ),
          // bottom nav
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNav(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTopBar(BuildContext context) {
    final colors = context.theme.colors;
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      height: 56 + topPadding,
      padding: EdgeInsets.only(top: topPadding, left: 16, right: 16),
      color: Colors.transparent,
      child: Row(
        children: [
          const Spacer(),
          GestureDetector(
            onTap: () {
              /* TODO: account switcher */
            },
            child: CircleAvatar(
              radius: 20,
              backgroundColor: colors.primary,
              child: Text(
                (() {
                  final username =
                      context
                          .watch<SubsonicProvider>()
                          .activeAccount
                          ?.username ??
                      '';
                  return username.isNotEmpty ? username[0].toUpperCase() : '?';
                })(),
                style: context.theme.typography.sm.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSelected(_NavItem item) {
    if (widget.selectedRoute == null) return false;
    return widget.selectedRoute == item.route ||
        widget.selectedRoute!.startsWith('${item.route}/');
  }

  void _navigateTo(String route) {
    context.go(route);
  }

  void _onScroll() {
    const maxScroll = 250;
    final scrollOffset = _scrollController.offset.clamp(0.0, maxScroll);
    final opacity = scrollOffset / maxScroll;

    if (opacity != _topBlurOpacity) {
      loggerPrint(
        "setting opacity to $opacity based on scroll offset $scrollOffset",
      );

      setState(() {
        _topBlurOpacity = opacity;
        aniu.value = opacity;
      });
    }
  }
}

class _NavItem {
  final String label;
  final String route;
  final IconData icon;

  const _NavItem({
    required this.label,
    required this.route,
    required this.icon,
  });
}
