import 'dart:async';

import 'package:cosmodrome/components/home/customize_home_dialog.dart';
import 'package:cosmodrome/components/home/home_sections.dart';
import 'package:cosmodrome/components/shared_views/no_account_view.dart';
import 'package:cosmodrome/components/shared_views/offline_banner.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/providers/subsonic_provider.dart';
import 'package:cosmodrome/services/home_layout_service.dart';
import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:cosmodrome/utils/notifiers/sidebar_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

final homeItems = [
  _HomeCard(
    icon: FIcons.history,
    title: 'Recently Added',
    onTap: (context) => context.push('/library/recent'),
  ),
  _HomeCard(
    icon: FIcons.shuffle,
    title: 'Random',
    onTap: (context) {
      // send snackbar message saying "grabbing random album..." that disappears when the album is loaded or fails to load
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Grabbing random album...')));
      context.read<SubsonicProvider>().subsonic.getRandomAlbum().then((album) {
        if (album != null) {
          // ignore: use_build_context_synchronously
          GoRouter.of(context).push('/library/album/${album.id}');
        }
      });
    },
  ),
  _HomeCard(
    icon: FIcons.star,
    title: 'Starred',
    onTap: (context) => context.push('/library/starred'),
  ),
  _HomeCard(
    icon: FIcons.clockArrowDown,
    title: 'Frequently played',
    onTap: null,
  ),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final void Function(BuildContext)? onTap;

  const _HomeCard({required this.icon, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return GestureDetector(
      onTap: onTap != null ? () => onTap!(context) : null,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: colors.muted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colors.mutedForeground),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: context.theme.typography.xs.copyWith(
                  color: colors.mutedForeground,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _homeRefreshInterval = Duration(minutes: 1);

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _sectionKeys = <String, GlobalKey>{};
  Timer? _refreshTimer;
  String? _accountId;
  bool _staleLayout = false;
  bool _staleReload = false;

  bool get _visible => ModalRoute.of(context)?.isCurrent ?? true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_visible) return;
    if (_staleLayout) {
      _staleLayout = false;
      setState(() {});
    }
    if (_staleReload) {
      _staleReload = false;
      _scheduleReload(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubsonicProvider>();
    final account = provider.activeAccount;

    if (account == null) {
      _accountId = null;
      return NoAccountView();
    }

    if (_accountId != account.id) {
      final switched = _accountId != null;
      _accountId = account.id;
      if (switched) _scheduleReload(force: true);
    }

    final byId = {for (final s in homeSections) s.id: s};
    final ordered = homeLayoutService.resolve([
      for (final s in homeSections) s.id,
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 50,
          child: isMobileView(context)
              ? null
              : Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _CustomizeButton(
                      onTap: () => showCustomizeHomeDialog(context),
                    ),
                  ),
                ),
        ),
        if (provider.isOffline)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: OfflineBanner(),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              _cardRow(homeItems[0], homeItems[1]),
              const SizedBox(height: 8),
              _cardRow(homeItems[2], homeItems[3]),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final section in ordered.map((id) => byId[id]!))
          section.buildView(
            key: _sectionKeys.putIfAbsent(
              '${account.id}:${section.id}',
              GlobalKey.new,
            ),
            subsonic: provider.subsonic,
            accountId: account.id,
            isOffline: provider.isOffline,
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleReload(force: true);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    homeLayoutService.removeListener(_onLayoutChanged);
    starredCountChanged.removeListener(_onStarOrPlaylistChanged);
    playlistsCountChanged.removeListener(_onStarOrPlaylistChanged);
    homeRefreshNotifier.removeListener(_onHomeRefreshRequested);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    homeLayoutService.addListener(_onLayoutChanged);
    unawaited(homeLayoutService.ensureLoaded());
    starredCountChanged.addListener(_onStarOrPlaylistChanged);
    playlistsCountChanged.addListener(_onStarOrPlaylistChanged);
    homeRefreshNotifier.addListener(_onHomeRefreshRequested);
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(
      _homeRefreshInterval,
      (_) => _scheduleReload(force: true),
    );
  }

  Widget _cardRow(Widget left, Widget right) => Row(
    children: [
      Expanded(child: left),
      const SizedBox(width: 8),
      Expanded(child: right),
    ],
  );

  Future<void> _reloadSections({bool force = false}) {
    final accountId = context.read<SubsonicProvider>().activeAccount?.id;
    if (accountId == null) return Future.value();
    return Future.wait([
      for (final section in homeSections)
        if (_sectionKeys['$accountId:${section.id}']?.currentState
            case final ReloadableHomeSection view)
          view.reload(force: force),
    ]);
  }

  void _onLayoutChanged() {
    if (!mounted) return;
    if (!_visible) {
      _staleLayout = true;
      return;
    }
    setState(() {});
  }

  void _onHomeRefreshRequested() {
    final completer = homeRefreshNotifier.value;
    if (completer == null || completer.isCompleted) return;
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      try {
        await _reloadSections(force: true);
      } finally {
        if (!completer.isCompleted) completer.complete();
      }
    });
  }

  void _onStarOrPlaylistChanged() => _scheduleReload();

  void _scheduleReload({bool force = false}) {
    if (mounted && !_visible) {
      _staleReload = true;
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_reloadSections(force: force));
    });
  }
}

class _CustomizeButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CustomizeButton({required this.onTap});

  @override
  State<_CustomizeButton> createState() => _CustomizeButtonState();
}

class _CustomizeButtonState extends State<_CustomizeButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final fg = _hovered ? colors.foreground : colors.mutedForeground;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered
                ? colors.muted
                : colors.muted.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FIcons.slidersHorizontal, size: 14, color: fg),
              const SizedBox(width: 8),
              Text(
                'Customize',
                style: context.theme.typography.xs.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
