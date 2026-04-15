import 'package:cosmodrome/components/forms/add_server_form.dart';
import 'package:cosmodrome/components/pill_header.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

class AddServerPage extends StatelessWidget {
  const AddServerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PillHeader(title: 'Add Server', onBack: () => context.pop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AddServerForm(onSuccess: () => context.pop()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
