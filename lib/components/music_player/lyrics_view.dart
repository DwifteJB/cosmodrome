import 'dart:async';
import 'dart:math' as math;

import 'package:cosmodrome/providers/lyrics_provider.dart';
import 'package:cosmodrome/providers/player_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

const int _kInterludeGapMs = 7000;

const int _kLineHoldMs = 3500;

const int _kInterludeLeadMs = 300;

const Duration _kManualScrollTimeout = Duration(seconds: 3);

const double _kHoverInset = 8;

const double _kInactiveScale = 0.94;

class LyricsView extends StatefulWidget {
  final SongLyrics lyrics;

  final TextStyle? mainStyle;

  final TextStyle? secondaryStyle;
  final EdgeInsets padding;

  final double lineSpacing;
  final bool showTranslation;
  final bool showPronunciation;

  final Color? accentColor;

  final bool enableHover;
  final TextAlign alignment;

  final double? topSpacer;
  final double? bottomSpacer;

  const LyricsView({
    super.key,
    required this.lyrics,
    this.mainStyle,
    this.secondaryStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    this.lineSpacing = 28,
    this.showTranslation = true,
    this.showPronunciation = true,
    this.accentColor,
    this.enableHover = true,
    this.alignment = TextAlign.left,
    this.topSpacer,
    this.bottomSpacer,
  });

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

sealed class _Block {
  int? get seekMs;
}

class _LineBlock extends _Block {
  final int lineIndex;
  final int? startMs;

  _LineBlock(this.lineIndex, this.startMs);

  @override
  int? get seekMs => startMs;
}

class _InterludeBlock extends _Block {
  final int startMs;

  final int endMs;

  _InterludeBlock(this.startMs, this.endMs);

  @override
  int get seekMs => startMs;
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _controller = ScrollController();

  List<_Block> _blocks = const [];

  List<int> _lineToBlock = const [];
  List<GlobalKey> _blockKeys = const [];

  int _lastActive = -1;
  bool _userScrolling = false;
  Timer? _resumeTimer;

  @override
  void initState() {
    super.initState();
    _rebuildBlocks();
  }

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.lyrics, widget.lyrics)) {
      final songChanged = oldWidget.lyrics.songId != widget.lyrics.songId;
      _rebuildBlocks();
      if (songChanged) {
        _lastActive = -1;
        _userScrolling = false;
        _resumeTimer?.cancel();
        _resumeTimer = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _controller.hasClients) _controller.jumpTo(0);
        });
      }
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    _rebuildBlocks();
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _rebuildBlocks() {
    final lyrics = widget.lyrics;
    final lines = lyrics.lines;
    final blocks = <_Block>[];
    final lineToBlock = List<int>.filled(lines.length, -1);

    if (!lyrics.synced) {
      for (var i = 0; i < lines.length; i++) {
        lineToBlock[i] = blocks.length;
        blocks.add(_LineBlock(i, null));
      }
    } else {
      final ends = _lineEndsMs(lyrics);
      final gapThreshold = _interludeThresholdMs(lyrics);
      int? prevStart;
      int? prevEnd;
      for (var i = 0; i < lines.length; i++) {
        final start = lyrics.lineStartMs(i);
        if (start != null) {
          if (prevStart == null) {
            if (start >= _kInterludeGapMs) {
              blocks.add(_InterludeBlock(0, start - _kInterludeLeadMs));
            }
          } else if (prevEnd != null) {
            // real end times, so a pause is simply silence after the line
            if (start - prevEnd >= _kInterludeGapMs) {
              blocks.add(_InterludeBlock(prevEnd, start - _kInterludeLeadMs));
            }
          } else if (start - prevStart >= gapThreshold) {
            final end = start - _kInterludeLeadMs;
            final hold = math.min(_kLineHoldMs, (end - prevStart) ~/ 2);
            blocks.add(_InterludeBlock(prevStart + hold, end));
          }
          prevStart = start;
          prevEnd = ends[i];
        }
        lineToBlock[i] = blocks.length;
        blocks.add(_LineBlock(i, start));
      }
    }

    _blocks = blocks;
    _lineToBlock = lineToBlock;
    _blockKeys = List.generate(blocks.length, (_) => GlobalKey());
  }

  // only starts are known for most lyrics, so a pause has to be long
  // compared to how far apart this song's lines usually are
  static int _interludeThresholdMs(SongLyrics lyrics) {
    final gaps = <int>[];
    int? prev;
    for (var i = 0; i < lyrics.lines.length; i++) {
      final start = lyrics.lineStartMs(i);
      if (start == null) continue;
      if (prev != null && start > prev) gaps.add(start - prev);
      prev = start;
    }
    if (gaps.isEmpty) return _kInterludeGapMs;
    gaps.sort();
    final median = gaps[gaps.length ~/ 2];
    return math.max(_kInterludeGapMs, median * 2);
  }

  static List<int?> _lineEndsMs(SongLyrics lyrics) {
    final main = lyrics.main;
    final ends = List<int?>.filled(lyrics.lines.length, null);
    if (main == null) return ends;
    for (final cue in main.cueLines) {
      final end = cue.end;
      if (end == null || cue.index < 0 || cue.index >= ends.length) continue;
      final adjusted = end - main.offset;
      final existing = ends[cue.index];
      if (existing == null || adjusted > existing) ends[cue.index] = adjusted;
    }
    return ends;
  }

  int _activeBlockFor(Duration position) {
    final lyrics = widget.lyrics;
    if (!lyrics.synced || _blocks.isEmpty) return -1;

    final ms = position.inMilliseconds;
    final lineIndex = lyrics.lineIndexAt(position);

    if (lineIndex == kLyricsNoLine) {
      return _blocks.first is _InterludeBlock ? 0 : -1;
    }

    final blockIndex = _lineToBlock[lineIndex];
    if (blockIndex < 0) return -1;

    final nextIndex = blockIndex + 1;
    if (nextIndex < _blocks.length) {
      final next = _blocks[nextIndex];
      if (next is _InterludeBlock && ms >= next.startMs) return nextIndex;
    }
    return blockIndex;
  }

  void _scrollToActive(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= _blockKeys.length) return;
    final ctx = _blockKeys[blockIndex].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.35,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  void _onActiveChanged(int active) {
    _lastActive = active;
    if (_userScrolling || active < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _userScrolling) return;
      _scrollToActive(active);
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    final isUser = switch (notification) {
      UserScrollNotification(:final direction) =>
        direction != ScrollDirection.idle,
      ScrollStartNotification(:final dragDetails) => dragDetails != null,
      _ => false,
    };
    if (!isUser) return false;

    _userScrolling = true;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_kManualScrollTimeout, () {
      if (!mounted) return;
      _userScrolling = false;
      _scrollToActive(_lastActive);
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = widget.lyrics;
    final colors = context.theme.colors;
    final typography = context.theme.typography;

    final mainStyle =
        widget.mainStyle ??
        typography.xl.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.25,
        );
    final secondaryStyle =
        widget.secondaryStyle ??
        typography.sm.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.3,
        );
    final mainColor = mainStyle.color ?? colors.foreground;
    final secondaryColor = secondaryStyle.color ?? colors.mutedForeground;

    final active = lyrics.synced
        ? context.select<PlayerProvider, int>(
            (p) => _activeBlockFor(p.position),
          )
        : -1;
    if (active != _lastActive) _onActiveChanged(active);

    final hover = widget.enableHover;
    final inset = hover ? _kHoverInset : 0.0;
    final listPadding = widget.padding.copyWith(
      left: math.max(0, widget.padding.left - inset),
      right: math.max(0, widget.padding.right - inset),
    );
    final gap = math.max(0.0, widget.lineSpacing - inset * 2);

    final crossAxis = switch (widget.alignment) {
      TextAlign.center => CrossAxisAlignment.center,
      TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.start,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 600.0;
        final topSpacer = widget.topSpacer ?? viewport * 0.5;
        final bottomSpacer = widget.bottomSpacer ?? viewport * 0.5;

        final children = <Widget>[SizedBox(height: topSpacer)];
        for (var i = 0; i < _blocks.length; i++) {
          if (i > 0) children.add(SizedBox(height: gap));
          children.add(
            _buildBlock(
              i,
              active: active,
              mainStyle: mainStyle,
              secondaryStyle: secondaryStyle,
              mainColor: mainColor,
              secondaryColor: secondaryColor,
              inset: inset,
            ),
          );
        }
        children.add(SizedBox(height: bottomSpacer));

        return NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: SingleChildScrollView(
            controller: _controller,
            padding: listPadding,
            child: Column(crossAxisAlignment: crossAxis, children: children),
          ),
        );
      },
    );
  }

  Widget _buildBlock(
    int index, {
    required int active,
    required TextStyle mainStyle,
    required TextStyle secondaryStyle,
    required Color mainColor,
    required Color secondaryColor,
    required double inset,
  }) {
    final lyrics = widget.lyrics;
    final block = _blocks[index];
    final synced = lyrics.synced;

    final isActive = synced && index == active;
    final isPast = synced && active >= 0 && index < active;
    final distance = synced && active >= 0 && index > active
        ? index - active
        : (synced && active < 0 ? index + 1 : 0);

    final seekMs = block.seekMs;
    final onTap = seekMs == null
        ? null
        : () => context.read<PlayerProvider>().seekTo(
            Duration(milliseconds: seekMs),
          );

    switch (block) {
      case _InterludeBlock():
        return _LyricBlock(
          key: _blockKeys[index],
          isActive: isActive,
          isPast: isPast,
          distance: distance,
          synced: synced,
          enableHover: widget.enableHover,
          inset: inset,
          accentColor: widget.accentColor,
          hoverBase: mainColor,
          onTap: onTap,
          alignment: widget.alignment,
          child: _InterludeDots(
            color: mainColor,
            isActive: isActive,
            startMs: block.startMs,
            endMs: block.endMs,
          ),
        );
      case _LineBlock(:final lineIndex):
        final pronunciation = widget.showPronunciation
            ? lyrics.layerLineFor(lyrics.pronunciation, lineIndex)?.value
            : null;
        final translation = widget.showTranslation
            ? lyrics.layerLineFor(lyrics.translation, lineIndex)?.value
            : null;
        return _LyricBlock(
          key: _blockKeys[index],
          isActive: isActive,
          isPast: isPast,
          distance: distance,
          synced: synced,
          enableHover: widget.enableHover,
          inset: inset,
          accentColor: widget.accentColor,
          hoverBase: mainColor,
          onTap: onTap,
          alignment: widget.alignment,
          child: _LineText(
            text: lyrics.lines[lineIndex].value,
            pronunciation: _nonEmpty(pronunciation),
            translation: _nonEmpty(translation),
            mainStyle: mainStyle,
            secondaryStyle: secondaryStyle,
            mainColor: mainColor,
            secondaryColor: secondaryColor,
            alignment: widget.alignment,
          ),
        );
    }
  }

  static String? _nonEmpty(String? s) =>
      s == null || s.trim().isEmpty ? null : s;
}

double _blockOpacity({
  required bool synced,
  required bool isActive,
  required bool isPast,
  required int distance,
}) {
  if (!synced) return 0.85;
  if (isActive) return 1.0;
  if (isPast) return 0.35;
  return math.max(0.25, 0.55 - 0.1 * (distance - 1));
}

class _LyricBlock extends StatefulWidget {
  final bool isActive;
  final bool isPast;
  final int distance;
  final bool synced;
  final bool enableHover;
  final double inset;
  final Color? accentColor;
  final Color hoverBase;
  final VoidCallback? onTap;
  final TextAlign alignment;
  final Widget child;

  const _LyricBlock({
    super.key,
    required this.isActive,
    required this.isPast,
    required this.distance,
    required this.synced,
    required this.enableHover,
    required this.inset,
    required this.accentColor,
    required this.hoverBase,
    required this.onTap,
    required this.alignment,
    required this.child,
  });

  @override
  State<_LyricBlock> createState() => _LyricBlockState();
}

class _LyricBlockState extends State<_LyricBlock> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hovered = widget.enableHover && _hovered;
    final opacity = hovered
        ? 1.0
        : _blockOpacity(
            synced: widget.synced,
            isActive: widget.isActive,
            isPast: widget.isPast,
            distance: widget.distance,
          );
    final scale = !widget.synced || widget.isActive ? 1.0 : _kInactiveScale;
    final scaleAlignment = switch (widget.alignment) {
      TextAlign.center => Alignment.center,
      TextAlign.right || TextAlign.end => Alignment.centerRight,
      _ => Alignment.centerLeft,
    };

    final accent = widget.accentColor;
    final hoverColor = accent != null
        ? accent.withValues(alpha: 0.10)
        : widget.hoverBase.withValues(alpha: 0.06);

    Widget body = AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: AnimatedScale(
        scale: scale,
        alignment: scaleAlignment,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );

    body = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.all(widget.inset),
      decoration: BoxDecoration(
        color: hovered ? hoverColor : hoverColor.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: body,
    );

    if (widget.onTap != null) {
      body = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: body,
      );
    }

    if (widget.enableHover) {
      body = MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: body,
      );
    }

    return RepaintBoundary(child: body);
  }
}

class _LineText extends StatelessWidget {
  final String text;
  final String? pronunciation;
  final String? translation;
  final TextStyle mainStyle;
  final TextStyle secondaryStyle;
  final Color mainColor;
  final Color secondaryColor;
  final TextAlign alignment;

  const _LineText({
    required this.text,
    required this.pronunciation,
    required this.translation,
    required this.mainStyle,
    required this.secondaryStyle,
    required this.mainColor,
    required this.secondaryColor,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxis = switch (alignment) {
      TextAlign.center => CrossAxisAlignment.center,
      TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.start,
    };
    final secondary = secondaryStyle.copyWith(color: secondaryColor);

    return Column(
      crossAxisAlignment: crossAxis,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: mainStyle.copyWith(color: mainColor),
          textAlign: alignment,
          softWrap: true,
        ),
        if (pronunciation != null) ...[
          const SizedBox(height: 6),
          Text(
            pronunciation!,
            style: secondary,
            textAlign: alignment,
            softWrap: true,
          ),
        ],
        if (translation != null) ...[
          const SizedBox(height: 6),
          Text(
            translation!,
            style: secondary,
            textAlign: alignment,
            softWrap: true,
          ),
        ],
      ],
    );
  }
}

class _InterludeDots extends StatefulWidget {
  final Color color;
  final bool isActive;
  final int startMs;
  final int endMs;

  const _InterludeDots({
    required this.color,
    required this.isActive,
    required this.startMs,
    required this.endMs,
  });

  @override
  State<_InterludeDots> createState() => _InterludeDotsState();
}

class _InterludeDotsState extends State<_InterludeDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant _InterludeDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.isActive && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final span = math.max(1, widget.endMs - widget.startMs);
    final progress = widget.isActive
        ? context.select<PlayerProvider, int>((p) {
                final t = (p.position.inMilliseconds - widget.startMs) / span;
                return (t.clamp(0.0, 1.0) * 20).round();
              }) /
              20
        : 0.0;

    final size = widget.isActive ? 8.0 : 6.0;
    return SizedBox(
      height: 20,
      width: size * 3 + 14,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => CustomPaint(
          painter: _InterludeDotsPainter(
            color: widget.color,
            dotSize: size,
            progress: progress,
            pulse: _pulse.value,
            active: widget.isActive,
          ),
        ),
      ),
    );
  }
}

class _InterludeDotsPainter extends CustomPainter {
  final Color color;
  final double dotSize;
  final double progress;
  final double pulse;
  final bool active;

  const _InterludeDotsPainter({
    required this.color,
    required this.dotSize,
    required this.progress,
    required this.pulse,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 7.0;
    final paint = Paint()..style = PaintingStyle.fill;
    final cy = size.height / 2;

    for (var i = 0; i < 3; i++) {
      final cx = dotSize / 2 + i * (dotSize + gap);

      final fill = ((progress * 3) - i).clamp(0.0, 1.0);

      var scale = 1.0;
      var glow = 0.0;
      if (active) {
        final phase = (pulse - i * 0.2) % 1.0;
        final wave = math.sin(phase * math.pi);
        scale = 1 + 0.18 * wave;
        glow = 0.25 * wave;
      }

      final alpha = active ? (0.3 + 0.7 * fill + glow).clamp(0.0, 1.0) : 0.3;
      paint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(cx, cy), dotSize / 2 * scale, paint);
    }
  }

  @override
  bool shouldRepaint(_InterludeDotsPainter old) =>
      old.color != color ||
      old.dotSize != dotSize ||
      old.progress != progress ||
      old.pulse != pulse ||
      old.active != active;
}
