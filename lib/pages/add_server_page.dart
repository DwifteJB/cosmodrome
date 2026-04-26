import 'package:cosmodrome/components/forms/add_server_form.dart';
import 'package:cosmodrome/components/mobile/pill_header.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

class AddServerPage extends StatefulWidget {
  final SubsonicServer? initialServer;

  const AddServerPage({super.key, this.initialServer});

  @override
  State<AddServerPage> createState() => _AddServerPageState();
}

class _AddServerPageState extends State<AddServerPage> {
  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final isEditing = widget.initialServer != null;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PillHeader(
              title: isEditing ? 'Edit Server' : 'Add Server',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AddServerForm(
                  initialServer: widget.initialServer,
                  onSuccess: (server) => context.pop(server),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
