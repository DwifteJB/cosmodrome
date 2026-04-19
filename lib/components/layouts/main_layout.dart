// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cosmodrome/components/desktop_profile_popover.dart';
import 'package:cosmodrome/components/desktop_titlebar.dart';
import 'package:cosmodrome/components/music_player/desktop_player_bar.dart';
import 'package:cosmodrome/components/music_player/desktop_queue_panel.dart';
import 'package:cosmodrome/components/music_player/mini_player.dart';
import 'package:cosmodrome/components/profile_sheet.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/theme/sidebar_item_style.dart';
import 'package:cosmodrome/utils/accent_notifier.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:cosmodrome/utils/layout_notifier.dart';
import 'package:cosmodrome/utils/logger.dart';
import 'package:cosmodrome/utils/sidebar_notifier.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

const _mobilenavItems = [
  _NavItem(label: 'Home', route: '/home', icon: FIcons.house),
  _NavItem(label: 'Library', route: '/library', icon: FIcons.library),
  _NavItem(label: 'Search', route: '/search', icon: FIcons.search),
];

String uriToTitle(String uri) {
  switch (uri) {
    case '/home':
      return 'Home';
    case '/library':
      return 'your albums';
    default:
      // try get from _mobilenavItems
      final item = _mobilenavItems.firstWhere(
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
  final Map<String, bool> _desktopMenuExpanded = {};
  final Map<String, bool> _desktopMenuHovered = {};

  final _mobileScrollController = ScrollController();
  final _desktopScrollController = ScrollController();
  bool _queueOpen = false;
  Future<List<Album>>? _starredAlbumsFuture;
  String? _starredAccountId;
  bool _isRefreshingStarred = false;
  Future<List<Playlist>>? _playlistsFuture;
  String? _playlistsAccountId;
  bool _isRefreshingPlaylists = false;

  LayoutConfig _layoutConfig = LayoutConfig.empty;

  Color? _accentColor;
  bool _accentVisible = false;
  Timer? _accentHideTimer;

  String? _coverUrl;
  bool _coverVisible = false;
  Timer? _coverHideTimer;

  late AnimationController aniu;

  final List<_NavMenu> _navMenus = [
    _NavMenu(
      label: "Cosmodrome",
      builder: null,
      items: [
        _NavItem(label: 'Home', route: '/home', icon: FIcons.house),
        _NavItem(label: 'Library', route: '/library', icon: FIcons.library),
      ],
    ),

    _NavMenu(label: "Starred", builder: null),
    _NavMenu(label: "Playlists", builder: null),
  ];

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  bool get _isSubPage =>
      widget.selectedRoute != null &&
      !_mobilenavItems.any((item) => widget.selectedRoute == item.route);

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
      // reset immediately to prevent showing wrong title/buttons during transition, then clear after animations complete
      _layoutConfig = LayoutConfig.empty;
      aniu.value = 0;
      if (_mobileScrollController.hasClients) _mobileScrollController.jumpTo(0);
      if (_desktopScrollController.hasClients) {
        _desktopScrollController.jumpTo(0);
      }
      if (!_isMusicPageRoute(widget.selectedRoute)) {
        accentColorNotifier.value = null;
        coverUrlNotifier.value = null;
      }
    }
  }

  @override
  void dispose() {
    _accentHideTimer?.cancel();
    _coverHideTimer?.cancel();
    _searchController.dispose();
    _mobileScrollController.dispose();
    _desktopScrollController.dispose();

    layoutConfig.removeListener(_onLayoutConfigChanged);
    accentColorNotifier.removeListener(_onAccentChanged);
    coverUrlNotifier.removeListener(_onCoverUrlChanged);
    starredCountChanged.removeListener(_onStarredSidebarChanged);
    playlistsCountChanged.removeListener(_onPlaylistsSidebarChanged);
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
    _desktopScrollController.addListener(_onScroll);

    layoutConfig.addListener(_onLayoutConfigChanged);
    accentColorNotifier.addListener(_onAccentChanged);
    coverUrlNotifier.addListener(_onCoverUrlChanged);
    starredCountChanged.addListener(_onStarredSidebarChanged);
    playlistsCountChanged.addListener(_onPlaylistsSidebarChanged);

    for (final menu in _navMenus) {
      _desktopMenuExpanded[menu.label] = true;
      _desktopMenuHovered[menu.label] = false;
    }
  }

  Widget _buildAlbumCoverPrefix(Album album) {
    final url = album.cachedCoverUrl;
    if (url == null || url.isEmpty) {
      return const Icon(FIcons.disc3, size: 20, color: AppColors.auraColor);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url,
        width: 20,
        height: 20,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Icon(FIcons.disc3, size: 20, color: AppColors.auraColor),
      ),
    );
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
                    const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  ),
                  footerPadding: .add(
                    const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  decoration: .boxDelta(color: AppColors.sidebar),
                ),
                header: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // on macOS the native traffic-light buttons sit in the top-left
                    // of the window, so push the search field down to avoid overlap
                    if (!kIsWeb && Platform.isMacOS) const SizedBox(height: 28),
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
                // DESKTOP nav menus
                children: _navMenus
                    .map(
                      (menu) => FSidebarGroup(
                        key: ValueKey('desktop-group-${menu.label}'),
                        label: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) =>
                              _setDesktopMenuHovered(menu.label, value: true),
                          onExit: (_) =>
                              _setDesktopMenuHovered(menu.label, value: false),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _toggleDesktopMenu(menu.label),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _isDesktopMenuHovered(menu.label)
                                    ? AppColors.sidebarSelected
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(child: Text(menu.label)),
                                  AnimatedRotation(
                                    turns: _isDesktopMenuExpanded(menu.label)
                                        ? 0.0
                                        : -0.25,
                                    duration: const Duration(milliseconds: 180),
                                    child: const Icon(
                                      FIcons.chevronDown,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        style: .delta(padding: .delta(left: 0, right: 0)),
                        action:
                            (menu.label == 'Starred' ||
                                menu.label == 'Playlists')
                            ? Tooltip(
                                message: menu.label == 'Starred'
                                    ? 'Refresh starred'
                                    : 'Refresh playlists',
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      (menu.label == 'Starred'
                                          ? _isRefreshingStarred
                                          : _isRefreshingPlaylists)
                                      ? const Padding(
                                          padding: EdgeInsets.all(2),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.refresh, size: 16),
                                ),
                              )
                            : null,
                        onActionPress: menu.label == 'Starred'
                            ? () => _refreshStarredAlbums(context)
                            : menu.label == 'Playlists'
                            ? () => _refreshPlaylists(context)
                            : null,
                        children: [
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: ClipRect(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 170),
                                curve: Curves.easeOut,
                                opacity: _isDesktopMenuExpanded(menu.label)
                                    ? 1
                                    : 0,
                                child: IgnorePointer(
                                  ignoring: !_isDesktopMenuExpanded(menu.label),
                                  child: _isDesktopMenuExpanded(menu.label)
                                      ? Column(
                                          children: [
                                            ...menu.items.map(
                                              (item) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 2,
                                                    ),
                                                child: FSidebarItem(
                                                  label: Text(item.label),
                                                  icon: Icon(
                                                    item.icon,
                                                    size: 20,

                                                    color: AppColors.auraColor,
                                                  ),
                                                  selected: _isSelected(item),
                                                  onPress: () =>
                                                      _navigateTo(item.route),
                                                  style: desktopSidebarItem(
                                                    selectedBackgroundColor:
                                                        AppColors.auraColor
                                                            .withValues(
                                                              alpha: 0.16,
                                                            ),
                                                    colors: colors,
                                                    typography: context
                                                        .theme
                                                        .typography,
                                                    style: context.theme.style,
                                                    touch: false,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (menu.label == 'Starred')
                                              _buildStarredMenuContent(context),
                                            if (menu.label == 'Playlists')
                                              _buildPlaylistsMenuContent(
                                                context,
                                              ),
                                            if (menu.builder != null)
                                              menu.builder!(context),
                                          ],
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                        ],
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
                      // main content area
                      Expanded(
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            Positioned(
                              top: -32,
                              left: 0,
                              right: 0,
                              height:
                                  MediaQuery.of(context).size.height * 1 + 32,
                              child: IgnorePointer(
                                child: AnimatedOpacity(
                                  opacity: _coverVisible ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeIn,
                                  child: _coverUrl == null
                                      ? const SizedBox.expand()
                                      : Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ImageFiltered(
                                              imageFilter: ImageFilter.blur(
                                                sigmaX: 100,
                                                sigmaY: 100,
                                                tileMode: TileMode.clamp,
                                              ),
                                              child: Image.network(
                                                _coverUrl!,
                                                fit: BoxFit.cover,
                                                colorBlendMode:
                                                    BlendMode.overlay,
                                              ),
                                            ),
                                            const DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: Color(0x99000000),
                                              ),
                                            ),
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.center,
                                                  colors: [
                                                    colors.background
                                                        .withValues(
                                                          alpha: 0.42,
                                                        ),
                                                    colors.background
                                                        .withValues(
                                                          alpha: 0.16,
                                                        ),
                                                  ],
                                                  stops: const [0.0, 0.62],
                                                ),
                                              ),
                                            ),
                                          ],
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
                                      onBack: () {
                                        if (context.canPop()) {
                                          context.pop();
                                        } else {
                                          context.go('/home');
                                        }
                                      },
                                      queueOpen: _queueOpen,
                                      onToggleQueue: () => setState(
                                        () => _queueOpen = !_queueOpen,
                                      ),
                                    )
                                  else if (kIsWeb)
                                    const SizedBox(height: 32),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      controller: _desktopScrollController,
                                      child: KeyedSubtree(
                                        key: const ValueKey('desktop-child'),
                                        child: widget.child,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IgnorePointer(
                              ignoring: !_queueOpen,
                              child: AnimatedOpacity(
                                opacity: _queueOpen ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 220),
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _queueOpen = false),
                                  behavior: HitTestBehavior.opaque,
                                  child: const ColoredBox(
                                    color: Color(0x66000000),
                                  ),
                                ),
                              ),
                            ),
                            // queue elements
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              top: 0,
                              right: _queueOpen ? 0 : -280,
                              bottom: 0,
                              width: 280,
                              child: DesktopQueuePanel(
                                onClose: () =>
                                    setState(() => _queueOpen = false),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // plr bar
                DesktopPlayerBar(
                  onQueueToggle: kIsWeb
                      ? () => setState(() => _queueOpen = !_queueOpen)
                      : null,
                ),
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
                _buildNavButton(context, _mobilenavItems[0], showLabel: false),
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
                                _mobilenavItems[1],
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
          if (_layoutConfig.isScrollable)
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
                      child: KeyedSubtree(
                        key: const ValueKey('mobile-child'),
                        child: widget.child,
                      ),
                    ),
                    // extra space at the bottom to allow scrolling content above the floating nav
                    SizedBox(height: navHeight + bottomPadding + 60),
                  ],
                ),
              ),
            )
          else
            Positioned.fill(
              child: KeyedSubtree(
                key: const ValueKey('mobile-child'),
                child: widget.child,
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
            child: _layoutConfig.hidePill
                ? const SizedBox.shrink()
                : Consumer<PlayerProvider>(
                    builder: (_, player, _) {
                      final collapsed = aniu.value > 0.3;
                      return Row(
                        children: [
                          _layoutConfig.mainPillBuilder != null
                              ? _layoutConfig.mainPillBuilder!(context)
                              : _buildMainPill(context),

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
                          _layoutConfig.searchPillBuilder != null
                              ? _layoutConfig.searchPillBuilder!(context)
                              : _buildSearchPill(context),
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
                  fontWeight: FontWeight.w400,
                  height: 0,
                  color: colors.foreground,
                ),
              ),
            const Spacer(),
            // custom buttons
            ..._layoutConfig.buttons.map(
              (button) => FButton(
                onPress: button.onPressed,
                style: .delta(
                  decoration: .delta([
                    FVariantOperation.all(
                      .boxDelta(
                        color: AppColors.mutedButtonColor,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: colors.border, width: 1),
                      ),
                    ),
                  ]),
                  contentStyle: .delta(
                    padding: EdgeInsetsGeometryDelta.value(
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    ),
                  ),
                ),
                child: Icon(
                  button.icon,
                  size: 24,
                  color: button.color ?? Colors.white,
                ),
              ),
            ),

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

  Widget _buildPlaylistCoverPrefix(
    Playlist playlist,
    SubsonicProvider subsonic,
  ) {
    if (playlist.coverArt == null || playlist.coverArt!.isEmpty) {
      return const Icon(FIcons.listMusic, size: 20, color: AppColors.auraColor);
    }

    String url;
    try {
      url = subsonic.subsonic.cachedCoverArtUrl(playlist.coverArt!, size: 80);
    } catch (_) {
      return const Icon(FIcons.listMusic, size: 20, color: AppColors.auraColor);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url,
        width: 20,
        height: 20,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Icon(FIcons.listMusic, size: 20, color: AppColors.auraColor),
      ),
    );
  }

  Widget _buildPlaylistsMenuContent(BuildContext context) {
    final colors = context.theme.colors;
    return Consumer<SubsonicProvider>(
      builder: (_, subsonic, _) {
        final active = subsonic.activeAccount;
        if (active == null) return const SizedBox.shrink();

        if (_playlistsFuture == null || _playlistsAccountId != active.id) {
          _playlistsAccountId = active.id;
          _playlistsFuture = _loadPlaylists(subsonic);
        }

        return FutureBuilder<List<Playlist>>(
          future: _playlistsFuture,
          builder: (_, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Text(
                  'Could not load playlists',
                  style: context.theme.typography.xs.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              );
            }

            final playlists = snapshot.data ?? const <Playlist>[];
            if (playlists.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Text(
                  'No playlists found',
                  style: context.theme.typography.xs.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              );
            }

            return Column(
              children: playlists
                  .map(
                    (playlist) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      child: FSidebarItem(
                        label: Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        icon: _buildPlaylistCoverPrefix(playlist, subsonic),
                        selected: _isPlaylistSelected(playlist.id),
                        onPress: () =>
                            _navigateTo('/library/playlist/${playlist.id}'),
                        style: desktopSidebarItem(
                          selectedBackgroundColor: AppColors.auraColor
                              .withValues(alpha: 0.16),
                          colors: colors,
                          typography: context.theme.typography,
                          style: context.theme.style,
                          touch: false,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        );
      },
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
            // search
            child: _buildNavButton(
              context,
              _mobilenavItems.where((item) => item.label == 'Search').first,
              showLabel: false,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStarredMenuContent(BuildContext context) {
    final colors = context.theme.colors;
    return Consumer<SubsonicProvider>(
      builder: (_, subsonic, _) {
        final active = subsonic.activeAccount;
        if (active == null) return const SizedBox.shrink();

        if (_starredAlbumsFuture == null || _starredAccountId != active.id) {
          _starredAccountId = active.id;
          _starredAlbumsFuture = _loadStarredAlbums(subsonic);
        }

        return FutureBuilder<List<Album>>(
          future: _starredAlbumsFuture,
          builder: (_, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Text(
                  'Could not load starred albums',
                  style: context.theme.typography.xs.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              );
            }

            final albums = snapshot.data ?? const <Album>[];
            if (albums.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Text(
                  'No starred albums yet',
                  style: context.theme.typography.xs.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              );
            }

            return Column(
              children: albums
                  .map(
                    (album) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      child: FSidebarItem(
                        label: Text(
                          album.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        icon: _buildAlbumCoverPrefix(album),
                        selected: _isAlbumSelected(album.id),
                        onPress: () =>
                            _navigateTo('/library/album/${album.id}'),
                        style: desktopSidebarItem(
                          selectedBackgroundColor: AppColors.auraColor
                              .withValues(alpha: 0.16),
                          colors: colors,
                          typography: context.theme.typography,
                          style: context.theme.style,
                          touch: false,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        );
      },
    );
  }

  String _getPageTitle() {
    if (_layoutConfig.title != null) return _layoutConfig.title!;
    return uriToTitle(widget.selectedRoute ?? '/home');
  }

  bool _isAlbumSelected(String albumId) {
    final route = widget.selectedRoute;
    if (route == null) return false;
    final albumRoute = '/library/album/$albumId';
    return route == albumRoute ||
        route.startsWith('$albumRoute?') ||
        route.startsWith('$albumRoute/');
  }

  bool _isDesktopMenuExpanded(String label) =>
      _desktopMenuExpanded[label] ?? true;

  bool _isDesktopMenuHovered(String label) =>
      _desktopMenuHovered[label] ?? false;

  bool _isMusicPageRoute(String? route) =>
      route?.startsWith('/library/album') == true ||
      route?.startsWith('/library/playlist') == true;

  bool _isPlaylistSelected(String playlistId) {
    final route = widget.selectedRoute;
    if (route == null) return false;
    final playlistRoute = '/library/playlist/$playlistId';
    return route == playlistRoute ||
        route.startsWith('$playlistRoute?') ||
        route.startsWith('$playlistRoute/');
  }

  bool _isSelected(_NavItem item) {
    if (widget.selectedRoute == null) return false;
    return widget.selectedRoute == item.route;
  }

  Future<List<Playlist>> _loadPlaylists(SubsonicProvider subsonic) async {
    return subsonic.subsonic.getPlaylists();
  }

  Future<List<Album>> _loadStarredAlbums(SubsonicProvider subsonic) async {
    final albums = await subsonic.subsonic.getAlbumList2('starred', size: 40);
    for (final album in albums) {
      if (album.coverArt != null) {
        album.cachedCoverUrl ??= subsonic.subsonic.cachedCoverArtUrl(
          album.coverArt!,
          size: 80,
        );
      }
    }
    return albums;
  }

  void _navigateTo(String route) {
    context.go(route);
  }

  void _onAccentChanged() {
    _accentHideTimer?.cancel();
    final color = accentColorNotifier.value;
    if (color != null) {
      setState(() {
        _accentColor = color;
        _accentVisible = true;
      });
    } else {
      setState(() => _accentVisible = false);
      _accentHideTimer = Timer(const Duration(milliseconds: 750), () {
        if (mounted && accentColorNotifier.value == null) {
          setState(() => _accentColor = null);
        }
      });
    }
  }

  void _onCoverUrlChanged() {
    _coverHideTimer?.cancel();
    final url = coverUrlNotifier.value;
    if (url != null) {
      setState(() {
        _coverUrl = url;
        _coverVisible = true;
      });
    } else {
      setState(() => _coverVisible = false);
      _coverHideTimer = Timer(const Duration(milliseconds: 750), () {
        if (mounted && coverUrlNotifier.value == null) {
          setState(() => _coverUrl = null);
        }
      });
    }
  }

  void _onLayoutConfigChanged() {
    setState(() {
      _layoutConfig = layoutConfig.value;
    });
  }

  void _onPlaylistsSidebarChanged() {
    if (!mounted || isMobile(context)) return;
    _refreshPlaylists(context);
  }

  void _onScroll() {
    ScrollController? activeController;

    if (_desktopScrollController.hasClients) {
      activeController = _desktopScrollController;
    }
    if (_mobileScrollController.hasClients &&
        _mobileScrollController.offset >= 0) {
      activeController = _mobileScrollController;
    }

    if (activeController == null) return;

    final maxScroll = 250.0;
    var scrollOffset = activeController.offset.clamp(0.0, maxScroll);
    final opacity = scrollOffset / maxScroll;

    if (opacity != aniu.value) {
      setState(() {
        aniu.value = opacity;
      });
    }
  }

  void _onStarredSidebarChanged() {
    if (!mounted || isMobile(context)) return;
    _refreshStarredAlbums(context);
  }

  Future<void> _refreshPlaylists(BuildContext context) async {
    final subsonic = context.read<SubsonicProvider>();
    final active = subsonic.activeAccount;
    if (active == null) return;

    setState(() {
      _isRefreshingPlaylists = true;
      _playlistsAccountId = active.id;
      _playlistsFuture = _loadPlaylists(subsonic);
    });

    try {
      await _playlistsFuture;
    } finally {
      if (mounted) {
        setState(() => _isRefreshingPlaylists = false);
      }
    }
  }

  Future<void> _refreshStarredAlbums(BuildContext context) async {
    final subsonic = context.read<SubsonicProvider>();
    final active = subsonic.activeAccount;
    if (active == null) return;

    setState(() {
      _isRefreshingStarred = true;
      _starredAccountId = active.id;
      _starredAlbumsFuture = _loadStarredAlbums(subsonic);
    });

    try {
      await _starredAlbumsFuture;
    } finally {
      if (mounted) {
        setState(() => _isRefreshingStarred = false);
      }
    }
  }

  void _setDesktopMenuHovered(String label, {required bool value}) {
    if (_isDesktopMenuHovered(label) == value) return;
    setState(() {
      _desktopMenuHovered[label] = value;
    });
  }

  void _toggleDesktopMenu(String label) {
    setState(() {
      _desktopMenuExpanded[label] = !_isDesktopMenuExpanded(label);
    });
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

class _NavMenu {
  final String label;
  final List<_NavItem> items;

  // optional custom widget builder
  // so you can show playlists, starred etc
  final Widget Function(BuildContext context)? builder;

  const _NavMenu({required this.label, this.items = const [], this.builder});
}
