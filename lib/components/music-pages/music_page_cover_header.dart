import 'package:cosmodrome/utils/cover_art_provider.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

String formatPageDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

class MusicPageCoverHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String metaText;
  final IconData placeholderIcon;
  final String? coverUrl;

  const MusicPageCoverHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.metaText,
    required this.placeholderIcon,
    this.coverUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: coverUrl != null
              ? Image(
                  image: coverArtProvider(coverUrl!),
                  width: 280,
                  height: 280,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => _placeholder(context),
                )
              : _placeholder(context),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.theme.typography.xl2.copyWith(
                    fontWeight: FontWeight.w400,
                    color: context.theme.colors.foreground,
                    letterSpacing: 1,
                    height: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: context.theme.typography.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  metaText,
                  style: context.theme.typography.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        color: context.theme.colors.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        placeholderIcon,
        color: context.theme.colors.mutedForeground,
        size: 80,
      ),
    );
  }
}
