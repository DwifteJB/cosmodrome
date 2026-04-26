import 'dart:io';

import 'package:cosmodrome/components/settings/settings.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

final _isDesktop =
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

void openSettings(BuildContext context) {
  if (_isDesktop) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) =>
          FTheme(data: context.theme, child: const _SettingsDesktopShell()),
    );
  } else {
    showFSheet(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: 0.85,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => const _SettingsMobileShell(),
    );
  }
}

class _SettingsDesktopShell extends StatefulWidget {
  const _SettingsDesktopShell();

  @override
  State<_SettingsDesktopShell> createState() => _SettingsDesktopShellState();
}

class _SettingsDesktopShellState extends State<_SettingsDesktopShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final items = settingsItems;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 500),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Material(
            color: AppColors.background,
            child: Row(
              children: [
                // left nav
                Container(
                  width: 180,
                  color: AppColors.sidebarSelected,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                        child: Text(
                          'Settings',
                          style: context.theme.typography.lg.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.foreground,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final item = items[i];
                            final selected = i == _selectedIndex;
                            return _NavItem(
                              icon: item.icon,
                              label: item.title,
                              selected: selected,
                              onTap: () => setState(() => _selectedIndex = i),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // divider
                VerticalDivider(width: 1, thickness: 1, color: colors.border),

                // right content
                Expanded(child: items[_selectedIndex].content),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData? icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final bg = widget.selected
        ? colors.primary.withValues(alpha: 0.15)
        : _hovered
        ? colors.muted
        : Colors.transparent;
    final fg = widget.selected ? colors.primary : colors.foreground;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 16, color: fg),
                const SizedBox(width: 10),
              ],
              Text(
                widget.label,
                style: context.theme.typography.sm.copyWith(
                  color: fg,
                  fontWeight: widget.selected
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps any settings content widget with the standard mobile sheet chrome
/// (background, rounded top corners, drag handle). Use this in onMobileTap
/// for pages that are also embedded as desktop panel content.
class MobileSettingsSheetWrapper extends StatelessWidget {
  final Widget child;
  final String title;

  const MobileSettingsSheetWrapper({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;

    return Material(
      color: AppColors.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _SettingsMobileShell extends StatelessWidget {
  const _SettingsMobileShell();

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final items = settingsItems;

    return Material(
      color: AppColors.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Settings',
                style: context.theme.typography.xl.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (ctx, i) {
                  final item = items[i];
                  return ListTile(
                    tileColor: AppColors.sidebarSelected,
                    leading: item.icon != null
                        ? Icon(item.icon, size: 20, color: colors.foreground)
                        : null,
                    title: Text(
                      item.title,
                      style: context.theme.typography.sm.copyWith(
                        color: colors.foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Icon(
                      FIcons.chevronRight,
                      size: 16,
                      color: colors.mutedForeground,
                    ),
                    onTap: () => item.onMobileTap?.call(ctx),
                    style: ListTileStyle.list,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
