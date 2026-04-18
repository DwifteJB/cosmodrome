import 'package:flutter/material.dart';

class ScrollingText extends StatefulWidget {
  final String text;
  final int duration;
  final TextStyle? style;
  final double maxWidth;

  const ScrollingText({
    super.key,
    required this.text,
    this.duration = 5,
    this.style,
    this.maxWidth = double.infinity,
  });

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  bool _needsScroll = false;

  @override
  Widget build(BuildContext context) {
    // if the text fits within the max width, just show it without scrolling
    if (widget.maxWidth.isFinite && !_needsScroll) {
      return Text(widget.text, style: widget.style, maxLines: 1);
    }

    return SizedBox(
      width: widget.maxWidth,
      child: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(
          scrollbars: false,
          overscroll: false,
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: Text(widget.text, style: widget.style),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(ScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text &&
        oldWidget.style == widget.style &&
        oldWidget.maxWidth == widget.maxWidth) {
      return;
    }

    // reset anim before measuring
    _animationController.stop();
    _animationController.reset();

    if (widget.maxWidth.isFinite) {
      _needsScroll = _measure();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      _startAnimation();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.maxWidth.isFinite) {
      _needsScroll = _measure();
    }
    final duration = widget.duration == 0
        ? (widget.text.length / 5).ceil()
        : widget.duration;
    _scrollController = ScrollController();
    _animationController =
        AnimationController(
          vsync: this,
          duration: Duration(seconds: duration),
        )..addListener(() {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _animationController.value *
                  _scrollController.position.maxScrollExtent,
            );
          }
        });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());
  }

  bool _measure() {
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.size.width > widget.maxWidth;
  }

  void _startAnimation() {
    if (!mounted || !_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent > 0) {
      _animationController.forward().then((_) {
        if (!mounted) return;
        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          _animationController.reverse().then((_) {
            if (mounted) _startAnimation();
          });
        });
      });
    }
  }
}
