import 'package:cosmodrome/components/home/home_sections.dart';
import 'package:cosmodrome/services/home_layout_service.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

void showCustomizeHomeDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) =>
        FTheme(data: context.theme, child: const _CustomizeHomeDialog()),
  );
}

class _CustomizeHomeDialog extends StatelessWidget {
  const _CustomizeHomeDialog();

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final available = [for (final s in homeSections) s.id];
    final byId = {for (final s in homeSections) s.id: s};

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Material(
            color: AppColors.background,
            child: ListenableBuilder(
              listenable: homeLayoutService,
              builder: (context, _) {
                final active = homeLayoutService.resolve(available);
                final hidden = available
                    .where((id) => !active.contains(id))
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                      child: Row(
                        children: [
                          Text(
                            'Customize Home',
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
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [
                          const _SectionLabel('On your home page'),
                          if (active.isEmpty)
                            const _EmptyHint('No sections shown.'),
                          for (var i = 0; i < active.length; i++)
                            _SectionRow(
                              title: byId[active[i]]!.title,
                              actions: [
                                _RowAction(
                                  icon: FIcons.chevronUp,
                                  onTap: i == 0
                                      ? null
                                      : () => homeLayoutService.move(
                                          available,
                                          active[i],
                                          -1,
                                        ),
                                ),
                                _RowAction(
                                  icon: FIcons.chevronDown,
                                  onTap: i == active.length - 1
                                      ? null
                                      : () => homeLayoutService.move(
                                          available,
                                          active[i],
                                          1,
                                        ),
                                ),
                                _RowAction(
                                  icon: FIcons.x,
                                  destructive: true,
                                  onTap: () => homeLayoutService.remove(
                                    available,
                                    active[i],
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 12),
                          const _SectionLabel('Add sections'),
                          if (hidden.isEmpty)
                            const _EmptyHint('theyre all placed Wow!'),
                          for (final id in hidden)
                            _SectionRow(
                              title: byId[id]!.title,
                              muted: true,
                              actions: [
                                _RowAction(
                                  icon: FIcons.plus,
                                  onTap: () =>
                                      homeLayoutService.add(available, id),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: colors.border)),
                      ),
                      child: Row(
                        children: [
                          FButton(
                            variant: FButtonVariant.outline,
                            onPress: homeLayoutService.reset,
                            child: const Text('Reset'),
                          ),
                          const Spacer(),
                          FButton(
                            onPress: () => Navigator.pop(context),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        label,
        style: context.theme.typography.sm.copyWith(
          color: context.theme.colors.mutedForeground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        text,
        style: context.theme.typography.xs.copyWith(
          color: context.theme.colors.mutedForeground,
        ),
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final bool muted;

  const _SectionRow({
    required this.title,
    required this.actions,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.sidebarSelected,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: context.theme.typography.sm.copyWith(
                color: muted ? colors.mutedForeground : colors.foreground,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class _RowAction extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool destructive;

  const _RowAction({
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  @override
  State<_RowAction> createState() => _RowActionState();
}

class _RowActionState extends State<_RowAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final enabled = widget.onTap != null;
    final color = !enabled
        ? colors.mutedForeground.withValues(alpha: 0.3)
        : widget.destructive && _hovered
        ? colors.destructive
        : _hovered
        ? colors.foreground
        : colors.mutedForeground;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: enabled && _hovered ? colors.muted : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(widget.icon, size: 16, color: color),
        ),
      ),
    );
  }
}
