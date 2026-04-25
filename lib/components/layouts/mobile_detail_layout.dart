// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui';

import 'package:cosmodrome/components/music_player/mini_player.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/utils/accent_notifier.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/layout_notifier.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Full-screen layout for detail pages (album, playlist) on mobile.
/// Lives on the root navigator so swipe-back slides it away cleanly,
/// revealing the shell (home/library) underneath.
class MobileDetailLayout extends StatefulWidget {
  final Widget child;
  final bool isScrollable;

  const MobileDetailLayout({
    super.key,
    required this.child,
    this.isScrollable = true,
  });

  @override
  State<MobileDetailLayout> createState() => _MobileDetailLayoutState();
}

class _MobileDetailLayoutState extends State<MobileDetailLayout>
    with TickerProviderStateMixin {
  final _scrollController = ScrollController();
  LayoutConfig _layoutConfig = LayoutConfig.empty;
  Color? _accentColor;
  bool _accentVisible = false;
  Timer? _accentHideTimer;
  late AnimationController _aniu;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    const navHeight = 80.0;

    final expandedMiniPlayer = Consumer<PlayerProvider>(
      builder: (_, player, _) {
        if (!player.hasCurrentSong) return const SizedBox.shrink();
        final collapsed = _aniu.value > 0.3;
        return AnimatedOpacity(
          opacity: collapsed ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(ignoring: collapsed, child: const MiniPlayer()),
        );
      },
    );

    final floatingNav = Consumer<PlayerProvider>(
      builder: (_, player, _) {
        final collapsed = _aniu.value > 0.3;
        return Row(
          children: [
            _buildNavPill(context),
            Expanded(
              child: player.hasCurrentSong && collapsed
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: MiniPlayer(),
                    )
                  : const SizedBox.shrink(),
            ),
            _buildSearchPill(context),
          ],
        );
      },
    );

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Accent gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPadding + MediaQuery.of(context).size.height * 0.38,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _accentVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeIn,
                child: _accentColor == null
                    ? const SizedBox.expand()
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _accentColor!.withValues(alpha: 0.55),
                              _accentColor!.withValues(alpha: 0.30),
                              colors.background.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.15, 1.0],
                          ),
                        ),
                      ),
              ),
            ),
          ),
          // Content
          if (widget.isScrollable)
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    SizedBox(height: topPadding + 20),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            MediaQuery.of(context).size.height -
                            (topPadding + 20) -
                            (navHeight + bottomPadding),
                      ),
                      child: widget.child,
                    ),
                    SizedBox(height: navHeight + bottomPadding + 60),
                  ],
                ),
              ),
            )
          else
            Positioned.fill(child: widget.child),
          // Bottom fade
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: navHeight + bottomPadding + 24,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.background.withValues(alpha: 0.0),
                      colors.background.withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Top fade (appears on scroll)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPadding + 72,
            child: IgnorePointer(
              child: FadeTransition(
                opacity: _aniu.drive(CurveTween(curve: Curves.easeOut)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        colors.background.withValues(alpha: 0.0),
                        colors.background.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 56 + topPadding,
            child: _buildTopBar(context),
          ),
          // Mini player
          Positioned(
            bottom: bottomPadding + 18 + 48 + 20,
            left: 16,
            right: 16,
            child: expandedMiniPlayer,
          ),
          // Nav
          Positioned(
            bottom: bottomPadding + 18,
            left: 16,
            right: 16,
            child: floatingNav,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _accentHideTimer?.cancel();
    _scrollController.dispose();
    layoutConfig.removeListener(_onLayoutConfigChanged);
    accentColorNotifier.removeListener(_onAccentChanged);
    _aniu.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _aniu = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scrollController.addListener(_onScroll);
    layoutConfig.addListener(_onLayoutConfigChanged);
    accentColorNotifier.addListener(_onAccentChanged);
    _layoutConfig = layoutConfig.value;
    // Sync initial accent if already set (e.g. navigating back to same page)
    final initialColor = accentColorNotifier.value;
    if (initialColor != null) {
      _accentColor = initialColor;
      _accentVisible = true;
    }
  }

  Widget _buildNavPill(BuildContext context) {
    final colors = context.theme.colors;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.border, width: 1),
        borderRadius: BorderRadius.circular(28),
        color: colors.background.withOpacity(0.55),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: GestureDetector(
              onTap: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(FIcons.house, size: 24, color: colors.mutedForeground),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPill(BuildContext context) {
    final colors = context.theme.colors;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.border, width: 1),
        borderRadius: BorderRadius.circular(28),
        color: colors.background.withOpacity(0.55),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: GestureDetector(
              onTap: () => context.go('/search'),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child:
                    Icon(FIcons.search, size: 24, color: colors.mutedForeground),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final colors = context.theme.colors;
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      height: 56 + topPadding,
      padding: EdgeInsets.only(top: topPadding, left: 20, right: 16),
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _aniu.drive(
          Tween(begin: 1.0, end: 0.0).chain(
            CurveTween(curve: const Interval(0.0, 0.3, curve: Curves.easeOut)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      color: colors.background.withOpacity(0.8),
                      child: Icon(
                        FIcons.chevronLeft,
                        size: 20,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            ..._layoutConfig.buttons.map(
              (button) => FButton(
                onPress: button.onPressed,
                style: .delta(
                  decoration: .delta([
                    FVariantOperation.all(
                      .boxDelta(
                        color: AppColors.mutedButtonColor,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: colors.border, width: 1),
                      ),
                    ),
                  ]),
                  contentStyle: .delta(
                    padding: EdgeInsetsGeometryDelta.value(
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    ),
                  ),
                ),
                child: Icon(
                  button.icon,
                  size: 24,
                  color: button.color ?? Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onAccentChanged() {
    _accentHideTimer?.cancel();
    final color = accentColorNotifier.value;
    if (color != null) {
      setState(() {
        _accentColor = color;
        _accentVisible = true;
      });
    } else {
      setState(() => _accentVisible = false);
      _accentHideTimer = Timer(const Duration(milliseconds: 750), () {
        if (mounted && accentColorNotifier.value == null) {
          setState(() => _accentColor = null);
        }
      });
    }
  }

  void _onLayoutConfigChanged() {
    setState(() => _layoutConfig = layoutConfig.value);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    const maxScroll = 250.0;
    final scrollOffset = _scrollController.offset.clamp(0.0, maxScroll);
    final opacity = scrollOffset / maxScroll;
    if (opacity != _aniu.value) {
      setState(() => _aniu.value = opacity);
    }
  }
}
