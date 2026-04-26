// ignore_for_file: use_build_context_synchronously, deprecated_member_use
import 'package:cosmodrome/components/forms/add_server_form.dart';
import 'package:cosmodrome/components/forms/add_user_form.dart';
import 'package:cosmodrome/providers/subsonic_account.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:cosmodrome/utils/scanning/scan_notifier.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class ProfileSheet extends StatefulWidget {
  const ProfileSheet({super.key});

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  bool _profilesExpanded = true;
  bool _serversExpanded = true;
  bool _isScanning = false;
  bool _wasScanning = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubsonicProvider>();

    final colors = context.theme.colors;

    // group
    final Map<String, List<SubsonicAccount>> accountsByServer = {};
    for (final account in provider.accounts) {
      accountsByServer.putIfAbsent(account.baseUrl, () => []).add(account);
    }

    final activeAccount = provider.activeAccount;

    return Material(
      color: AppColors.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Consumer<SubsonicProvider>(
          builder: (context, value, child) => Column(
            children: [
              // only show on mobile
              if (isMobile(context))
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )
              else
                const SizedBox(height: 16),

              // header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
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
              // profile card
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: activeAccount != null
                    ? _buildActiveProfileCard(context, activeAccount, colors)
                    : _buildNoAccountPill(context, colors),
              ),
              // content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    Container(height: 1, color: context.theme.colors.border),
                    _buildSectionHeader(
                      context,
                      'Profiles',
                      _profilesExpanded,
                      () => setState(
                        () => _profilesExpanded = !_profilesExpanded,
                      ),
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
                                _buildAddButton(context, 'Add Account', () {
                                  context.push('/adduser');
                                }),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 8),
                    Container(height: 1, color: context.theme.colors.border),
                    _buildSectionHeader(
                      context,
                      'Servers',
                      _serversExpanded,
                      () =>
                          setState(() => _serversExpanded = !_serversExpanded),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: _serversExpanded
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ...provider.knownServers.map(
                                  (server) => _buildServerRow(context, server),
                                ),
                                _buildAddButton(context, 'Add Server', () {
                                  context.push('/addserver');
                                }),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    // clear cache button
                    if (activeAccount != null) ...[
                      const SizedBox(height: 12),
                      _buildNormalButton(context, 'Clear Cache', () async {
                        await provider.deleteCacheForActiveAccount();

                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          const SnackBar(
                            content: Text('Cache cleared'),
                            duration: Duration(seconds: 3),
                          ),
                        );

                        // change active account to trigger a refresh of all data and UI
                        final currentId = provider.activeAccount?.id;
                        provider.switchAccount("none");
                        // switch back after a short delay to ensure all listeners have reacted to the change
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (currentId != null) {
                            provider.switchAccount(currentId);
                          }
                        });
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
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
                : Image.asset("assets/logo.png").image,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.username,
                  style: context.theme.typography.sm.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  server.name,
                  style: context.theme.typography.xs.copyWith(
                    color: colors.mutedForeground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _isScanning
                ? null
                : () => startLibraryScan(provider.subsonic),
            child: _isScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    FIcons.refreshCw,
                    size: 18,
                    color: colors.mutedForeground,
                  ),
          ),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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

  Widget _buildNormalButton(
    BuildContext context,
    String label,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: FButton(
        variant: FButtonVariant.outline,
        onPress: onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [Text(label)]),
      ),
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
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

          return Dismissible(
            key: ValueKey(account.id),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => provider.removeAccount(account.id),
            background: const SizedBox.shrink(),
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              color: Colors.red,
              child: const Icon(FIcons.trash2, color: Colors.white, size: 20),
            ),
            child: GestureDetector(
              onTap: () {
                provider.switchAccount(account.id);
                Navigator.pop(context);
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            _openEditAccountSheet(context, account);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              FIcons.pencil,
                              size: 16,
                              color: colors.mutedForeground,
                            ),
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Icon(FIcons.check, size: 16, color: colors.primary),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  void _openEditAccountSheet(BuildContext context, SubsonicAccount account) {
    showFSheet(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: 0.75,
      builder: (sheetCtx) => Material(
        color: const Color(0xFF101012),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Edit Account',
                  style: sheetCtx.theme.typography.xl.copyWith(
                    fontWeight: FontWeight.bold,
                    color: sheetCtx.theme.colors.foreground,
                  ),
                ),
                const SizedBox(height: 20),
                AddUserForm(
                  initialAccount: account,
                  onSuccess: () => Navigator.pop(sheetCtx),
                  onCancel: () => Navigator.pop(sheetCtx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServerRow(BuildContext context, SubsonicServer server) {
    final colors = context.theme.colors;
    final connected = server.canConnect;

    return Dismissible(
      key: ValueKey(server.baseUrl),
      direction: DismissDirection.endToStart,
      onDismissed: (_) =>
          context.read<SubsonicProvider>().removeKnownServer(server.baseUrl),
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red,
        child: const Icon(FIcons.trash2, color: Colors.white, size: 20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _statusText(connected),
                  style: context.theme.typography.xs.copyWith(
                    color: _statusColor(context, connected),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _openEditServerSheet(context, server);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Icon(
                    FIcons.pencil,
                    size: 16,
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openEditServerSheet(BuildContext context, SubsonicServer server) {
    showFSheet(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: 0.75,
      builder: (sheetCtx) => Material(
        color: const Color(0xFF101012),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Edit Server',
                  style: sheetCtx.theme.typography.xl.copyWith(
                    fontWeight: FontWeight.bold,
                    color: sheetCtx.theme.colors.foreground,
                  ),
                ),
                const SizedBox(height: 20),
                AddServerForm(
                  initialServer: server,
                  onSuccess: (_) => Navigator.pop(sheetCtx),
                  onCancel: () => Navigator.pop(sheetCtx),
                ),
              ],
            ),
          ),
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
