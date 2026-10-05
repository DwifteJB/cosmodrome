import 'dart:io';

import 'package:cosmodrome/utils/colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

const _titlebarHeight = 32.0;

final _isDesktop =
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

class InfoSettingsButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData? icon;
  final String title;

  const InfoSettingsButton({
    super.key,
    this.onTap,
    required this.title,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return (GestureDetector(
      onTap: () => onTap?.call(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.sidebarSelected,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            if (icon != null)
              Icon(icon, size: 18, color: colors.mutedForeground),
            const SizedBox(width: 12),
            Text(
              title,
              style: context.theme.typography.sm.copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(FIcons.chevronRight, size: 16, color: colors.mutedForeground),
          ],
        ),
      ),
    ));
  }
}

class InfoSettingsPage extends StatelessWidget {
  const InfoSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Row(
            children: [
              Text(
                'Info',
                style: context.theme.typography.xl.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    FIcons.x,
                    size: 20,
                    color: colors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 44,
                        height: 44,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Cosmodrome',
                      style: context.theme.typography.lg.copyWith(
                        color: colors.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                InfoSettingsButton(
                  title: 'Licenses',
                  icon: FIcons.scale,
                  onTap: () => _showLicenses(context),
                ),
                const SizedBox(height: 12),
                InfoSettingsButton(
                  title: 'Privacy Policy',
                  icon: FIcons.shield,
                  onTap: () => launchUrl(
                    Uri.parse(
                      'https://raw.githubusercontent.com/DwifteJB/cosmodrome/refs/heads/main/privacy-policy.md',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InfoSettingsButton(
                  title: 'Github',
                  icon: FIcons.github,
                  onTap: () => launchUrl(
                    Uri.parse('https://github.com/DwifteJB/cosmodrome'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // same page showLicensePage() pushes, with room for the window buttons
  void _showLicenses(BuildContext context) {
    final theme = Theme.of(context);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (context) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: _isDesktop
                ? mq.copyWith(
                    padding: mq.padding.copyWith(top: _titlebarHeight),
                  )
                : mq,
            child: Theme(
              data: theme.copyWith(
                textTheme: theme.textTheme.apply(heightFactor: 1.4),
              ),
              child: Stack(
                children: [
                  LicensePage(
                    applicationName: 'Cosmodrome',
                    applicationIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 64,
                        height: 64,
                      ),
                    ),
                  ),
                  if (_isDesktop)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: _titlebarHeight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanStart: (_) => windowManager.startDragging(),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
