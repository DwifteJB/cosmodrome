// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui';

import 'package:cosmodrome/components/music_player/mini_player.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/utils/notifiers/accent_notifier.dart';
import 'package:cosmodrome/utils/colors.dart';
import 'package:cosmodrome/utils/notifiers/layout_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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

class _AccentGradientLayer extends StatefulWidget {
  final Color backgroundColor;

  const _AccentGradientLayer({required this.backgroundColor});

  @override
  State<_AccentGradientLayer> createState() => _AccentGradientLayerState();
}

class _AccentGradientLayerState extends State<_AccentGradientLayer> {
  Color? _accentColor;
  bool _accentVisible = false;
  Timer? _accentHideTimer;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
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
                      widget.backgroundColor.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.15, 1.0],
                  ),
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _accentHideTimer?.cancel();
    accentColorNotifier.removeListener(_onAccentChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    accentColorNotifier.addListener(_onAccentChanged);
    final initialColor = accentColorNotifier.value;
    if (initialColor != null) {
      _accentColor = initialColor;
      _accentVisible = true;
    }
  }

  void _onAccentChanged() {
    _accentHideTimer?.cancel();
    final color = accentColorNotifier.value;
    if (color != null) {
      _safeSetState(() {
        _accentColor = color;
        _accentVisible = true;
      });
    } else {
      _safeSetState(() => _accentVisible = false);
      _accentHideTimer = Timer(const Duration(milliseconds: 750), () {
        if (mounted && accentColorNotifier.value == null) {
          setState(() => _accentColor = null);
        }
      });
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }
}

class _MobileDetailLayoutState extends State<MobileDetailLayout>
    with TickerProviderStateMixin {
  final _scrollController = ScrollController();
  Timer? _blurEnableTimer;
  bool _enableBlur = false;
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
        return AnimatedBuilder(
          animation: _aniu,
          builder: (_, _) {
            final collapsed = _aniu.value > 0.3;
            return AnimatedOpacity(
              opacity: collapsed ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: collapsed,
                child: const MiniPlayer(),
              ),
            );
          },
        );
      },
    );

    final floatingNav = Consumer<PlayerProvider>(
      builder: (_, player, _) {
        return AnimatedBuilder(
          animation: _aniu,
          builder: (_, _) {
            final collapsed = _aniu.value > 0.3;
            return Row(
              children: [
                _buildNavPill(context, collapsed: collapsed),
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
      },
    );

    return ColoredBox(
      color: colors.background,
      child: Stack(
        children: [
          // accent gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPadding + MediaQuery.of(context).size.height * 0.38,
            child: _AccentGradientLayer(backgroundColor: colors.background),
          ),
          // content
          if (widget.isScrollable)
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    ValueListenableBuilder<LayoutConfig>(
                      valueListenable: layoutConfig,
                      builder: (_, config, _) => config.ignoreTopSpacing
                          ? const SizedBox.shrink()
                          : SizedBox(height: topPadding + 20),
                    ),
                    ValueListenableBuilder<LayoutConfig>(
                      valueListenable: layoutConfig,
                      builder: (_, config, child) => ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              MediaQuery.of(context).size.height -
                              (config.ignoreTopSpacing ? 0 : topPadding + 20) -
                              (navHeight + bottomPadding),
                        ),
                        child: child,
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
          // bottom fade
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
          // top fade (appears on scroll)
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
          // top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 56 + topPadding,
            child: _buildTopBar(context),
          ),
          // mini player
          Positioned(
            bottom: bottomPadding + 18 + 48 + 20,
            left: 16,
            right: 16,
            child: expandedMiniPlayer,
          ),
          // nav/search pills
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
    if (detailPageActive.value) detailPageActive.value = false;
    _blurEnableTimer?.cancel();
    _scrollController.dispose();
    _aniu.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (!detailPageActive.value) detailPageActive.value = true;
    _aniu = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scrollController.addListener(_onScroll);
    _blurEnableTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() => _enableBlur = true);
    });
  }

  Widget _buildBlurContainer({
    required Widget child,
    required double sigmaX,
    required double sigmaY,
  }) {
    if (!_enableBlur) return child;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
      child: child,
    );
  }

  Widget _buildNavPill(BuildContext context, {required bool collapsed}) {
    final colors = context.theme.colors;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.border, width: 1),
        borderRadius: BorderRadius.circular(28),
        color: colors.background.withValues(alpha: 0.55),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: _buildBlurContainer(
          sigmaX: 12,
          sigmaY: 12,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () =>
                      context.canPop() ? context.pop() : context.go('/home'),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      FIcons.house,
                      size: 24,
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: collapsed ? 0.0 : 1.0,
                    child: collapsed
                        ? const SizedBox.shrink()
                        : GestureDetector(
                            onTap: () => context.go('/library'),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                FIcons.library,
                                size: 24,
                                color: colors.mutedForeground,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
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
        color: colors.background.withValues(alpha: 0.55),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: _buildBlurContainer(
          sigmaX: 12,
          sigmaY: 12,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: GestureDetector(
              onTap: () => context.go('/search'),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  FIcons.search,
                  size: 24,
                  color: colors.mutedForeground,
                ),
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
                  child: _buildBlurContainer(
                    sigmaX: 10,
                    sigmaY: 10,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      color: colors.background.withValues(alpha: 0.8),
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
            Expanded(
              child: ValueListenableBuilder<LayoutConfig>(
                valueListenable: layoutConfig,
                builder: (_, config, _) {
                  if (config.title == null) return const SizedBox.shrink();
                  return Text(
                    config.title!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  );
                },
              ),
            ),
            ValueListenableBuilder<LayoutConfig>(
              valueListenable: layoutConfig,
              builder: (_, config, _) {
                if (config.buttons.isEmpty) return const SizedBox.shrink();

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: config.buttons
                      .map(
                        (button) =>
                            _buildTopBarActionButton(context, button: button),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBarActionButton(
    BuildContext context, {
    required TopbarButton button,
  }) {
    final colors = context.theme.colors;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: button.onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.mutedButtonColor,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: colors.border, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Icon(
            button.icon,
            size: 24,
            color: button.color ?? Colors.white,
          ),
        ),
      ),
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    const maxScroll = 250.0;
    final scrollOffset = _scrollController.offset.clamp(0.0, maxScroll);
    final opacity = scrollOffset / maxScroll;
    if (opacity != _aniu.value) {
      _aniu.value = opacity;
    }
  }
}
