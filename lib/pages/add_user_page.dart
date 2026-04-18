import 'package:cosmodrome/components/forms/add_user_form.dart';
import 'package:cosmodrome/components/pill_header.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

class AddUserPage extends StatelessWidget {
  const AddUserPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PillHeader(title: 'Add Account'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AddUserForm(
                  onSuccess: () => context.pop(),
                  onAddServerPressed: () =>
                      context.push<SubsonicServer>('/addserver'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
