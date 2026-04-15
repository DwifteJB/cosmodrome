// simple text that scrolls if it's too long, otherwise just shows normally
import 'package:flutter/material.dart';

class ScrollingText extends StatefulWidget {
  final String text;
  final int duration;
  final TextStyle? style;
  final double maxWidth;

  const ScrollingText({
    super.key,
    required this.text,
    this.duration = 10,
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
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: Text(widget.text, style: widget.style),
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