import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:cosmodrome/components/custom_scroll_behaviour.dart';
import 'package:cosmodrome/components/layouts/main_layout.dart';
import 'package:cosmodrome/components/layouts/mobile_detail_layout.dart';
import 'package:cosmodrome/components/music_player/fullscreen_player.dart';
import 'package:cosmodrome/components/music_player/queue_sheet.dart';
// PAGES
import 'package:cosmodrome/pages/add_server_page.dart';
import 'package:cosmodrome/pages/add_user_page.dart';
import 'package:cosmodrome/pages/album_page.dart';
import 'package:cosmodrome/pages/artist_detail_page.dart';
import 'package:cosmodrome/pages/home.dart';
import 'package:cosmodrome/pages/library_page.dart';
import 'package:cosmodrome/pages/playlist_page.dart';
import 'package:cosmodrome/pages/search_page.dart';
import 'package:cosmodrome/services/offline_cache_service.dart'
    show SpotlightItem;
//
import 'package:cosmodrome/providers/download_provider.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/services/discord_rpc.dart';
import 'package:cosmodrome/services/local_storage_service.dart';
import 'package:cosmodrome/theme/theme.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  usePathUrlStrategy();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  WidgetsFlutterBinding.ensureInitialized();

  JustAudioMediaKit.ensureInitialized(
    linux: true,
    windows: true,
    android: false,
    iOS: true,
    macOS: true,
  );

  JustAudioMediaKit.title = "Cosmodrome";

  await JustAudioBackground.init(
    androidNotificationChannelId: 'me.rmfosho.cosmodrome.channel.audio',
    androidNotificationChannelName: 'Cosmodrome',
    androidNotificationOngoing: true,
  );

  final session = await AudioSession.instance;
  await session.configure(AudioSessionConfiguration.music());

  // DESKTOP ONLY!!!
  if (isDesktop) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(900, 900),
      minimumSize: Size(800, 800),
      center: true,
      title: 'Cosmodrome',
      skipTaskbar: false,
      titleBarStyle: .hidden,
      backgroundColor: Colors.transparent,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    await windowManager.setPreventClose(true);
  }

  await LocalStorageService.init();
  await subsonicProvider.tryRestoreSession();

  // load the new download manifest for when the user changes account
  subsonicProvider.addListener(() {
    final id = subsonicProvider.activeAccount?.id;
    if (id != null) downloadProvider.loadForAccount(id);
  });

  final initialId = subsonicProvider.activeAccount?.id;
  if (initialId != null) await downloadProvider.loadForAccount(initialId);

  router = _buildRouter('/home');

  runApp(const Application());
}

final downloadProvider = DownloadProvider();

final isDesktop =
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
late final GoRouter router;
final subsonicProvider = SubsonicProvider();

// go router
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter _buildRouter(String initialLocation) => GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: initialLocation,
  onException: (context, state, router) => router.go('/home'),
  routes: [
    ShellRoute(
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomePage()),
        ),

        GoRoute(
          path: '/library',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: LibraryPage()),
        ),

        GoRoute(
          path: '/search',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SearchPage()),
        ),

        if (isDesktop) ...[
          GoRoute(
            path: '/library/album/:id',
            pageBuilder: (context, state) => NoTransitionPage(
              child: AlbumPage(albumId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/library/playlist/:id',
            pageBuilder: (context, state) => NoTransitionPage(
              child: PlaylistPage(playlistId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/artist-detail/:id',
            pageBuilder: (context, state) => NoTransitionPage(
              child: ArtistDetailPage(item: state.extra as SpotlightItem),
            ),
          ),
        ],
      ],
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainLayout(selectedRoute: state.uri.toString(), child: child);
      },
    ),

    if (!isDesktop) ...[
      GoRoute(
        path: '/library/album/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CupertinoPage(
          child: MobileDetailLayout(
            isScrollable: true,
            child: AlbumPage(albumId: state.pathParameters['id']!),
          ),
        ),
      ),
      GoRoute(
        path: '/library/playlist/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CupertinoPage(
          child: MobileDetailLayout(
            isScrollable: false,
            child: PlaylistPage(playlistId: state.pathParameters['id']!),
          ),
        ),
      ),
      GoRoute(
        path: '/artist-detail/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CupertinoPage(
          child: ArtistDetailPage(item: state.extra as SpotlightItem),
        ),
      ),
    ],

    GoRoute(
      path: '/addserver',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const AddServerPage()),
    ),

    GoRoute(
      path: '/adduser',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const AddUserPage()),
    ),
  ],
);

class Application extends StatefulWidget {
  const Application({super.key});

  @override
  State<Application> createState() => _ApplicationState();
}

class _ApplicationState extends State<Application>
    with WindowListener, WidgetsBindingObserver {
  RpcBridge? _rpcBridge;

  @override
  Widget build(BuildContext context) {
    final isTouch = const <TargetPlatform>{
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.fuchsia,
    }.contains(defaultTargetPlatform);

    final theme = appTheme(touch: isTouch);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: subsonicProvider),
        ChangeNotifierProvider.value(value: downloadProvider),
        ChangeNotifierProxyProvider<SubsonicProvider, PlayerProvider>(
          create: (_) =>
              PlayerProvider()..setDownloadProvider(downloadProvider),
          update: (_, sub, player) => player!..update(sub),
        ),
        if (isDesktop && _rpcBridge != null)
          ChangeNotifierProxyProvider<PlayerProvider, RpcBridge>(
            lazy: false,
            create: (_) => _rpcBridge!,
            update: (_, player, rpc) => rpc!..update(player),
          ),
      ],
      child: MaterialApp.router(
        supportedLocales: FLocalizations.supportedLocales,
        localizationsDelegates: const [
          ...FLocalizations.localizationsDelegates,
        ],
        scrollBehavior: ScrollBehaviorModified(),
        debugShowCheckedModeBanner: false,
        theme: theme.toApproximateMaterialTheme().copyWith(
          scaffoldBackgroundColor: AppColors.background,
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
              TargetPlatform.macOS: _NoTransition(),
              TargetPlatform.windows: _NoTransition(),
              TargetPlatform.linux: _NoTransition(),
              TargetPlatform.fuchsia: _NoTransition(),
            },
          ),
        ),
        routerConfig: router,
        builder: (_, child) => SafeArea(
          bottom: false,
          left: false,
          top: false,
          right: false,
          child: Material(
            color: AppColors.background,
            child: FTheme(
              data: theme,
              child: FToaster(
                child: FTooltipGroup(
                  child: Stack(
                    children: [
                      child!,
                      if (!isDesktop)
                        Positioned.fill(
                          child: const _FullscreenPlayerOverlay(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    subsonicProvider.setAppLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (isDesktop) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    subsonicProvider.setAppLifecycleState(AppLifecycleState.resumed);
    if (isDesktop) {
      windowManager.addListener(this);
      _rpcBridge = RpcBridge()..init();
      windowManager.setMinimumSize(const Size(800, 800)); // ensure!!!
    }
  }

  @override
  Future<void> onWindowClose() async {
    await windowManager.hide();
    await _rpcBridge?.shutdown();
    await windowManager.destroy();
  }
}

class _FullscreenPlayerOverlay extends StatefulWidget {
  const _FullscreenPlayerOverlay();

  @override
  State<_FullscreenPlayerOverlay> createState() =>
      _FullscreenPlayerOverlayState();
}

class _FullscreenPlayerOverlayState extends State<_FullscreenPlayerOverlay> {
  // fullscreen player drag
  double _playerDragOffset = 0;

  // queue state
  bool _queueOpen = false;
  double _queueDragOffset = 0;
  double? _queueDragStartY;

  late PlayerProvider _playerProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    _playerProvider.addListener(_onPlayerChanged);
  }

  @override
  void dispose() {
    _playerProvider.removeListener(_onPlayerChanged);
    super.dispose();
  }

  void _onPlayerChanged() {
    if (!_playerProvider.isFullscreenOpen && _queueOpen && mounted) {
      _closeQueue();
    }
  }

  void _openQueue() {
    if (!_queueOpen) setState(() => _queueOpen = true);
  }

  void _closeQueue() {
    if (!_queueOpen) return;
    setState(() => _queueOpen = false);
    // reset drag after exit animation finishes
    Future.delayed(const Duration(milliseconds: 310), () {
      if (mounted) setState(() => _queueDragOffset = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, player, _) {
        if (!player.hasCurrentSong) return const SizedBox.shrink();

        final queueVisible = _queueOpen && player.isFullscreenOpen;
        final screenHeight = MediaQuery.of(context).size.height;
        final sheetHeight = screenHeight * 0.7;

        return Stack(
          children: [
            IgnorePointer(
              ignoring: !player.isFullscreenOpen,
              child: AnimatedSlide(
                offset: Offset(0, player.isFullscreenOpen ? 0 : 1),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                child: Transform.translate(
                  offset: Offset(0, _playerDragOffset),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (details) {
                      final delta = details.primaryDelta ?? 0;
                      if (_playerDragOffset > 0 || delta > 0) {
                        setState(() {
                          _playerDragOffset =
                              (_playerDragOffset + delta).clamp(
                                0,
                                double.infinity,
                              );
                        });
                      }
                    },
                    onVerticalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (velocity > 500 ||
                          _playerDragOffset > screenHeight * 0.25) {
                        player.closeFullscreen();
                        Future.delayed(const Duration(milliseconds: 350), () {
                          if (mounted) setState(() => _playerDragOffset = 0);
                        });
                      } else {
                        setState(() => _playerDragOffset = 0);
                      }
                    },
                    onVerticalDragCancel: () =>
                        setState(() => _playerDragOffset = 0),
                    child: RepaintBoundary(
                      child: FullscreenPlayer(onQueueOpen: _openQueue),
                    ),
                  ),
                ),
              ),
            ),

            if (queueVisible)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeQueue,
                  child: const ColoredBox(color: Colors.black54),
                ),
              ),

            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) {
                if (!queueVisible) return;
                // only track drags that start inside the sheet area
                if (e.position.dy > screenHeight - sheetHeight) {
                  _queueDragStartY = e.position.dy;
                }
              },
              onPointerMove: (e) {
                if (_queueDragStartY == null || !queueVisible) return;
                final dy = e.position.dy - _queueDragStartY!;
                if (dy > 0) setState(() => _queueDragOffset = dy);
              },
              onPointerUp: (e) {
                if (_queueDragStartY == null) return;
                final dy = e.position.dy - _queueDragStartY!;
                _queueDragStartY = null;
                if (dy > sheetHeight * 0.25) {
                  _closeQueue();
                } else {
                  setState(() => _queueDragOffset = 0);
                }
              },
              onPointerCancel: (_) => setState(() {
                _queueDragOffset = 0;
                _queueDragStartY = null;
              }),
              child: IgnorePointer(
                ignoring: !queueVisible,
                child: AnimatedSlide(
                  offset: Offset(0, queueVisible ? 0 : 1),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: Transform.translate(
                    offset: Offset(0, _queueDragOffset),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: 0.7,
                        widthFactor: 1,
                        child: QueueSheet(onClose: _closeQueue),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NoTransition extends PageTransitionsBuilder {
  const _NoTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
