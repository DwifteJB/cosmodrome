import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubsonicProvider>();
    final isLoading = provider.authState == AuthState.loading;

    final activeAccount = provider.activeAccount;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          if (activeAccount != null)
            Text('Logged in as ${activeAccount.user.username} on ${activeAccount.baseUrl}'),
          if (provider.errorMessage != null)
            Text(
              provider.errorMessage!,
              style: TextStyle(color: context.theme.colors.error),
            ),
          FTextField(
            label: const Text('Server URL'),
            hint: 'localhost:4533',
            control: FTextFieldControl.managed(controller: _serverController),
            autocorrect: false,
          ),
          FTextField(
            label: const Text('Username'),
            control: FTextFieldControl.managed(controller: _usernameController),
            autocorrect: false,
          ),
          FTextField.password(
            label: const Text('Password'),
            control: FTextFieldControl.managed(controller: _passwordController),
            
          ),
          FButton(
            onPress: isLoading ? null : _login,
            child: isLoading ? const CircularProgressIndicator() : const Text('Login'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final error = await context.read<SubsonicProvider>().addAccount(
      baseUrl: _serverController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (error == null && mounted) {
      // TODO: navigate on success
    }
  }
}
