import 'package:cosmodrome/utils/cover_art/cover_art_provider.dart';
import 'package:cosmodrome/utils/tap_area.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

typedef SongGridTrailingBuilder =
    Widget Function(BuildContext context, bool hovered);

class SongGridItem extends StatefulWidget {
  final String? imageUrl;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final VoidCallback? onPlay;
  final VoidCallback? onLongPress;
  final ValueChanged<Offset>? onContextMenu;
  final SongGridTrailingBuilder? trailingBuilder;

  const SongGridItem({
    super.key,
    required this.title,
    required this.subtitle,
    this.titleColor,
    this.imageUrl,
    this.onPlay,
    this.onLongPress,
    this.onContextMenu,
    this.trailingBuilder,
  });

  @override
  State<SongGridItem> createState() => _SongGridItemState();
}

class _SongGridItemState extends State<SongGridItem> {
  bool _hovered = false;
  bool? _pendingHovered;

  bool get _visible => ModalRoute.isCurrentOf(context) ?? true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pendingHovered != null && _visible) {
      _hovered = _pendingHovered!;
      _pendingHovered = null;
    }
  }

  void _setHovered(bool hovered) {
    if (_hovered == hovered) return;
    if (!_visible) {
      _pendingHovered = hovered;
      return;
    }
    setState(() => _hovered = hovered);
  }

  @override
  Widget build(BuildContext context) {
    final onContextMenu = widget.onContextMenu;

    Widget child = TapArea(
      onTap: widget.onPlay,
      onLongTap: onContextMenu == null ? widget.onLongPress : null,
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
                  child: widget.imageUrl != null
                      ? Image(
                          image: coverArtProvider(widget.imageUrl!),
                          width: double.infinity,
                          height: double.infinity,
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
                                      : _placeholder(
                                          ctx,
                                          key: const ValueKey('placeholder'),
                                        ),
                                );
                              },
                          errorBuilder: (ctx, e, s) => _placeholder(ctx),
                        )
                      : _placeholder(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: context.theme.typography.sm.copyWith(
                        color:
                            widget.titleColor ??
                            context.theme.colors.foreground,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: context.theme.typography.xs.copyWith(
                        color: context.theme.colors.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.trailingBuilder != null) ...[
                const SizedBox(width: 4),
                widget.trailingBuilder!(context, _hovered),
                const SizedBox(width: 4),
              ] else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );

    if (onContextMenu != null) {
      child = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: (d) => onContextMenu(d.globalPosition),
        onLongPressStart: (d) => onContextMenu(d.globalPosition),
        child: child,
      );
    }

    if (widget.trailingBuilder != null) {
      child = MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: child,
      );
    }

    return child;
  }

  Widget _placeholder(BuildContext context, {Key? key}) => Container(
    key: key,
    color: context.theme.colors.muted,
    child: Icon(Icons.music_note, color: context.theme.colors.mutedForeground),
  );
}
