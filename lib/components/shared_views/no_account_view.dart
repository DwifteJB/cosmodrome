import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class NoAccountView extends StatelessWidget {
  const NoAccountView({super.key});
  @override
  Widget build(BuildContext context) {
    // background of a bunch of shimmering album cards in a row
    // so grid based layout that it looks like a music library, but the cards are just gray boxes with a shimmer effect
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'No account connected',
            style: context.theme.typography.xl.copyWith(
              fontWeight: FontWeight.bold,
              color: context.theme.colors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Please add an account to view your music library.',
            style: context.theme.typography.md.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
