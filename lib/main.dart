import 'package:cosmodrome/pages/login_page.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

final subsonicProvider = SubsonicProvider();

void main() async {
  usePathUrlStrategy();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  WidgetsFlutterBinding.ensureInitialized();

  await subsonicProvider.tryRestoreSession();

  router = _buildRouter(
    subsonicProvider.isAuthenticated ? '/home' : '/',
  );

  runApp(const Application());
}
late final GoRouter router;

// go router
final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter _buildRouter(String initialLocation) => GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: LoginPage()),
    ),
  ],
);


class Application extends StatelessWidget {
  const Application({super.key});

  @override
  Widget build(BuildContext context) {
    final theme =
        const <TargetPlatform>{
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.fuchsia,
        }.contains(defaultTargetPlatform)
        ? FThemes.neutral.dark.touch
        : FThemes.neutral.dark.desktop;

    return ChangeNotifierProvider.value(
      value: subsonicProvider,
      child: MaterialApp.router(
        supportedLocales: FLocalizations.supportedLocales,
        localizationsDelegates: const [
          ...FLocalizations.localizationsDelegates,
        ],
        debugShowCheckedModeBanner: false,
        theme: theme.toApproximateMaterialTheme(),
        routerConfig: router,
        builder: (_, child) => FTheme(
          data: theme,
          child: Material(
            child: FToaster(
              child: FTooltipGroup(child: child ?? const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
  }
}
