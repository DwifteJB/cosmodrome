import 'dart:math' as math;
import 'dart:ui';

import 'package:cosmodrome/components/music_player/desktop_side_panel.dart';
import 'package:cosmodrome/utils/cover_art/cover_art_provider.dart';
import 'package:flutter/material.dart';

class DesktopLayout extends StatelessWidget {
  static const double playerBarHeight = 64;
  static const double playerBarBottomMargin = 12;
  static const double playerBarReserved = playerBarHeight + 24;
  static const double topBarHeight = 32;

  final Color backgroundColor;
  final Widget sidebar;
  final bool panelOpen;
  final VoidCallback onClosePanel;
  final String? coverUrl;
  final bool coverVisible;
  final Widget topBar;
  final double topBarInset;
  final Widget child;
  final Widget Function(double bottomInset) sidePanelBuilder;
  final Widget playerBar;

  const DesktopLayout({
    super.key,
    required this.backgroundColor,
    required this.sidebar,
    required this.panelOpen,
    required this.onClosePanel,
    required this.coverUrl,
    required this.coverVisible,
    required this.topBar,
    this.topBarInset = topBarHeight,
    required this.child,
    required this.sidePanelBuilder,
    required this.playerBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sidebar,
          Expanded(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  top: -32,
                  left: 0,
                  right: 0,
                  height: MediaQuery.sizeOf(context).height + 32,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: coverVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeIn,
                      child: coverUrl == null
                          ? const SizedBox.expand()
                          : _CoverBackdrop(
                              coverUrl: coverUrl!,
                              backgroundColor: backgroundColor,
                            ),
                    ),
                  ),
                ),
                Positioned.fill(
                  top: topBarInset,
                  child: KeyedSubtree(
                    key: const ValueKey('desktop-child'),
                    child: child,
                  ),
                ),
                Positioned(top: 0, left: 0, right: 0, child: topBar),
                // overlays only, so the page itself is never rebuilt inside
                // a layout callback
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final contentWidth = constraints.maxWidth;
                      final panelWidth = panelOpen
                          ? DesktopSidePanel.width
                          : 0.0;
                      final barWidth = math.min(800.0, contentWidth - 32);
                      final barLeft = math.max(
                        16.0,
                        (contentWidth - panelWidth - barWidth) / 2,
                      );
                      // the bar floats over the panel on narrow windows
                      final barOverlapsPanel =
                          panelOpen &&
                          barLeft + barWidth >
                              contentWidth - DesktopSidePanel.width;
                      final panelInset = barOverlapsPanel
                          ? playerBarReserved
                          : 0.0;
                      return Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          IgnorePointer(
                            ignoring: !panelOpen,
                            child: AnimatedOpacity(
                              opacity: panelOpen ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 220),
                              child: GestureDetector(
                                onTap: onClosePanel,
                                behavior: HitTestBehavior.opaque,
                                child: const ColoredBox(
                                  color: Color(0x66000000),
                                ),
                              ),
                            ),
                          ),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            top: 0,
                            right: panelOpen ? 0 : -DesktopSidePanel.width,
                            bottom: 0,
                            width: DesktopSidePanel.width,
                            child: sidePanelBuilder(panelInset),
                          ),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            left: barLeft,
                            width: barWidth,
                            bottom: playerBarBottomMargin,
                            child: playerBar,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Blurred, darkened album art shown behind the page content.
class _CoverBackdrop extends StatelessWidget {
  final String coverUrl;
  final Color backgroundColor;

  const _CoverBackdrop({required this.coverUrl, required this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: 100,
            sigmaY: 100,
            tileMode: TileMode.clamp,
          ),
          child: Image(
            image: coverArtProvider(coverUrl),
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            colorBlendMode: BlendMode.overlay,
          ),
        ),
        const DecoratedBox(decoration: BoxDecoration(color: Color(0x99000000))),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                backgroundColor.withValues(alpha: 0.42),
                backgroundColor.withValues(alpha: 0.16),
              ],
              stops: const [0.0, 0.62],
            ),
          ),
        ),
      ],
    );
  }
}
