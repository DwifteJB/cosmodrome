import 'package:cosmodrome/helpers/subsonic-api-helper/api/browsing.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/browsing.dart';
import 'package:cosmodrome/utils/cover_art/cover_art_provider.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

class AlbumCard extends StatelessWidget {
  static const double _cardWidth = 150.0;
  final Album album;

  final Subsonic subsonic;

  const AlbumCard({super.key, required this.album, required this.subsonic});

  @override
  Widget build(BuildContext context) {
    const cardWidth = _cardWidth;
    final coverUrl = album.coverArt != null
        ? subsonic.cachedCoverArtUrl(album.coverArt!, size: 300)
        : null;

    return GestureDetector(
      onTap: () => context.push('/library/album/${album.id}'),
      child: SizedBox(
        width: cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: coverUrl != null
                  ? Image(
                      image: coverArtProvider(coverUrl),
                      width: cardWidth,
                      height: cardWidth,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: cardWidth,
                          height: cardWidth,
                          decoration: BoxDecoration(
                            color: context.theme.colors.muted,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      },
                      errorBuilder: (ctx, err, stack) => Container(
                        width: cardWidth,
                        height: cardWidth,
                        color: context.theme.colors.muted,
                        child: Icon(
                          Icons.album,
                          color: context.theme.colors.mutedForeground,
                          size: 40,
                        ),
                      ),
                    )
                  : Container(
                      width: cardWidth,
                      height: cardWidth,
                      color: context.theme.colors.muted,
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              album.name,
              style: context.theme.typography.sm.copyWith(
                fontWeight: FontWeight.w400,
                color: context.theme.colors.foreground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              album.artist,
              style: context.theme.typography.xs.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
