import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class NoContentView extends StatelessWidget {
  final String contentType;

  const NoContentView({super.key, this.contentType = "content"});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'No $contentType found',
            style: context.theme.typography.xl.copyWith(
              fontWeight: FontWeight.bold,
              color: context.theme.colors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Try adding some $contentType to your library.',
            style: context.theme.typography.md.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
