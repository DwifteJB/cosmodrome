import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/services/local_storage_service.dart';
import 'package:cosmodrome/services/offline_cache_service.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

class CacheSettingsPage extends StatefulWidget {
  const CacheSettingsPage({super.key});

  @override
  State<CacheSettingsPage> createState() => _CacheSettingsPageState();
}

class _CacheSettingsPageState extends State<CacheSettingsPage> {
  Map<String, int> _bytesByAccount = {};
  bool _loading = true;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _loadSizes();
  }

  Future<void> _loadSizes() async {
    final provider = context.read<SubsonicProvider>();
    final result = <String, int>{};
    for (final account in provider.accounts) {
      result[account.id] = await LocalStorageService.accountStorageBytes(
        account.id,
      );
    }
    if (mounted) {
      setState(() {
        _bytesByAccount = result;
        _loading = false;
      });
    }
  }

  Future<void> _clearAccount(String accountId) async {
    setState(() => _clearing = true);
    await offlineCacheService.clearCacheForAccount(accountId);
    await _loadSizes();
    setState(() => _clearing = false);
  }

  Future<void> _clearAll() async {
    setState(() => _clearing = true);
    final provider = context.read<SubsonicProvider>();
    for (final account in provider.accounts) {
      await offlineCacheService.clearCacheForAccount(account.id);
    }
    await _loadSizes();
    setState(() => _clearing = false);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final provider = context.watch<SubsonicProvider>();
    final accounts = provider.accounts;
    final totalBytes = _bytesByAccount.values.fold(0, (a, b) => a + b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Cache',
            style: context.theme.typography.xl.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'API response cache and cover art stored locally.',
            style: context.theme.typography.sm.copyWith(
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 20),

          // total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.muted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(FIcons.database, size: 18, color: colors.mutedForeground),
                const SizedBox(width: 12),
                Text(
                  'Total cache',
                  style: context.theme.typography.sm.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                _loading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.mutedForeground,
                        ),
                      )
                    : Text(
                        _formatBytes(totalBytes),
                        style: context.theme.typography.sm.copyWith(
                          color: colors.mutedForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No accounts',
                style: context.theme.typography.sm.copyWith(
                  color: colors.mutedForeground,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            Text(
              'Per Account',
              style: context.theme.typography.sm.copyWith(
                color: colors.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...accounts.map((account) {
              final bytes = _bytesByAccount[account.id] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  decoration: BoxDecoration(
                    color: AppColors.sidebarSelected,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage:
                            account.avatar.isNotEmpty
                                ? MemoryImage(account.avatar)
                                : Image.asset('assets/logo.png').image,
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
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
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
                      const SizedBox(width: 12),
                      _loading
                          ? SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.mutedForeground,
                              ),
                            )
                          : Text(
                              _formatBytes(bytes),
                              style: context.theme.typography.xs.copyWith(
                                color: colors.mutedForeground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      const SizedBox(width: 10),
                      FButton(
                        variant: FButtonVariant.outline,
                        onPress: _clearing ? null : () => _clearAccount(account.id),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            FButton(
              variant: FButtonVariant.destructive,
              onPress: _clearing || _loading ? null : _clearAll,
              child: _clearing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Clear All Cache'),
            ),
          ],
        ],
      ),
    );
  }
}
