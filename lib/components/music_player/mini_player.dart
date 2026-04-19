/*
  MOBILE ONLY!

  this mini player should be used on small screens / mobile only due to how the bottom bar in the layout works :)
  
*/

import 'dart:ui';

import 'package:cosmodrome/components/music_player/fullscreen_player.dart';
import 'package:cosmodrome/components/scrolling_text.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:cosmodrome/utils/cover_art_provider.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) return const SizedBox.shrink();

        final colors = context.theme.colors;
        final coverUrl = player.currentCoverArtUrl;

        return GestureDetector(
          onTap: () => showFSheet(
            context: context,
            side: FLayout.btt,
            mainAxisMaxRatio: 1.0,
            useSafeArea: false,
            builder: (_) => const FullscreenPlayer(),
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: colors.border, width: 1),
              borderRadius: BorderRadius.circular(28),
              color: Colors.black.withValues(alpha: 0.55),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: coverUrl != null
                            ? Image(
                                image: coverArtProvider(coverUrl),
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) =>
                                    _coverPlaceholder(),
                              )
                            : _coverPlaceholder(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ScrollingText(
                          text: song.title,
                          style: context.theme.typography.xs.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxWidth: 200,
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            player.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          onPressed: () => player.togglePlay(),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      width: 32,
      height: 32,
      color: Colors.grey[800],
      child: const Icon(Icons.music_note, color: Colors.white54, size: 16),
    );
  }
}
