// simple text that scrolls if it's too long, otherwise just shows normally
import 'package:flutter/material.dart';

class ScrollingText extends StatefulWidget {
  final String text;
  int duration;
  final TextStyle? style;
  final double maxWidth;

  ScrollingText({
    super.key,
    required this.text,
    this.duration = 5,
    this.style,
    required this.maxWidth,
  });

  @override
  _ScrollingTextState createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;

  @override
  Widget build(BuildContext context) {
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
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.duration),
    )..addListener(() {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_animationController.value *
              _scrollController.position.maxScrollExtent);
        }
      });

    if (widget.duration == 0) {
      // set duration based on text length (assuming ~10 chars per second)
      widget.duration = (widget.text.length / 10).ceil();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());
  }

  void _startAnimation() {
    if (_scrollController.position.maxScrollExtent > 0) {
      // go back the other way
      _animationController.forward().then((_) {
        // wait a second at the end before scrolling back
        Future.delayed(const Duration(seconds: 1), () {
          _animationController.reverse().then((_) => _startAnimation());
        });
      });
    }
  }
}