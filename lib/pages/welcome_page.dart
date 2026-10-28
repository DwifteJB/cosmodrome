import 'dart:io';

import 'package:cosmodrome/components/desktop/desktop_titlebar.dart';
import 'package:cosmodrome/components/forms/add_server_form.dart';
import 'package:cosmodrome/components/forms/add_user_form.dart';
import 'package:cosmodrome/components/settings/local_files_settings_page.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/services/local_music/local_music_service.dart';
import 'package:cosmodrome/services/onboarding_service.dart';
import 'package:cosmodrome/utils/open_folder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

enum _Step { welcome, source, server, account, local }

class WelcomePage extends StatefulWidget {
  final bool showTitlebar;

  const WelcomePage({super.key, this.showTitlebar = false});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  _Step _step = _Step.welcome;
  SubsonicServer? _server;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          if (widget.showTitlebar) const DesktopTitlebar(),
          Expanded(
            child: SafeArea(
              top: !widget.showTitlebar,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: _buildStep(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case _Step.welcome:
        return _WelcomeStep(onNext: () => _go(_Step.source));
      case _Step.source:
        return _StepLayout(
          step: 1,
          title: 'Add an Account',
          description: 'Choose where your music comes from.',
          onBack: () => _go(_Step.welcome),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SourceOption(
                icon: FIcons.server,
                title: 'Server',
                description:
                    'Connect to any Subsonic Server. (Requires a Subsonic server.)',
                onTap: () => _go(_Step.server),
              ),
              const SizedBox(height: 12),
              _SourceOption(
                icon: FIcons.folder,
                title: 'Local',
                description: 'Play music stored on this device.',
                onTap: () => _go(_Step.local),
              ),
            ],
          ),
        );
      case _Step.server:
        var tapText = "tap";

        if (!kIsWeb &&
            (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
          tapText = "click";
        }

        return _StepLayout(
          step: 2,
          title: 'Add Server',
          description:
              'Enter the address of your server. Servers found within your local network will show up below, $tapText one to use it.',
          onBack: () => _go(_Step.source),
          child: AddServerForm(
            onSuccess: (server) {
              _server = server;
              _go(_Step.account);
            },
          ),
        );
      case _Step.account:
        return _StepLayout(
          step: 3,
          title: 'Add Account',
          description:
              'Sign in with the username and password you use for ${_server?.name ?? 'your server'}.',
          onBack: () => _go(_Step.server),
          child: AddUserForm(initialServer: _server, onSuccess: _finish),
        );
      case _Step.local:
        return _StepLayout(
          step: 2,
          title: 'Local Files',
          description: localFilesHint(localMusicService.musicDirectory),
          onBack: () => _go(_Step.source),
          child: _LocalStep(onDone: _useLocal),
        );
    }
  }

  void _go(_Step step) => setState(() => _step = step);

  void _useLocal() {
    final provider = context.read<SubsonicProvider>();
    final local = provider.accounts.where((a) => a.isLocal).firstOrNull;
    if (local != null) provider.switchAccount(local.id);
    _finish();
  }

  Future<void> _finish() async {
    await OnboardingService.markComplete();
    if (mounted) context.go('/home');
  }
}

class _WelcomeStep extends StatelessWidget {
  final VoidCallback onNext;

  const _WelcomeStep({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset('assets/logo.png', width: 88, height: 88),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Welcome to Cosmodrome',
          textAlign: TextAlign.center,
          style: typography.xl2.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Let's get your music set up. It only takes a minute.",
          textAlign: TextAlign.center,
          style: typography.md.copyWith(color: colors.mutedForeground),
        ),
        const SizedBox(height: 32),
        FButton(onPress: onNext, child: const Text('Get Started')),
      ],
    );
  }
}

class _StepLayout extends StatelessWidget {
  final int step;
  final String title;
  final String description;
  final VoidCallback onBack;
  final Widget child;

  const _StepLayout({
    required this.step,
    required this.title,
    required this.description,
    required this.onBack,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border),
                ),
                child: Icon(
                  FIcons.chevronLeft,
                  size: 18,
                  color: colors.foreground,
                ),
              ),
            ),
            const Spacer(),
            Text(
              'Step $step',
              style: typography.sm.copyWith(color: colors.mutedForeground),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: typography.xl2.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: typography.sm.copyWith(color: colors.mutedForeground),
        ),
        const SizedBox(height: 24),
        child,
      ],
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;

    return Material(
      color: colors.muted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: colors.foreground),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typography.md.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: typography.sm.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                FIcons.chevronRight,
                size: 18,
                color: colors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalStep extends StatelessWidget {
  final VoidCallback onDone;

  const _LocalStep({required this.onDone});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final local = context.watch<LocalMusicService>();
    final count = local.count;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.muted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(FIcons.folder, size: 18, color: colors.mutedForeground),
              const SizedBox(width: 12),
              Text(
                localFilesAlbumName,
                style: context.theme.typography.sm.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (local.isScanning)
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.mutedForeground,
                  ),
                )
              else
                Text(
                  '$count song${count == 1 ? '' : 's'}',
                  style: context.theme.typography.sm.copyWith(
                    color: colors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FButton(
          variant: FButtonVariant.outline,
          onPress: () => importLocalMusic(context),
          child: const Text('Import Music'),
        ),
        if (!kIsWeb && local.canOpenFolder && canOpenFolders) ...[
          const SizedBox(height: 8),
          FButton(
            variant: FButtonVariant.outline,
            onPress: () => openLocalMusicFolder(context),
            child: const Text('Open Music Folder'),
          ),
        ],
        const SizedBox(height: 8),
        FButton(
          variant: FButtonVariant.outline,
          onPress: local.isScanning ? null : local.scan,
          child: const Text('Rescan'),
        ),
        const SizedBox(height: 24),
        FButton(onPress: onDone, child: const Text('Done')),
        const SizedBox(height: 12),
        Text(
          'You can add a server at any time from your profile.',
          textAlign: TextAlign.center,
          style: context.theme.typography.xs.copyWith(
            color: colors.mutedForeground,
          ),
        ),
      ],
    );
  }
}
