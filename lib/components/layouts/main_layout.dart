// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'dart:ui';

import 'package:cosmodrome/components/desktop_profile_popover.dart';
import 'package:cosmodrome/components/desktop_titlebar.dart';
import 'package:cosmodrome/components/music_player/desktop_player_bar.dart';
import 'package:cosmodrome/components/music_player/desktop_queue_panel.dart';
import 'package:cosmodrome/components/music_player/mini_player.dart';
import 'package:cosmodrome/components/profile_sheet.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/theme/sidebar_item_style.dart';
import 'package:cosmodrome/utils/accent_notifier.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:cosmodrome/utils/layout_notifier.dart';
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

String uriToTitle(String uri) {
  switch (uri) {
    case '/home':
      return 'Home';
    case '/library':
      return 'your library';
    default:
      // try get from _navItems
      final item = _navItems.firstWhere(
        (item) => uri.startsWith(item.route),
        orElse: () => _NavItem(label: '', route: '', icon: FIcons.qrCode),
      );
      return item.label.isNotEmpty ? item.label : 'Page';
  }
}

class MainLayout extends StatefulWidget {
  final Widget child;
  final String? selectedRoute;

  const MainLayout({super.key, required this.child, this.selectedRoute});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with TickerProviderStateMixin {
  final _searchController = TextEditingController();

  final _mobileScrollController = ScrollController();
  final _desktopScrollController = ScrollController();
  bool _queueOpen = false;

  String? _customTitle;

  Color? _accentColor;
  bool _accentVisible = false;

  late AnimationController aniu;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  bool get _isSubPage =>
      widget.selectedRoute != null &&
      !_navItems.any((item) => widget.selectedRoute == item.route);

  @override
  Widget build(BuildContext context) {
    if (isMobile(context)) {
      return _buildMobileLayout(context);
    }
    return _buildDesktopLayout(context);
  }

  @override
  void didUpdateWidget(MainLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRoute != widget.selectedRoute) {
      if (_mobileScrollController.hasClients) _mobileScrollController.jumpTo(0);
      if (_desktopScrollController.hasClients)
        _desktopScrollController.jumpTo(0);
      if (!(widget.selectedRoute?.startsWith('/library/album') ?? false)) {
        accentColorNotifier.value = null;
      }
    }
  }

  @override
  void dispose() {
    accentColorNotifier.removeListener(_onAccentChanged);
    _searchController.dispose();
    _mobileScrollController.dispose();
    _desktopScrollController.dispose();
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
    _mobileScrollController.addListener(_onScroll);
    accentColorNotifier.addListener(_onAccentChanged);
    customTitle.addListener(_onCustomTitleChanged);
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final colors = context.theme.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // sidebar
          SizedBox(
            width: AppLayout.sidebarWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF151517),
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
                  decoration: .boxDelta(color: AppColors.sidebar),
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
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Main content area
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned(
                              top: -32,
                              left: 0,
                              right: 0,
                              height:
                                  MediaQuery.of(context).size.height * 0.38 +
                                  32,
                              child: IgnorePointer(
                                child: AnimatedOpacity(
                                  opacity: _accentVisible ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeIn,
                                  child: _accentColor == null
                                      ? const SizedBox.expand()
                                      : Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                _accentColor!.withValues(
                                                  alpha: 0.55,
                                                ),
                                                _accentColor!.withValues(
                                                  alpha: 0.30,
                                                ),
                                                colors.background.withValues(
                                                  alpha: 0.0,
                                                ),
                                              ],
                                              stops: const [0.0, 0.15, 1.0],
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_isDesktop)
                                    DesktopTitlebar(
                                      showWindowControls: !_queueOpen,
                                      canGoBack:
                                          widget.selectedRoute != '/home' &&
                                          widget.selectedRoute != null,
                                      onBack: () => context.pop(),
                                      queueOpen: _queueOpen,
                                      onToggleQueue: () => setState(
                                        () => _queueOpen = !_queueOpen,
                                      ),
                                    ),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      controller: _desktopScrollController,
                                      child: widget.child,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Queue panel
                      if (_queueOpen)
                        SizedBox(
                          width: 280,
                          child: DesktopQueuePanel(
                            onClose: () => setState(() => _queueOpen = false),
                          ),
                        ),
                    ],
                  ),
                ),
                // plr bar
                const DesktopPlayerBar(),
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
                _buildNavButton(context, _navItems[0], showLabel: false),
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
                              _buildNavButton(
                                context,
                                _navItems[1],
                                showLabel: false,
                              ),
                              _buildNavButton(
                                context,
                                _navItems[2],
                                showLabel: false,
                              ),
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
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // accent gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPadding + MediaQuery.of(context).size.height * 0.38,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _accentVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeIn,
                child: _accentColor == null
                    ? const SizedBox.expand()
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _accentColor!.withValues(alpha: 0.55),
                              _accentColor!.withValues(alpha: 0.30),
                              colors.background.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.15, 1.0],
                          ),
                        ),
                      ),
              ),
            ),
          ),
          // actual content
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _mobileScrollController,
              child: Column(
                children: [
                  SizedBox(height: topPadding + 20),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          MediaQuery.of(context).size.height -
                          (topPadding + 20) -
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

          // mini mobile player! (if song playing, and not collapsed)
          Positioned(
            bottom: bottomPadding + 18 + 48 + 20,
            left: 16,
            right: 16,
            child: Consumer<PlayerProvider>(
              builder: (_, player, _) {
                if (!player.hasCurrentSong) return const SizedBox.shrink();
                final collapsed = aniu.value > 0.3;
                return AnimatedOpacity(
                  opacity: collapsed ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: collapsed,
                    child: const MiniPlayer(),
                  ),
                );
              },
            ),
          ),
          // floating dual-pill nav
          Positioned(
            bottom: bottomPadding + 18,
            left: 16,
            right: 16,
            child: Consumer<PlayerProvider>(
              builder: (_, player, _) {
                final collapsed = aniu.value > 0.3;
                return Row(
                  children: [
                    _buildMainPill(context),

                    // mini mobile player! (if song playing, and collapsed)
                    Expanded(
                      child: player.hasCurrentSong && collapsed
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: const MiniPlayer(),
                            )
                          : const SizedBox.shrink(),
                    ),
                    _buildSearchPill(context),
                  ],
                );
              },
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
            if (_isSubPage)
              GestureDetector(
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        color: colors.background.withOpacity(0.8),
                        child: Icon(
                          FIcons.chevronLeft,
                          size: 20,
                          color: colors.foreground,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Text(
                _getPageTitle(),
                style: context.theme.typography.xl2.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 0,
                  color: colors.foreground,
                ),
              ),
            const Spacer(),
            // custom buttons
            // FButton(
            //   onPress: () => context.push('/search'),

            //   style: .delta(
            //     decoration: .delta([
            //       FVariantOperation.all(
            //         .boxDelta(
            //           color: AppColors.mutedButtonColor,
            //           borderRadius: BorderRadius.circular(40),
            //           border: Border.all(color: colors.border, width: 1),
            //         ),
            //       ),
                  
            //     ]),
            //     contentStyle: .delta(
            //       padding: EdgeInsetsGeometryDelta.value(
            //         const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            //       ),
            //     ),
            //   ),
            //   child: const Icon(FIcons.plus, size: 24, color: Colors.white),
            // ),

            if (widget.selectedRoute == '/home' || widget.selectedRoute == '/')
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
                  backgroundImage:
                      subsonic.activeAccount?.avatar.isNotEmpty == true
                      ? MemoryImage(subsonic.activeAccount!.avatar)
                      : Image.asset("/assets/logo.png").image,
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
    if (_customTitle != null) return _customTitle!;
    return uriToTitle(widget.selectedRoute ?? '/home');
  }

  bool _isSelected(_NavItem item) {
    if (widget.selectedRoute == null) return false;
    return widget.selectedRoute == item.route ||
        widget.selectedRoute!.startsWith('${item.route}/');
  }

  void _navigateTo(String route) {
    context.go(route);
  }

  void _onAccentChanged() {
    final color = accentColorNotifier.value;
    if (color != null) {
      setState(() {
        _accentColor = color;
        _accentVisible = true;
      });
    } else {
      setState(() => _accentVisible = false);
      // Clear stored color after the fade-out completes
      Future.delayed(const Duration(milliseconds: 750), () {
        if (mounted && accentColorNotifier.value == null) {
          setState(() => _accentColor = null);
        }
      });
    }
  }

  void _onCustomTitleChanged() {
    setState(() {
      _customTitle = customTitle.value;
    });
  }

  void _onScroll() {
    const maxScroll = 250;
    final scrollOffset = _mobileScrollController.offset.clamp(0.0, maxScroll);
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
