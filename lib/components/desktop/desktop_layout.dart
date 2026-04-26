import 'dart:ui';

import 'package:cosmodrome/utils/cover_art/cover_art_provider.dart';
import 'package:flutter/material.dart';

class DesktopLayout extends StatelessWidget {
  final Color backgroundColor;
  final Widget sidebar;
  final bool queueOpen;
  final VoidCallback onCloseQueue;
  final String? coverUrl;
  final bool coverVisible;
  final ScrollController scrollController;
  final Widget topBar;
  final Widget child;
  final Widget queuePanel;
  final Widget playerBar;

  const DesktopLayout({
    super.key,
    required this.backgroundColor,
    required this.sidebar,
    required this.queueOpen,
    required this.onCloseQueue,
    required this.coverUrl,
    required this.coverVisible,
    required this.scrollController,
    required this.topBar,
    required this.child,
    required this.queuePanel,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            Positioned(
                              top: -32,
                              left: 0,
                              right: 0,
                              height:
                                  MediaQuery.of(context).size.height * 1 + 32,
                              child: IgnorePointer(
                                child: AnimatedOpacity(
                                  opacity: coverVisible ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeIn,
                                  child: coverUrl == null
                                      ? const SizedBox.expand()
                                      : Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ImageFiltered(
                                              imageFilter: ImageFilter.blur(
                                                sigmaX: 100,
                                                sigmaY: 100,
                                                tileMode: TileMode.clamp,
                                              ),
                                              child: Image(
                                                image: coverArtProvider(
                                                  coverUrl!,
                                                ),
                                                fit: BoxFit.cover,
                                                colorBlendMode:
                                                    BlendMode.overlay,
                                              ),
                                            ),
                                            const DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: Color(0x99000000),
                                              ),
                                            ),
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.center,
                                                  colors: [
                                                    backgroundColor.withValues(
                                                      alpha: 0.42,
                                                    ),
                                                    backgroundColor.withValues(
                                                      alpha: 0.16,
                                                    ),
                                                  ],
                                                  stops: const [0.0, 0.62],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  topBar,
                                  Expanded(
                                    child: SingleChildScrollView(
                                      controller: scrollController,
                                      child: KeyedSubtree(
                                        key: const ValueKey('desktop-child'),
                                        child: child,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IgnorePointer(
                              ignoring: !queueOpen,
                              child: AnimatedOpacity(
                                opacity: queueOpen ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 220),
                                child: GestureDetector(
                                  onTap: onCloseQueue,
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
                              right: queueOpen ? 0 : -280,
                              bottom: 0,
                              width: 280,
                              child: queuePanel,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                playerBar,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
