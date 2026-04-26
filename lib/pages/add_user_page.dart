import 'package:cosmodrome/components/forms/add_user_form.dart';
import 'package:cosmodrome/components/mobile/pill_header.dart';
import 'package:cosmodrome/providers/subsonic_account.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

class AddUserPage extends StatelessWidget {
  final SubsonicAccount? initialAccount;

  const AddUserPage({super.key, this.initialAccount});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final isEditing = initialAccount != null;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PillHeader(title: isEditing ? 'Edit Account' : 'Add Account'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AddUserForm(
                  initialAccount: initialAccount,
                  onSuccess: () => context.pop(),
                  onAddServerPressed: isEditing
                      ? null
                      : () => context.push<SubsonicServer>('/addserver'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
