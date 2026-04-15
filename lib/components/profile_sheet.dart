// ignore_for_file: deprecated_member_use
import 'package:cosmodrome/providers/subsonic_account.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/utils/colors.dart';
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
  final Map<String, bool?> _connectivity = {};
  bool _profilesExpanded = true;
  bool _serversExpanded = true;

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
        child: Column(
          children: [
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
            ),
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
                            _buildAddButton(context, '+ Add Account', () {
                              Navigator.pop(context);
                              context.push('/adduser');
                            }),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),
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
                              (server) => _buildServerRow(context, server),
                            ),
                            _buildAddButton(context, '+ Add Server', () {
                              Navigator.pop(context);
                              context.push('/addserver');
                            }),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Widget _buildActiveProfileCard(
    BuildContext context,
    SubsonicAccount account,
    dynamic colors,
  ) {
    String TestColor = account.username[0].toUpperCase();
    // hex it to a color
    final color = Color(
      (TestColor.codeUnitAt(0) * 0xFFFFFF ~/ 26) | 0xFF000000,
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
            backgroundColor: color,
            child: Text(
              account.username[0].toUpperCase(),
              style: context.theme.typography.sm.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                  account.baseUrl,
                  style: context.theme.typography.xs.copyWith(
                    color: colors.mutedForeground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Active',
                  style: context.theme.typography.xs.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
    final colors = context.theme.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Text(
          label,
          style: context.theme.typography.sm.copyWith(color: colors.primary),
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
    final connected = _connectivity[baseUrl];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            baseUrl,
            style: context.theme.typography.xs.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ),
        ...accounts.map((account) {
          final isActive = provider.activeAccount?.id == account.id;
          final accountConnected = isActive ? true : connected;
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
                    if (isActive)
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

  Widget _buildServerRow(BuildContext context, SubsonicServer server) {
    final colors = context.theme.colors;
    final connected = _connectivity[server.baseUrl];

    return Dismissible(
      key: ValueKey(server.baseUrl),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => context.read<SubsonicProvider>().removeKnownServer(server.baseUrl),
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

  Future<void> _checkConnectivity() async {
    final provider = context.read<SubsonicProvider>();
    final activeUrl = provider.activeAccount?.baseUrl;

    // mark it as connected right away (probably is)
    if (activeUrl != null) {
      setState(() => _connectivity[activeUrl] = true);
    }

    // get all urls from the server providers
    final urlsToCheck = <String>{};
    for (final account in provider.accounts) {
      if (account.baseUrl != activeUrl) urlsToCheck.add(account.baseUrl);
    }
    for (final server in provider.knownServers) {
      if (server.baseUrl != activeUrl) urlsToCheck.add(server.baseUrl);
    }

    for (final url in urlsToCheck) {
      SubsonicServer(baseUrl: url, name: url).tryConnect().then((connected) {
        if (mounted) setState(() => _connectivity[url] = connected);
      });
    }
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

  Color _statusColor(BuildContext context, bool? connected) {
    if (connected == null) return context.theme.colors.mutedForeground;
    return connected ? Colors.green : Colors.red;
  }

  String _statusText(bool? connected) {
    if (connected == null) return 'Checking…';
    return connected ? 'Connected' : 'Could not connect';
  }
}
