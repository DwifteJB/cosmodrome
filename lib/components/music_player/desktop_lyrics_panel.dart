import 'dart:ui';

import 'package:cosmodrome/components/music_player/lyrics_view.dart';
import 'package:cosmodrome/providers/lyrics_provider.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

class DesktopLyricsPanel extends StatelessWidget {
  final double bottomInset;

  const DesktopLyricsPanel({super.key, this.bottomInset = 0});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LyricsProvider>();
    final hasSong = context.select<PlayerProvider, bool>(
      (p) => p.hasCurrentSong,
    );
    final accent = context.select<PlayerProvider, Color?>((p) => p.accentColor);
    final colors = context.theme.colors;
    final typography = context.theme.typography;

    final lyrics = provider.lyrics;

    Widget body;
    if (!hasSong) {
      body = const _LyricsMessage(title: 'Nothing playing');
    } else if (provider.isLoading) {
      body = const _LyricsLoading();
    } else if (lyrics == null || !lyrics.hasLyrics) {
      body = const _LyricsMessage(
        icon: Icons.lyrics_outlined,
        title: 'No lyrics for this song',
      );
    } else {
      body = Stack(
        children: [
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0, 0.06, 0.9, 1],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: LyricsView(
                lyrics: lyrics,
                mainStyle: typography.xl.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                secondaryStyle: typography.sm.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: 24 + bottomInset,
                ),
                showTranslation: provider.showTranslation,
                showPronunciation: provider.showPronunciation,
                accentColor: accent,
              ),
            ),
          ),
          if (provider.hasSecondaryLayers)
            Positioned(
              right: 16,
              bottom: 16 + bottomInset,
              child: _TranslateToggle(
                active: provider.secondaryLayersVisible,
                accent: accent ?? colors.primary,
                onPressed: provider.toggleSecondaryLayers,
              ),
            ),
        ],
      );
    }

    return Material(color: Colors.transparent, child: body);
  }
}

class _LyricsLoading extends StatelessWidget {
  const _LyricsLoading();

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Finding lyrics…',
            style: context.theme.typography.sm.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _LyricsMessage extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;

  const _LyricsMessage({this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 28, color: colors.mutedForeground),
              const SizedBox(height: 12),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: typography.sm.copyWith(color: colors.mutedForeground),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: typography.xs.copyWith(
                  color: colors.mutedForeground.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TranslateToggle extends StatelessWidget {
  final bool active;
  final Color accent;
  final VoidCallback onPressed;

  const _TranslateToggle({
    required this.active,
    required this.accent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return FTooltip(
      tipBuilder: (context, controller) =>
          const Text('Show translation / pronunciation'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Color.alphaBlend(
              colors.foreground.withValues(alpha: 0.12),
              colors.background.withValues(alpha: 0.6),
            ),
            child: InkWell(
              onTap: onPressed,
              hoverColor: colors.foreground.withValues(alpha: 0.06),
              child: SizedBox(
                width: 32,
                height: 32,
                child: Icon(
                  FIcons.languages,
                  size: 16,
                  color: active
                      ? accent
                      : colors.foreground.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
