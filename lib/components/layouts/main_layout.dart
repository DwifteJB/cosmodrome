// ignore_for_file: deprecated_member_use

/*
  this file was split into mobile_layout & desktop_layout

  this handles all the things that the two layouts need to function properly
  UI is controlled there now :)

  - 19/04/2026 Robbie Morgan
*/

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cosmodrome/components/desktop/desktop_profile_popover.dart';
import 'package:cosmodrome/components/desktop/desktop_search_field.dart';
import 'package:cosmodrome/components/desktop/desktop_titlebar.dart';
import 'package:cosmodrome/components/desktop/desktop_layout.dart';
import 'package:cosmodrome/components/desktop/desktop_page_scroll.dart';
import 'package:cosmodrome/components/layouts/main_layout_sidebar.dart';
import 'package:cosmodrome/components/layouts/mobile_layout.dart';
import 'package:cosmodrome/components/music_player/desktop_player_bar.dart';
import 'package:cosmodrome/components/music_player/desktop_side_panel.dart';
import 'package:cosmodrome/components/music_player/mini_player.dart';
import 'package:cosmodrome/components/mobile/profile_sheet.dart';
import 'package:cosmodrome/components/settings/settings_shell.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/theme/sidebar_item_style.dart';
import 'package:cosmodrome/utils/notifiers/accent_notifier.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/cover_art/cover_art_provider.dart';
import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:cosmodrome/utils/notifiers/layout_notifier.dart';
import 'package:cosmodrome/utils/notifiers/search_notifier.dart';
import 'package:cosmodrome/utils/notifiers/sidebar_notifier.dart';
import 'package:cosmodrome/utils/tap_area.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

const _mobilenavItems = [
  MainLayoutNavItem(label: 'Home', route: '/home', icon: FIcons.house),
  MainLayoutNavItem(label: 'Library', route: '/library', icon: FIcons.library),
  MainLayoutNavItem(label: 'Search', route: '/search', icon: FIcons.search),
];

String uriToTitle(String uri) {
  switch (uri) {
    case '/home':
      return 'Home';
    case '/library':
      return 'your albums';
    default:
      // try get from _mobilenavItems
      for (final item in _mobilenavItems) {
        if (uri.startsWith(item.route)) return item.label;
      }
      return 'Page';
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
  final Map<String, bool> _desktopMenuExpanded = {};
  final Map<String, bool> _desktopMenuHovered = {};

  final _mobileScrollController = ScrollController();
  DesktopSidePanelMode? _panelMode;
  // keeps the content while the panel slides closed
  DesktopSidePanelMode _lastPanelMode = DesktopSidePanelMode.queue;
  Future<List<Album>>? _starredAlbumsFuture;
  String? _starredAccountId;
  bool _isRefreshingStarred = false;
  Future<List<Playlist>>? _playlistsFuture;
  String? _playlistsAccountId;
  bool _isRefreshingPlaylists = false;

  LayoutConfig _layoutConfig = LayoutConfig.empty;
  LayoutConfig? _frozenConfig;

  Color? _accentColor;
  bool _accentVisible = false;
  Timer? _accentHideTimer;

  String? _coverUrl;
  bool _coverVisible = false;
  Timer? _coverHideTimer;

  late AnimationController aniu;
  late AnimationController _searchAnim;
  late final TextEditingController _mobileSearchController;
  late final VoidCallback _searchQueryListener;
  final _mobileSearchFocus = FocusNode();

  final List<MainLayoutNavMenu> _navMenus = [
    MainLayoutNavMenu(
      label: "Cosmodrome",
      builder: null,
      items: [
        MainLayoutNavItem(label: 'Home', route: '/home', icon: FIcons.house),
        MainLayoutNavItem(
          label: 'Library',
          route: '/library',
          icon: FIcons.library,
        ),
      ],
    ),

    const MainLayoutNavMenu(label: "Starred", builder: null),
    const MainLayoutNavMenu(label: "Playlists", builder: null),
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

  // even more yikes
  @override
  void didUpdateWidget(MainLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRoute != widget.selectedRoute) {
      // reset immediately to prevent showing wrong title/buttons during transition, then clear after animations complete
      _layoutConfig = LayoutConfig.empty;
      aniu.value = 0;
      if (_mobileScrollController.hasClients) _mobileScrollController.jumpTo(0);
      if (!_isMusicPageRoute(widget.selectedRoute)) {
        accentColorNotifier.value = null;
        coverUrlNotifier.value = null;
      }
      if (_isSearchRoute(widget.selectedRoute)) {
        _searchAnim.forward().then((_) {
          if (mounted) _mobileSearchFocus.requestFocus();
        });
      } else if (_isSearchRoute(oldWidget.selectedRoute)) {
        _mobileSearchFocus.unfocus();
        searchQuery.value = '';
        _searchAnim.reverse();
      }
    }
  }

  // yikes
  @override
  void dispose() {
    _accentHideTimer?.cancel();
    _coverHideTimer?.cancel();
    searchQuery.removeListener(_searchQueryListener);
    _mobileSearchController.dispose();
    _mobileSearchFocus.dispose();
    _mobileScrollController.dispose();
    desktopScrollOffset.removeListener(_onScroll);

    layoutConfig.removeListener(_onLayoutConfigChanged);
    detailPageActive.removeListener(_onDetailPageActiveChanged);
    accentColorNotifier.removeListener(_onAccentChanged);
    coverUrlNotifier.removeListener(_onCoverUrlChanged);
    starredCountChanged.removeListener(_onStarredSidebarChanged);
    playlistsCountChanged.removeListener(_onPlaylistsSidebarChanged);
    aniu.dispose();
    _searchAnim.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    aniu = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchAnim = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _mobileSearchController = TextEditingController(text: searchQuery.value);
    _searchQueryListener = () {
      final value = searchQuery.value;
      if (_mobileSearchController.text == value) return;
      _mobileSearchController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    };
    searchQuery.addListener(_searchQueryListener);
    if (_isSearchRoute(widget.selectedRoute)) _searchAnim.value = 1.0;
    _mobileScrollController.addListener(_onScroll);
    desktopScrollOffset.addListener(_onScroll);

    layoutConfig.addListener(_onLayoutConfigChanged);
    detailPageActive.addListener(_onDetailPageActiveChanged);
    accentColorNotifier.addListener(_onAccentChanged);
    coverUrlNotifier.addListener(_onCoverUrlChanged);
    starredCountChanged.addListener(_onStarredSidebarChanged);
    playlistsCountChanged.addListener(_onPlaylistsSidebarChanged);

    for (final menu in _navMenus) {
      _desktopMenuExpanded[menu.label] = true;
      _desktopMenuHovered[menu.label] = false;
    }
  }

  Widget _buildAlbumCoverPrefix(Album album) =>
      _buildSidebarCover(album.cachedCoverUrl, FIcons.disc3);

  Widget _buildDesktopLayout(BuildContext context) {
    final colors = context.theme.colors;

    final sidebar = SizedBox(
      width: AppLayout.sidebarWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF151517),
          border: Border(right: BorderSide(color: colors.border, width: 1)),
        ),
        child: MainLayoutDesktopSidebar(
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(12, 5, 12, 5),
                  child: DesktopSearchField(),
                ),
              ),
              const Divider(),
            ],
          ),
          footer: const DesktopProfilePopover(),
          navMenus: _navMenus,
          isRefreshingStarred: _isRefreshingStarred,
          isRefreshingPlaylists: _isRefreshingPlaylists,
          isMenuExpanded: _isDesktopMenuExpanded,
          isMenuHovered: _isDesktopMenuHovered,
          isItemSelected: _isSelected,
          onMenuHoverChanged: _setDesktopMenuHovered,
          onMenuToggle: _toggleDesktopMenu,
          onRefreshStarred: () => _refreshStarredAlbums(context),
          onRefreshPlaylists: () => _refreshPlaylists(context),
          onNavigate: _navigateTo,
          buildStarredContent: _buildStarredMenuContent,
          buildPlaylistsContent: _buildPlaylistsMenuContent,
        ),
      ),
    );

    final topBar = _isDesktop
        ? DesktopTitlebar(
            showWindowControls: _panelMode == null,
            canGoBack:
                widget.selectedRoute != '/home' && widget.selectedRoute != null,
            onBack: () => _goBack(context),
            onSettingsPressed: () => openSettings(context),
          )
        : (kIsWeb ? const SizedBox(height: 32) : const SizedBox.shrink());
    final hasTopBar = _isDesktop || kIsWeb;

    return DesktopLayout(
      backgroundColor: colors.background,
      sidebar: sidebar,
      panelOpen: _panelMode != null,
      onClosePanel: _closePanel,
      coverUrl: _coverUrl,
      coverVisible: _coverVisible,
      topBar: topBar,
      topBarInset: hasTopBar && !_isArtistRoute(widget.selectedRoute)
          ? DesktopLayout.topBarHeight
          : 0,
      sidePanelBuilder: (bottomInset) => DesktopSidePanel(
        mode: _panelMode ?? _lastPanelMode,
        onClose: _closePanel,
        bottomInset: bottomInset,
      ),
      playerBar: DesktopPlayerBar(
        panelMode: _panelMode,
        onToggleLyrics: () => _togglePanel(DesktopSidePanelMode.lyrics),
        onToggleQueue: () => _togglePanel(DesktopSidePanelMode.queue),
      ),
      child: widget.child,
    );
  }

  void _togglePanel(DesktopSidePanelMode mode) {
    final wasOpen = _panelMode != null;
    setState(() {
      if (_panelMode == mode) {
        _panelMode = null;
      } else {
        _panelMode = mode;
        _lastPanelMode = mode;
      }
    });
    if (!wasOpen && _panelMode != null) _growWindowForPanel();
  }

  // widen the window so the content keeps at least 400px beside the panel
  void _growWindowForPanel() {
    if (!_isDesktop) return;
    final available =
        MediaQuery.sizeOf(context).width -
        AppLayout.sidebarWidth -
        DesktopSidePanel.width;
    if (available >= 400) return;
    unawaited(() async {
      try {
        final size = await windowManager.getSize();
        await windowManager.setSize(
          Size(size.width + (400 - available), size.height),
          animate: true,
        );
      } catch (_) {}
    }());
  }

  void _closePanel() {
    if (_panelMode == null) return;
    setState(() => _panelMode = null);
  }

  // frosted rounded container shared by the floating mobile pills
  Widget _buildGlassPill(BuildContext context, {required Widget child}) {
    final colors = context.theme.colors;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.border, width: 1),
        borderRadius: BorderRadius.circular(28),
        color: colors.background.withValues(alpha: 0.55),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildMainPill(BuildContext context) {
    final collapsed = aniu.value > 0.3;

    return _buildGlassPill(
      context,
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
                  : _buildNavButton(
                      context,
                      _mobilenavItems[1],
                      showLabel: false,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final colors = context.theme.colors;
    final expandedMiniPlayer = Consumer<PlayerProvider>(
      builder: (_, player, _) {
        if (!player.hasCurrentSong) return const SizedBox.shrink();
        final collapsed = aniu.value > 0.3;
        return AnimatedOpacity(
          opacity: collapsed ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(ignoring: collapsed, child: const MiniPlayer()),
        );
      },
    );

    final floatingNav = _layoutConfig.hidePill
        ? const SizedBox.shrink()
        : Consumer<PlayerProvider>(
            builder: (_, player, _) {
              final collapsed = aniu.value > 0.3;
              return AnimatedBuilder(
                animation: _searchAnim,
                builder: (context, _) {
                  final searching = _searchAnim.value > 0;
                  final curved = CurvedAnimation(
                    parent: _searchAnim,
                    curve: Curves.easeOutCubic,
                  );
                  final hideOnSearch = Tween<double>(
                    begin: 1.0,
                    end: 0.0,
                  ).animate(curved);
                  return Row(
                    children: [
                      _layoutConfig.mainPillBuilder?.call(context) ??
                          _buildMainPill(context),
                      const SizedBox(width: 8),
                      Expanded(
                        child: searching
                            ? FadeTransition(
                                opacity: curved,
                                child: _buildSearchPillExpanded(context),
                              )
                            : (player.hasCurrentSong && collapsed
                                  ? MiniPlayer()
                                  : const SizedBox.shrink()),
                      ),
                      // fades, goes left & opens up :)
                      FadeTransition(
                        opacity: hideOnSearch,
                        child: SizeTransition(
                          axis: Axis.horizontal,
                          axisAlignment: 1.0,
                          sizeFactor: hideOnSearch,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 8),
                              _layoutConfig.searchPillBuilder?.call(context) ??
                                  _buildSearchPillIcon(context),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );

    return Consumer<PlayerProvider>(
      builder: (_, player, _) => PopScope(
        canPop: !player.isFullscreenOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) player.closeFullscreen();
        },
        child: MobileLayout(
          backgroundColor: colors.background,
          accentColor: _accentColor,
          accentVisible: _accentVisible,
          isScrollable: _layoutConfig.isScrollable,
          scrollController: _mobileScrollController,
          topGradientOpacity: aniu.drive(CurveTween(curve: Curves.easeOut)),
          topBar: _buildMobileTopBar(context),
          expandedMiniPlayer: expandedMiniPlayer,
          floatingNav: floatingNav,
          searchAnimation: CurvedAnimation(
            parent: _searchAnim,
            curve: Curves.easeOutCubic,
          ),
          onRefresh: widget.selectedRoute == '/home'
              ? requestHomeRefresh
              : null,
          child: widget.child,
        ),
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
                onTap: () => _goBack(context),
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
                        color: colors.background.withValues(alpha: 0.8),
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
            // custom buttons — hidden when a detail page is on top
            if (!detailPageActive.value)
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

            if (widget.selectedRoute == '/home' ||
                widget.selectedRoute == '/') ...[
              TapArea(
                child: const Icon(FIcons.settings),
                onTap: () => openSettings(context),
              ),
              SizedBox(width: 8),
              TapArea(
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
                      : Image.asset("assets/logo.png").image,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context,
    MainLayoutNavItem item, {
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
    final coverArt = playlist.coverArt;
    String? url;
    if (coverArt != null && coverArt.isNotEmpty) {
      try {
        url = subsonic.subsonic.cachedCoverArtUrl(coverArt, size: 80);
      } catch (_) {}
    }
    return _buildSidebarCover(url, FIcons.listMusic);
  }

  Widget _buildPlaylistsMenuContent(BuildContext context) {
    return Consumer<SubsonicProvider>(
      builder: (_, subsonic, _) {
        final active = subsonic.activeAccount;
        if (active == null) return const SizedBox.shrink();

        if (_playlistsFuture == null || _playlistsAccountId != active.id) {
          _playlistsAccountId = active.id;
          _playlistsFuture = _loadPlaylists(subsonic);
        }

        return _buildSidebarFutureList<Playlist>(
          context,
          future: _playlistsFuture,
          errorText: 'Could not load playlists',
          emptyText: 'No playlists found',
          itemBuilder: (playlist) => _buildSidebarEntry(
            context,
            label: playlist.name,
            icon: _buildPlaylistCoverPrefix(playlist, subsonic),
            route: '/library/playlist/${playlist.id}',
          ),
        );
      },
    );
  }

  Widget _buildSearchPillExpanded(BuildContext context) {
    final colors = context.theme.colors;

    return _buildGlassPill(
      context,
      child: SizedBox(
        height: 44,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 20, color: colors.mutedForeground),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _mobileSearchController,
                focusNode: _mobileSearchFocus,
                style: context.theme.typography.sm.copyWith(
                  color: colors.foreground,
                ),
                decoration: InputDecoration(
                  hintText: 'Search music...',
                  hintStyle: context.theme.typography.sm.copyWith(
                    color: colors.mutedForeground,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) => searchQuery.value = value,
                onSubmitted: (_) => _mobileSearchFocus.unfocus(),
              ),
            ),
            ValueListenableBuilder<String>(
              valueListenable: searchQuery,
              builder: (_, value, _) {
                if (value.isEmpty) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () {
                    searchQuery.value = '';
                    _mobileSearchFocus.requestFocus();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: colors.mutedForeground,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // icon that expands into the textfield on search
  Widget _buildSearchPillIcon(BuildContext context) {
    final searchNavItem = _mobilenavItems.firstWhere(
      (item) => item.label == 'Search',
    );

    return _buildGlassPill(
      context,
      child: _buildNavButton(context, searchNavItem, showLabel: false),
    );
  }

  Widget _buildSidebarCover(String? url, IconData fallbackIcon) {
    final fallback = Icon(fallbackIcon, size: 20, color: AppColors.auraColor);
    if (url == null || url.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image(
        image: coverArtProvider(url),
        width: 20,
        height: 20,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  Widget _buildSidebarEntry(
    BuildContext context, {
    required String label,
    required Widget icon,
    required String route,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: FSidebarItem(
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        icon: icon,
        selected: _isRouteSelected(route),
        onPress: () => _navigateTo(route),
        style: desktopSidebarItem(
          selectedBackgroundColor: AppColors.auraColor.withValues(alpha: 0.16),
          colors: context.theme.colors,
          typography: context.theme.typography,
          style: context.theme.style,
          touch: false,
        ),
      ),
    );
  }

  Widget _buildSidebarFutureList<T>(
    BuildContext context, {
    required Future<List<T>>? future,
    required String errorText,
    required String emptyText,
    required Widget Function(T item) itemBuilder,
  }) {
    Widget message(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        text,
        style: context.theme.typography.xs.copyWith(
          color: context.theme.colors.mutedForeground,
        ),
      ),
    );

    return FutureBuilder<List<T>>(
      future: future,
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

        if (snapshot.hasError) return message(errorText);

        final items = snapshot.data ?? <T>[];
        if (items.isEmpty) return message(emptyText);

        return Column(children: items.map(itemBuilder).toList());
      },
    );
  }

  Widget _buildStarredMenuContent(BuildContext context) {
    return Consumer<SubsonicProvider>(
      builder: (_, subsonic, _) {
        final active = subsonic.activeAccount;
        if (active == null) return const SizedBox.shrink();

        if (_starredAlbumsFuture == null || _starredAccountId != active.id) {
          _starredAccountId = active.id;
          _starredAlbumsFuture = _loadStarredAlbums(subsonic);
        }

        return _buildSidebarFutureList<Album>(
          context,
          future: _starredAlbumsFuture,
          errorText: 'Could not load starred albums',
          emptyText: 'No starred albums yet',
          itemBuilder: (album) => _buildSidebarEntry(
            context,
            label: album.name,
            icon: _buildAlbumCoverPrefix(album),
            route: '/library/album/${album.id}',
          ),
        );
      },
    );
  }

  String _getPageTitle() {
    if (_layoutConfig.title != null) return _layoutConfig.title!;
    return uriToTitle(widget.selectedRoute ?? '/home');
  }

  void _goBack(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/home');

  bool _isArtistRoute(String? route) =>
      route?.startsWith('/library/artist/') == true;

  bool _isDesktopMenuExpanded(String label) =>
      _desktopMenuExpanded[label] ?? true;

  bool _isDesktopMenuHovered(String label) =>
      _desktopMenuHovered[label] ?? false;

  bool _isMusicPageRoute(String? route) =>
      route?.startsWith('/library/album') == true ||
      route?.startsWith('/library/playlist') == true;

  bool _isRouteSelected(String baseRoute) =>
      _routeMatches(widget.selectedRoute, baseRoute);

  bool _isSearchRoute(String? route) => _routeMatches(route, '/search');

  bool _isSelected(MainLayoutNavItem item) =>
      widget.selectedRoute == item.route;

  Future<List<Playlist>> _loadPlaylists(SubsonicProvider subsonic) =>
      subsonic.subsonic.getPlaylists();

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

  // true when [route] is [baseRoute] itself or a query/child of it
  bool _routeMatches(String? route, String baseRoute) =>
      route == baseRoute ||
      route?.startsWith('$baseRoute?') == true ||
      route?.startsWith('$baseRoute/') == true;

  void _navigateTo(String route) {
    context.go(route);
  }

  void _onAccentChanged() {
    _accentHideTimer?.cancel();
    final color = accentColorNotifier.value;
    if (color != null) {
      _safeSetState(() {
        _accentColor = color;
        _accentVisible = true;
      });
    } else {
      _safeSetState(() => _accentVisible = false);
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
      _safeSetState(() {
        _coverUrl = url;
        _coverVisible = true;
      });
    } else {
      _safeSetState(() => _coverVisible = false);
      _coverHideTimer = Timer(const Duration(milliseconds: 750), () {
        if (mounted && coverUrlNotifier.value == null) {
          setState(() => _coverUrl = null);
        }
      });
    }
  }

  void _onDetailPageActiveChanged() {
    if (!detailPageActive.value) {
      _safeSetState(() {
        _layoutConfig = _frozenConfig ?? LayoutConfig.empty;
        _frozenConfig = null;
      });
    }
  }

  void _onLayoutConfigChanged() {
    if (detailPageActive.value) {
      _frozenConfig ??= _layoutConfig;
      return;
    }
    _safeSetState(() {
      _layoutConfig = layoutConfig.value;
    });
  }

  void _onPlaylistsSidebarChanged() {
    if (!mounted || isMobile(context)) return;
    _refreshPlaylists(context);
  }

  void _onScroll() {
    final double offset;
    if (_mobileScrollController.hasClients) {
      if (_mobileScrollController.offset < 0) return;
      offset = _mobileScrollController.offset;
    } else {
      offset = desktopScrollOffset.value;
    }

    final maxScroll = 250.0;
    var scrollOffset = offset.clamp(0.0, maxScroll);
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

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }

  void _setDesktopMenuHovered(String label, bool value) {
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
