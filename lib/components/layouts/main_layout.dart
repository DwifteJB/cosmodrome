// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'dart:ui';

import 'package:cosmodrome/components/desktop_profile_popover.dart';
import 'package:cosmodrome/components/desktop_titlebar.dart';
import 'package:cosmodrome/components/profile_sheet.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/theme/sidebar_item_style.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
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

  late AnimationController aniu;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  Widget build(BuildContext context) {
    if (isMobile(context)) {
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

  Widget _buildDesktopLayout(BuildContext context) {
    final colors = context.theme.colors;

    print("using desktop layout");

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: AppLayout.sidebarWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF151517),
                border: Border(
                  right: BorderSide(color: colors.border, width: 1),
                ),
              ),
              child: FSidebar(
                style: .delta(
                  contentPadding: .add(
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  footerPadding: .add(
                    const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  decoration: .boxDelta(color: AppColors.sidebar)
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
                footer: const DesktopProfilePopover(),
                children: _navItems
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: FSidebarItem(
                        label: Text(item.label),
                        icon: Icon(item.icon, size: 20),
                        selected: _isSelected(item),
                        onPress: () => _navigateTo(item.route),
                        style: desktopSidebarItem(
                          colors: colors,
                          typography: context.theme.typography,
                          style: context.theme.style,
                          touch: false,
                        ),
                        
                        ),
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
                Expanded(child: SingleChildScrollView(child: widget.child)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainPill(BuildContext context) {
    final colors = context.theme.colors;
    final collapsed = aniu.value > 0.3;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.border, width: 1),
        borderRadius: BorderRadius.circular(28),
        color: colors.background.withOpacity(0.55),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNavButton(context, _navItems[0]),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: collapsed ? 0.0 : 1.0,
                    child: collapsed
                        ? const SizedBox.shrink()
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildNavButton(context, _navItems[1]),
                              _buildNavButton(context, _navItems[2]),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final colors = context.theme.colors;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    const navHeight = 80.0;
    return Scaffold(
      body: Stack(
        children: [
          // actual content
          Positioned.fill(
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
          // bottom gradient (always visible, beneath the floating nav)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: navHeight + bottomPadding + 24,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.background.withOpacity(0),
                      colors.background.withOpacity(0.95),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // top gradient 
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPadding + 72,
            child: IgnorePointer(
              child: FadeTransition(
                opacity: aniu.drive(CurveTween(curve: Curves.easeOut)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        colors.background.withOpacity(0),
                        colors.background.withOpacity(0.9),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 56 + topPadding,
            child: _buildMobileTopBar(context),
          ),
          // floating dual-pill nav
          Positioned(
            bottom: bottomPadding + 18,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_buildMainPill(context), _buildSearchPill(context)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTopBar(BuildContext context) {
    final colors = context.theme.colors;
    final topPadding = MediaQuery.of(context).padding.top;

    final subsonic = context.read<SubsonicProvider>();

    String username = subsonic.activeAccount?.username[0] ?? 'meowmeowmeow';

    String TestColor = username.toUpperCase();
    // hex it to a color
    final color = Color(
      (TestColor.codeUnitAt(0) * 0xFFFFFF ~/ 26) | 0xFF000000,
    );

    return Container(
      height: 56 + topPadding,
      padding: EdgeInsets.only(top: topPadding, left: 20, right: 16),
      color: Colors.transparent,
      child: FadeTransition(
        opacity: aniu.drive(
          Tween(begin: 1.0, end: 0.0).chain(
            CurveTween(curve: const Interval(0.0, 0.3, curve: Curves.easeOut)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _getPageTitle(),
              style: context.theme.typography.xl2.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.foreground,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => showFSheet(
                context: context,
                side: FLayout.btt,
                mainAxisMaxRatio: null,
                useSafeArea: true,
                builder: (_) => const ProfileSheet(),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: color,
                child: Text(
                  (() {
                    final username =
                        context
                            .watch<SubsonicProvider>()
                            .activeAccount
                            ?.username ??
                        '';
                    return username.isNotEmpty
                        ? username[0].toUpperCase()
                        : '?';
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
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context,
    _NavItem item, {
    bool showLabel = true,
  }) {
    final colors = context.theme.colors;
    final selected = _isSelected(item);
    final color = selected ? colors.primary : colors.mutedForeground;

    return GestureDetector(
      onTap: () => _navigateTo(item.route),
      behavior: HitTestBehavior.opaque,
      child: showLabel
          ? SizedBox(
              width: 68,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 24, color: color),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    style: context.theme.typography.xs.copyWith(color: color),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(item.icon, size: 24, color: color),
            ),
    );
  }

  Widget _buildSearchPill(BuildContext context) {
    final colors = context.theme.colors;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.border, width: 1),
        borderRadius: BorderRadius.circular(28),
        color: colors.background.withOpacity(0.55),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: _buildNavButton(context, _navItems[3], showLabel: false),
          ),
        ),
      ),
    );
  }

  String _getPageTitle() {
    for (final item in _navItems) {
      if (_isSelected(item)) return item.label;
    }
    return '';
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

    if (opacity != aniu.value) {
      setState(() {
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
