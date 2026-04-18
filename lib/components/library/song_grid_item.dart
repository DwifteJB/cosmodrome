import 'package:cosmodrome/utils/tap_area.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class SongGridItem extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback? onPlay;
  final VoidCallback? onLongPress;

  const SongGridItem({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.onPlay,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return TapArea(
      onTap: onPlay,
      onLongTap: onLongPress,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          frameBuilder:
                              (ctx, child, frame, wasSynchronouslyLoaded) {
                                if (wasSynchronouslyLoaded) return child;
                                return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: frame != null
                                      ? KeyedSubtree(
                                          key: const ValueKey('img'),
                                          child: child,
                                        )
                                      : Container(
                                          key: const ValueKey('placeholder'),
                                          color: ctx.theme.colors.muted,
                                          child: Icon(
                                            Icons.music_note,
                                            color: ctx
                                                .theme
                                                .colors
                                                .mutedForeground,
                                          ),
                                        ),
                                );
                              },
                          errorBuilder: (ctx, e, s) => Container(
                            color: ctx.theme.colors.muted,
                            child: Icon(
                              Icons.music_note,
                              color: ctx.theme.colors.mutedForeground,
                            ),
                          ),
                        )
                      : Container(
                          color: context.theme.colors.muted,
                          child: Icon(
                            Icons.music_note,
                            color: context.theme.colors.mutedForeground,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: context.theme.typography.sm.copyWith(
                        color: context.theme.colors.foreground,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: context.theme.typography.xs.copyWith(
                        color: context.theme.colors.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}
