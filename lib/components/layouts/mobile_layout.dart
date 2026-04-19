import 'package:flutter/material.dart';

class MobileLayout extends StatelessWidget {
  final Color backgroundColor;
  final Color? accentColor;
  final bool accentVisible;
  final bool isScrollable;
  final ScrollController scrollController;
  final Widget child;
  final Animation<double> topGradientOpacity;
  final Widget topBar;
  final Widget expandedMiniPlayer;
  final Widget floatingNav;

  const MobileLayout({
    super.key,
    required this.backgroundColor,
    required this.accentColor,
    required this.accentVisible,
    required this.isScrollable,
    required this.scrollController,
    required this.child,
    required this.topGradientOpacity,
    required this.topBar,
    required this.expandedMiniPlayer,
    required this.floatingNav,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    const navHeight = 80.0;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPadding + MediaQuery.of(context).size.height * 0.38,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: accentVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeIn,
                child: accentColor == null
                    ? const SizedBox.expand()
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              accentColor!.withValues(alpha: 0.55),
                              accentColor!.withValues(alpha: 0.30),
                              backgroundColor.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.15, 1.0],
                          ),
                        ),
                      ),
              ),
            ),
          ),
          if (isScrollable)
            Positioned.fill(
              child: SingleChildScrollView(
                controller: scrollController,
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
                      child: KeyedSubtree(
                        key: const ValueKey('mobile-child'),
                        child: child,
                      ),
                    ),
                    SizedBox(height: navHeight + bottomPadding + 60),
                  ],
                ),
              ),
            )
          else
            Positioned.fill(
              child: KeyedSubtree(
                key: const ValueKey('mobile-child'),
                child: child,
              ),
            ),
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
                      backgroundColor.withValues(alpha: 0.0),
                      backgroundColor.withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPadding + 72,
            child: IgnorePointer(
              child: FadeTransition(
                opacity: topGradientOpacity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        backgroundColor.withValues(alpha: 0.0),
                        backgroundColor.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 56 + topPadding,
            child: topBar,
          ),
          Positioned(
            bottom: bottomPadding + 18 + 48 + 20,
            left: 16,
            right: 16,
            child: expandedMiniPlayer,
          ),
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
}
