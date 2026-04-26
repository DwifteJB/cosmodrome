import 'package:cosmodrome/utils/isMobileView.dart';
import 'package:cosmodrome/utils/layout_page_mixin.dart';
import 'package:cosmodrome/utils/notifiers/layout_notifier.dart';
import 'package:flutter/material.dart';

/// template for pages that need distinct desktop and mobile layouts.
///
/// Key rules:
///   - Use [LayoutPageMixin] — it registers the page with the parent layout on
///     init and cleans up on dispose (title, buttons, pill overrides, etc.).
///   - Return plain widget content from build() — never wrap in a Scaffold.
///     The parent [MobileLayout] / desktop layout already owns the Scaffold and
///     provides controls (mini-player, nav pill, back button).
///   - [_mobileLayout] returns a Column; the parent scrolls it.
///   - [_desktopLayout] returns a Column with desktop-appropriate padding.
class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> with LayoutPageMixin {
  // Override to set the page title shown in the mobile top bar.
  @override
  String? get pageTitle => 'Example';

  // Override to add action buttons to the mobile top bar.
  @override
  List<TopbarButton> get pageButtons => [
    TopbarButton(
      icon: Icons.refresh,
      onPressed: _onRefresh,
    ),
  ];

  void _onRefresh() {
    // handle refresh
  }

  @override
  Widget build(BuildContext context) {
    return isMobileView(context) ? _mobileLayout() : _desktopLayout();
  }

  Widget _mobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top spacing accounts for the overlaid mobile top bar.
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mobile content',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This column is scrolled by the parent MobileLayout.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _desktopLayout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Desktop content',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Desktop layout can use LayoutBuilder for compact vs wide variants.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}
