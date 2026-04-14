import 'package:cosmodrome/helpers/subsonic-api-helper/api/basic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

void main() {
  runApp(const Application());
}

class Application extends StatelessWidget {
  const Application({super.key});

  @override
  Widget build(BuildContext context) {
    /// Try changing this and hot reloading the application.
    ///
    /// To create a custom theme:
    /// ```shell
    /// dart forui theme create [theme template].
    /// ```
    final theme =
        const <TargetPlatform>{
          .android,
          .iOS,
          .fuchsia,
        }.contains(defaultTargetPlatform)
        ? FThemes.neutral.dark.touch
        : FThemes.neutral.dark.desktop;

    return MaterialApp(
      supportedLocales: FLocalizations.supportedLocales,
      localizationsDelegates: const [...FLocalizations.localizationsDelegates],
      debugShowCheckedModeBanner: false,

      theme: theme.toApproximateMaterialTheme(),
      builder: (_, child) => FTheme(
        data: theme,
        child: FToaster(child: FTooltipGroup(child: child!)),
      ),
      home: const FScaffold(
        // TODO: replace with your widget.
        child: Example(),
      ),
    );
  }
}

class Example extends StatefulWidget {
  const Example({super.key});

  @override
  State<Example> createState() => _ExampleState();
}

class _ExampleState extends State<Example> {
  String error = '';

  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: .min,
      spacing: 10,
      children: [
        if (error.isNotEmpty)
          Text(error, style: TextStyle(color: context.theme.colors.error)),
        Text('test login'),
        FTextField(
          label: Text('username'),
          obscuringCharacter: '*',
          control: .managed(controller: usernameController),
        ),
        FTextField(
          label: Text('password'),
          obscuringCharacter: '*',
          control: .managed(controller: passwordController),
        ),

        FButton(onPress: () => login(), child: Text('login')),
      ],
    ),
  );

  void login() async {
    setState(() => error = '');

    // use subsonic to login

    Subsonic sub = Subsonic(
      baseUrl: "http://localhost:4533",
      username: usernameController.value.text,
      password: passwordController.value.text,
    );

    final success = await sub.ping();

    if (success.success) {
      setState(() => error = 'login successful');
    } else {
      loggerPrint('login failed');
      setState(() => error = success.errorMessage ?? 'unknown error');
    }
  }

}
