import 'package:cosmodrome/components/mobile/profile_sheet.dart';
import 'package:cosmodrome/components/settings/cache_settings_page.dart';
import 'package:cosmodrome/components/settings/info_settings_page.dart';
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

void _showSettingsSheet(
  BuildContext context, {
  required double? mainAxisMaxRatio,
  required Widget child,
}) => showFSheet(
  context: context,
  side: FLayout.btt,
  mainAxisMaxRatio: mainAxisMaxRatio,
  useSafeArea: true,
  useRootNavigator: true,
  builder: (_) => child,
);

final settingsItems = <SettingsItem>[
  SettingsItem(
    title: 'Accounts',
    icon: FIcons.user,
    content: const AccountsSettingsPage(),
    onMobileTap: (ctx) => _showSettingsSheet(
      ctx,
      mainAxisMaxRatio: null,
      child: const ProfileSheet(),
    ),
  ),
  SettingsItem(
    title: 'Downloads',
    icon: FIcons.download,
    content: const DownloadsSettingsPage(),
    onMobileTap: (ctx) => _showSettingsSheet(
      ctx,
      mainAxisMaxRatio: 0.92,
      child: const MobileSettingsSheetWrapper(child: DownloadsSettingsPage()),
    ),
  ),
  SettingsItem(
    title: 'Cache',
    icon: FIcons.database,
    content: const CacheSettingsPage(),
    onMobileTap: (ctx) => _showSettingsSheet(
      ctx,
      mainAxisMaxRatio: 0.9,
      child: const MobileSettingsSheetWrapper(child: CacheSettingsPage()),
    ),
  ),
  SettingsItem(
    title: 'Info',
    icon: FIcons.info,
    content: const InfoSettingsPage(),
    onMobileTap: (ctx) => _showSettingsSheet(
      ctx,
      mainAxisMaxRatio: 0.5,
      child: const MobileSettingsSheetWrapper(child: InfoSettingsPage()),
    ),
  ),
];

class SettingsItem {
  final IconData? icon;
  final String title;
  final Widget content;
  final void Function(BuildContext)? onMobileTap;

  const SettingsItem({
    required this.title,
    required this.content,
    this.icon,
    this.onMobileTap,
  });
}
