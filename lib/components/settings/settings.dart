import 'package:cosmodrome/components/mobile/profile_sheet.dart';
import 'package:cosmodrome/components/settings/cache_settings_page.dart';
import 'package:cosmodrome/components/settings/settings_shell.dart';
import 'package:cosmodrome/pages/downloads_page.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class AccountsSettingsPage extends StatelessWidget {
  const AccountsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileSheet();
  }
}

final settingsItems = <SettingsItem>[
  SettingsItem(
    title: 'Accounts',
    icon: FIcons.user,
    content: const AccountsSettingsPage(),
    onMobileTap: (ctx) => showFSheet(
      context: ctx,
      side: FLayout.btt,
      mainAxisMaxRatio: null,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => const ProfileSheet(),
    ),
  ),
  SettingsItem(
    title: 'Downloads',
    icon: FIcons.download,
    content: const DownloadsSettingsPage(),
    onMobileTap: (ctx) => showFSheet(
      context: ctx,
      side: FLayout.btt,
      mainAxisMaxRatio: 0.92,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => const MobileSettingsSheetWrapper(
        title: 'Downloads',
        child: DownloadsSettingsPage(),
      ),
    ),
  ),
  SettingsItem(
    title: 'Cache',
    icon: FIcons.database,
    content: const CacheSettingsPage(),
    onMobileTap: (ctx) => showFSheet(
      context: ctx,
      side: FLayout.btt,
      mainAxisMaxRatio: 0.9,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => const MobileSettingsSheetWrapper(
        title: 'Cache',
        child: CacheSettingsPage(),
      ),
    ),
  ),
];

class SettingsItem {
  final IconData? icon;
  final String title;
  final Widget content;
  final void Function(BuildContext)? onMobileTap;
  final void Function(BuildContext)? onDesktopTap;

  const SettingsItem({
    required this.title,
    required this.content,
    this.icon,
    this.onMobileTap,
    this.onDesktopTap,
  });
}
