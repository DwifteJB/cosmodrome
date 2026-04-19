import 'package:cosmodrome/theme/sidebar_item_style.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class MainLayoutDesktopSidebar extends StatelessWidget {
  final Widget header;
  final Widget footer;
  final List<MainLayoutNavMenu> navMenus;
  final bool isRefreshingStarred;
  final bool isRefreshingPlaylists;
  final bool Function(String label) isMenuExpanded;
  final bool Function(String label) isMenuHovered;
  final bool Function(MainLayoutNavItem item) isItemSelected;
  final void Function(String label, bool value) onMenuHoverChanged;
  final void Function(String label) onMenuToggle;
  final VoidCallback onRefreshStarred;
  final VoidCallback onRefreshPlaylists;
  final void Function(String route) onNavigate;
  final Widget Function(BuildContext context) buildStarredContent;
  final Widget Function(BuildContext context) buildPlaylistsContent;

  const MainLayoutDesktopSidebar({
    super.key,
    required this.header,
    required this.footer,
    required this.navMenus,
    required this.isRefreshingStarred,
    required this.isRefreshingPlaylists,
    required this.isMenuExpanded,
    required this.isMenuHovered,
    required this.isItemSelected,
    required this.onMenuHoverChanged,
    required this.onMenuToggle,
    required this.onRefreshStarred,
    required this.onRefreshPlaylists,
    required this.onNavigate,
    required this.buildStarredContent,
    required this.buildPlaylistsContent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;

    return FSidebar(
      style: .delta(
        contentPadding: .add(
          const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        ),
        footerPadding: .add(const EdgeInsets.symmetric(horizontal: 12)),
        decoration: .boxDelta(color: AppColors.sidebar),
      ),
      header: header,
      footer: footer,
      children: navMenus
          .map(
            (menu) => FSidebarGroup(
              key: ValueKey('desktop-group-${menu.label}'),
              label: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => onMenuHoverChanged(menu.label, true),
                onExit: (_) => onMenuHoverChanged(menu.label, false),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onMenuToggle(menu.label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isMenuHovered(menu.label)
                          ? AppColors.sidebarSelected
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(menu.label)),
                        AnimatedRotation(
                          turns: isMenuExpanded(menu.label) ? 0.0 : -0.25,
                          duration: const Duration(milliseconds: 180),
                          child: const Icon(FIcons.chevronDown, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              style: .delta(padding: .delta(left: 0, right: 0)),
              action: (menu.label == 'Starred' || menu.label == 'Playlists')
                  ? Tooltip(
                      message: menu.label == 'Starred'
                          ? 'Refresh starred'
                          : 'Refresh playlists',
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: (menu.label == 'Starred'
                                ? isRefreshingStarred
                                : isRefreshingPlaylists)
                            ? const Padding(
                                padding: EdgeInsets.all(2),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh, size: 16),
                      ),
                    )
                  : null,
              onActionPress: menu.label == 'Starred'
                  ? onRefreshStarred
                  : menu.label == 'Playlists'
                  ? onRefreshPlaylists
                  : null,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: ClipRect(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 170),
                      curve: Curves.easeOut,
                      opacity: isMenuExpanded(menu.label) ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !isMenuExpanded(menu.label),
                        child: isMenuExpanded(menu.label)
                            ? Column(
                                children: [
                                  ...menu.items.map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 2,
                                      ),
                                      child: FSidebarItem(
                                        label: Text(item.label),
                                        icon: Icon(
                                          item.icon,
                                          size: 20,
                                          color: AppColors.auraColor,
                                        ),
                                        selected: isItemSelected(item),
                                        onPress: () => onNavigate(item.route),
                                        style: desktopSidebarItem(
                                          selectedBackgroundColor: AppColors
                                              .auraColor
                                              .withValues(alpha: 0.16),
                                          colors: colors,
                                          typography: context.theme.typography,
                                          style: context.theme.style,
                                          touch: false,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (menu.label == 'Starred')
                                    buildStarredContent(context),
                                  if (menu.label == 'Playlists')
                                    buildPlaylistsContent(context),
                                  if (menu.builder != null) menu.builder!(context),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

class MainLayoutNavItem {
  final String label;
  final String route;
  final IconData icon;

  const MainLayoutNavItem({
    required this.label,
    required this.route,
    required this.icon,
  });
}

class MainLayoutNavMenu {
  final String label;
  final List<MainLayoutNavItem> items;
  final Widget Function(BuildContext context)? builder;

  const MainLayoutNavMenu({
    required this.label,
    this.items = const [],
    this.builder,
  });
}
