import 'package:cosmodrome/components/scrolling_text.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class LibraryGridItem extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String? subtitle;
  final IconData placeholderIcon;
  final VoidCallback? onTap;

  const LibraryGridItem({
    super.key, 
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.placeholderIcon = Icons.music_note,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) => progress == null
                          ? child
                          : Container(color: ctx.theme.colors.muted),
                      errorBuilder: (ctx, e, s) => _placeholder(ctx),
                    )
                  : _placeholder(context),
            ),
          ),
          const SizedBox(height: 5),
          ScrollingText(
            text: title,
            style: context.theme.typography.xs.copyWith(
              fontWeight: FontWeight.w600,
              color: context.theme.colors.foreground,
            ),
            maxWidth: 200,
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: context.theme.typography.xs.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
    color: context.theme.colors.muted,
    child: Icon(
      placeholderIcon,
      color: context.theme.colors.mutedForeground,
      size: 28,
    ),
  );
}
