import 'dart:io';

import 'package:cosmodrome/components/layouts/main_layout.dart';
import 'package:cosmodrome/pages/home.dart';
import 'package:cosmodrome/pages/login_page.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  usePathUrlStrategy();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  WidgetsFlutterBinding.ensureInitialized();

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

  router = _buildRouter(subsonicProvider.isAuthenticated ? '/home' : '/');

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
  routes: [
    // layout routes
    ShellRoute(
      routes: [
        // /
        GoRoute(
          path: '/',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomePage()),
        ),
      ],
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainLayout(selectedRoute: state.uri.toString(), child: child);
      },
    ),

    GoRoute(
      path: '/login',
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: LoginPage()),
    ),
  ],
);

class Application extends StatelessWidget {
  const Application({super.key});

  @override
  Widget build(BuildContext context) {
    final base =
        const <TargetPlatform>{
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.fuchsia,
        }.contains(defaultTargetPlatform)
        ? FThemes.neutral.dark.touch
        : FThemes.neutral.dark.desktop;

    final theme = base.copyWith(
      colors: base.colors.copyWith(background: AppColors.background),
    );

    return ChangeNotifierProvider.value(
      value: subsonicProvider,
      child: MaterialApp.router(
        supportedLocales: FLocalizations.supportedLocales,
        localizationsDelegates: const [
          ...FLocalizations.localizationsDelegates,
        ],
        debugShowCheckedModeBanner: false,
        theme: theme.toApproximateMaterialTheme().copyWith(
          pageTransitionsTheme: PageTransitionsTheme(
            builders: {
              // disable page transitions for ALL..
              TargetPlatform.android: SadPageTransition(),
              TargetPlatform.iOS: SadPageTransition(),
              TargetPlatform.linux: SadPageTransition(),
              TargetPlatform.macOS: SadPageTransition(),
              TargetPlatform.windows: SadPageTransition(),
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

class SadPageTransition extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
