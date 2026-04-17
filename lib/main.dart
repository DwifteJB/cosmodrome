import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:cosmodrome/components/custom_scroll_behaviour.dart';
import 'package:cosmodrome/components/layouts/main_layout.dart';
// PAGES
import 'package:cosmodrome/pages/add_server_page.dart';
import 'package:cosmodrome/pages/add_user_page.dart';
import 'package:cosmodrome/pages/album_page.dart';
import 'package:cosmodrome/pages/playlist_page.dart';
import 'package:cosmodrome/pages/home.dart';
import 'package:cosmodrome/pages/library_page.dart';
//
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/theme/theme.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    linux: true, // default: true  - dependency: media_kit_libs_linux
    windows: true, // default: true  - dependency: media_kit_libs_windows_audio
    android: false,
    iOS: true, // default: false - dependency: media_kit_libs_ios_audio
    macOS: true, // default: false - dependency: media_kit_libs_macos_audio
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
      minimumSize: Size(800, 800), // x never below 768
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
  }

  await subsonicProvider.tryRestoreSession();

  router = _buildRouter('/home');

  runApp(const Application());
}

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
      ],
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainLayout(selectedRoute: state.uri.toString(), child: child);
      },
    ),

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

class Application extends StatelessWidget {
  const Application({super.key});

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
        ChangeNotifierProxyProvider<SubsonicProvider, PlayerProvider>(
          create: (_) => PlayerProvider(),
          update: (_, sub, player) => player!..update(sub),
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
              child: FToaster(child: FTooltipGroup(child: child!)),
            ),
          ),
        ),
      ),
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
