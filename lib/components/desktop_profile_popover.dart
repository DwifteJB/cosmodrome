// ignore_for_file: deprecated_member_use
import 'package:cosmodrome/components/forms/add_server_form.dart';
import 'package:cosmodrome/components/forms/add_user_form.dart';
import 'package:cosmodrome/components/scrolling_text.dart';
import 'package:cosmodrome/pages/downloads_page.dart';
import 'package:cosmodrome/providers/download_provider.dart';
import 'package:cosmodrome/providers/subsonic_account.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/scan_notifier.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

class DesktopProfilePopover extends StatefulWidget {
  const DesktopProfilePopover({super.key});

  @override
  State<DesktopProfilePopover> createState() => _DesktopProfilePopoverState();
}

class _DesktopAccountPopoverContent extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onAddServer;
  final VoidCallback onAddAccount;

  const _DesktopAccountPopoverContent({
    required this.onClose,
    required this.onAddServer,
    required this.onAddAccount,
  });

  @override
  State<_DesktopAccountPopoverContent> createState() =>
      _DesktopAccountPopoverContentState();
}

class _DesktopAccountPopoverContentState
    extends State<_DesktopAccountPopoverContent> {
  bool _profilesExpanded = false;
  bool _serversExpanded = false;
  bool _isScanning = false;
  bool _wasScanning = false;
  final Set<String> _hoveredItems = {};

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubsonicProvider>();
    final colors = context.theme.colors;

    final Map<String, List<SubsonicAccount>> accountsByServer = {};
    for (final account in provider.accounts) {
      accountsByServer.putIfAbsent(account.baseUrl, () => []).add(account);
    }

    final activeAccount = provider.activeAccount;

    return Material(
      color: AppColors.sidebarSelected,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: AppLayout.sidebarWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Text(
                    'Accounts',
                    style: context.theme.typography.xl.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: widget.onClose,
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
            // active profile card (one we are on)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: activeAccount != null
                  ? _buildActiveProfileCard(context, activeAccount, colors)
                  : _buildNoAccountPill(context, colors),
            ),
            Container(height: 1, color: colors.border),
            _buildDownloadsShortcut(context),
            // all profiles
            Container(height: 1, color: colors.border),
            _buildSectionHeader(
              context,
              'Profiles',
              _profilesExpanded,
              () => setState(() => _profilesExpanded = !_profilesExpanded),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _profilesExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...accountsByServer.entries.map(
                          (entry) => _buildServerGroup(
                            context,
                            entry.key,
                            entry.value,
                            provider,
                          ),
                        ),
                        _buildAddButton(
                          context,
                          'Add Account',
                          widget.onAddAccount,
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            // Servers section
            Container(height: 1, color: colors.border),
            _buildSectionHeader(
              context,
              'Servers',
              _serversExpanded,
              () => setState(() => _serversExpanded = !_serversExpanded),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _serversExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...provider.knownServers.map(
                          (server) =>
                              _buildServerRow(context, server, provider),
                        ),
                        _buildAddButton(
                          context,
                          'Add Server',
                          widget.onAddServer,
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    isScanningNotifier.removeListener(_onScanChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _isScanning = isScanningNotifier.value;
    _wasScanning = _isScanning;
    isScanningNotifier.addListener(_onScanChanged);
  }

  Widget _buildActiveProfileCard(
    BuildContext context,
    SubsonicAccount account,
    dynamic colors,
  ) {
    // get server for account
    final provider = context.read<SubsonicProvider>();
    final server = provider.knownServers.firstWhere(
      (s) => s.baseUrl == account.baseUrl,
      orElse: () =>
          SubsonicServer(baseUrl: account.baseUrl, name: account.baseUrl),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: account.avatar.isNotEmpty
                ? MemoryImage(account.avatar)
                : Image.asset("/assets/images/logo.png").image,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScrollingText(
                  text: account.username,
                  style: context.theme.typography.sm.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.bold,
                  ),
                  duration: 3,
                  maxWidth: 200,
                ),
                ScrollingText(
                  text: server.name,
                  maxWidth: 200,
                  style: context.theme.typography.xs.copyWith(
                    color: colors.mutedForeground,
                  ),
                  duration: 3,
                ),
              ],
            ),
          ),
          _buildRefreshButton(context, account),
        ],
      ),
    );
  }

  Widget _buildAddButton(
    BuildContext context,
    String label,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: FButton(
        variant: FButtonVariant.outline,
        onPress: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(FIcons.plus, size: 14),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadsShortcut(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (ctx, dl, _) {
        final colors = context.theme.colors;
        final count = dl.completedDownloads.length;
        final active = dl.activeDownloads.length;

        return GestureDetector(
          onTap: () {
            widget.onClose();
            showDownloadsSheet(context);
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Icon(
                  Icons.download_rounded,
                  size: 18,
                  color: colors.foreground,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Downloads',
                    style: context.theme.typography.sm.copyWith(
                      color: colors.foreground,
                    ),
                  ),
                ),
                Text(
                  active > 0
                      ? '$count downloaded · $active active'
                      : '$count song${count == 1 ? '' : 's'}',
                  style: context.theme.typography.xs.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  FIcons.chevronRight,
                  size: 14,
                  color: colors.mutedForeground,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoAccountPill(BuildContext context, dynamic colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.border,
            ),
            child: Icon(
              FIcons.circleUser,
              size: 20,
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'No account selected',
            style: context.theme.typography.sm.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton(BuildContext context, SubsonicAccount account) {
    final provider = context.read<SubsonicProvider>();
    return GestureDetector(
      onTap: _isScanning ? null : () => startLibraryScan(provider.subsonic),
      child: _isScanning
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(FIcons.refreshCw, size: 16),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    bool expanded,
    VoidCallback onToggle,
  ) {
    final colors = context.theme.colors;
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Text(
              title,
              style: context.theme.typography.sm.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.foreground,
              ),
            ),
            const Spacer(),
            Icon(
              expanded ? FIcons.chevronUp : FIcons.chevronDown,
              size: 16,
              color: colors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerGroup(
    BuildContext context,
    String baseUrl,
    List<SubsonicAccount> accounts,
    SubsonicProvider provider,
  ) {
    final colors = context.theme.colors;

    final server = provider.knownServers.firstWhere(
      (s) => s.baseUrl == baseUrl,
      orElse: () => SubsonicServer(baseUrl: baseUrl, name: baseUrl),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            "${server.name} ($baseUrl)",
            style: context.theme.typography.xs.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ),
        ...accounts.map((account) {
          final isActive = provider.activeAccount?.id == account.id;
          final accountConnected = server.canConnect;
          final key = account.id;

          return MouseRegion(
            onEnter: (_) => setState(() => _hoveredItems.add(key)),
            onExit: (_) => setState(() => _hoveredItems.remove(key)),
            child: GestureDetector(
              onTap: () {
                provider.switchAccount(account.id);
                widget.onClose();
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    _dot(accountConnected),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.username,
                            style: context.theme.typography.sm.copyWith(
                              color: colors.foreground,
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          Text(
                            _statusText(accountConnected),
                            style: context.theme.typography.xs.copyWith(
                              color: _statusColor(context, accountConnected),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_hoveredItems.contains(key))
                      GestureDetector(
                        onTap: () => provider.removeAccount(account.id),
                        child: const Icon(
                          FIcons.trash2,
                          size: 16,
                          color: Colors.red,
                        ),
                      )
                    else if (isActive)
                      Icon(FIcons.check, size: 16, color: colors.primary),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildServerRow(
    BuildContext context,
    SubsonicServer server,
    SubsonicProvider provider,
  ) {
    final colors = context.theme.colors;
    final connected = server.canConnect;
    final key = server.baseUrl;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredItems.add(key)),
      onExit: (_) => setState(() => _hoveredItems.remove(key)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            _dot(connected),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    server.name,
                    style: context.theme.typography.sm.copyWith(
                      color: colors.foreground,
                    ),
                  ),
                  if (server.name != server.baseUrl)
                    Text(
                      server.baseUrl,
                      style: context.theme.typography.xs.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                ],
              ),
            ),
            if (_hoveredItems.contains(key))
              GestureDetector(
                onTap: () => provider.removeKnownServer(server.baseUrl),
                child: const Icon(FIcons.trash2, size: 16, color: Colors.red),
              )
            else
              Text(
                _statusText(connected),
                style: context.theme.typography.xs.copyWith(
                  color: _statusColor(context, connected),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dot(bool? connected) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: connected == null
          ? Colors.grey
          : connected
          ? Colors.green
          : Colors.red,
    ),
  );

  void _onScanChanged() {
    final scanning = isScanningNotifier.value;
    if (_wasScanning && !scanning && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Library scan complete'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    _wasScanning = scanning;
    if (mounted) setState(() => _isScanning = scanning);
  }

  Color _statusColor(BuildContext context, bool? connected) {
    if (connected == null) return context.theme.colors.mutedForeground;
    return connected ? Colors.green : Colors.red;
  }

  String _statusText(bool? connected) {
    if (connected == null) return 'Checking…';
    return connected ? 'Connected' : 'Cannot connect';
  }
}

class _DesktopProfilePopoverState extends State<DesktopProfilePopover>
    with SingleTickerProviderStateMixin {
  late final FPopoverController _ctrl;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubsonicProvider>();
    final colors = context.theme.colors;
    final activeAccount = provider.activeAccount;

    return FPopover(
      control: FPopoverControl.managed(controller: _ctrl),
      childAnchor: Alignment.topLeft,
      popoverAnchor: Alignment.bottomLeft,
      popoverBuilder: (_, _) => _DesktopAccountPopoverContent(
        onClose: _ctrl.hide,
        onAddServer: () {
          _ctrl.hide();
          _showAddServerDialog(context);
        },
        onAddAccount: () {
          _ctrl.hide();
          _showAddAccountDialog(context);
        },
      ),
      child: GestureDetector(
        onTap: () => _ctrl.toggle(),
        behavior: HitTestBehavior.opaque,
        child: _buildFooterTrigger(context, activeAccount, colors),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _ctrl = FPopoverController(vsync: this);
  }

  Widget _buildFooterTrigger(
    BuildContext context,
    SubsonicAccount? activeAccount,
    dynamic colors,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: activeAccount?.avatar.isNotEmpty == true
                  ? MemoryImage(activeAccount!.avatar)
                  : Image.asset("/assets/images/logo.png").image,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    activeAccount?.username ?? 'No account',
                    style: context.theme.typography.sm.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    activeAccount?.baseUrl ?? 'No account selected',
                    style: context.theme.typography.xs.copyWith(
                      color: colors.mutedForeground,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              FIcons.chevronsUpDown,
              size: 14,
              color: colors.mutedForeground,
            ),
          ],
        ],
      ),
    );
  }

  void _showAddAccountDialog(BuildContext ctx) {
    showFDialog(
      context: ctx,
      builder: (dialogCtx, _, animation) => FDialog.raw(
        animation: animation,
        builder: (innerCtx, style) => SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add Account',
                  style: innerCtx.theme.typography.xl.copyWith(
                    fontWeight: FontWeight.bold,
                    color: innerCtx.theme.colors.foreground,
                  ),
                ),
                const SizedBox(height: 20),
                AddUserForm(
                  onSuccess: () => Navigator.pop(dialogCtx),
                  onCancel: () => Navigator.pop(dialogCtx),
                  onAddServerPressed: () => _showAddServerDialog(ctx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<SubsonicServer?> _showAddServerDialog(BuildContext ctx) async {
    SubsonicServer? result;
    await showFDialog(
      context: ctx,
      builder: (dialogCtx, _, animation) => FDialog.raw(
        animation: animation,
        builder: (innerCtx, style) => SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add Server',
                  style: innerCtx.theme.typography.xl.copyWith(
                    fontWeight: FontWeight.bold,
                    color: innerCtx.theme.colors.foreground,
                  ),
                ),
                const SizedBox(height: 20),
                AddServerForm(
                  onSuccess: (server) {
                    result = server;
                    Navigator.pop(dialogCtx);
                  },
                  onCancel: () => Navigator.pop(dialogCtx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return result;
  }
}
