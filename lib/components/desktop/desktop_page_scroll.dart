import 'package:cosmodrome/components/desktop/desktop_layout.dart';
import 'package:flutter/material.dart';

final ValueNotifier<double> desktopScrollOffset = ValueNotifier(0);

class DesktopPageScroll extends StatefulWidget {
  final Widget child;

  const DesktopPageScroll({super.key, required this.child});

  @override
  State<DesktopPageScroll> createState() => _DesktopPageScrollState();
}

class _DesktopPageScrollState extends State<DesktopPageScroll> {
  final _controller = ScrollController();
  bool _isCurrent = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_publish);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (current == _isCurrent) return;
    _isCurrent = current;
    if (!current) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _publish();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _publish() {
    if (!_isCurrent) return;
    desktopScrollOffset.value = _controller.hasClients ? _controller.offset : 0;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      padding: const EdgeInsets.only(
        bottom: DesktopLayout.playerBarReserved + 16,
      ),
      child: widget.child,
    );
  }
}
