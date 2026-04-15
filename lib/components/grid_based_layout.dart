import 'package:flutter/widgets.dart';

double generateCardWidth(int axisCount, double spacing, double maxWidth) {
  if (axisCount == 1) {
    return maxWidth;
  }

  return (maxWidth - (spacing * (axisCount - 1))) / axisCount;
}

int generateAxisCount(
  BoxConstraints constraints,
  int maxCardsPerLine,
  int totalCards, {
  int customMaxWidthMd = 768,
  int customMaxWidthLg = 1200,
}) {
  int realMaxCardsPerLine = maxCardsPerLine;

  if (totalCards < maxCardsPerLine) {
    realMaxCardsPerLine = totalCards;
  }

  if (constraints.maxWidth > customMaxWidthLg) {
    return realMaxCardsPerLine;
  } else if (constraints.maxWidth > customMaxWidthMd) {
    // see if we can fit half cards within (so / 2 and check if even)
    if (maxCardsPerLine / 2 % 1 == 0) {
      // even, so just return half
      return (maxCardsPerLine / 2).floor();
    } else {
      // odd, so return half rounded up
      return (maxCardsPerLine / 2).ceil();
    }
  }

  return 1;
}

class GridBasedLayoutBuilder extends StatelessWidget {
  final List<Widget> cards;
  final double spacing;
  final int maxCardsPerLine;

  final int customMaxWidthMd;
  final int customMaxWidthLg;

  const GridBasedLayoutBuilder({
    super.key,
    required this.cards,
    this.spacing = 16.0,
    required this.maxCardsPerLine,
    this.customMaxWidthMd = 768,
    this.customMaxWidthLg = 1200,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final axisCount = generateAxisCount(
          constraints,
          maxCardsPerLine,
          cards.length,
          customMaxWidthMd: customMaxWidthMd,
          customMaxWidthLg: customMaxWidthLg,
        );

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          clipBehavior: Clip.none,
          children: cards.map((card) {
            final cardWidth = generateCardWidth(
              axisCount,
              spacing,
              constraints.maxWidth,
            );

            return Padding(
              padding: EdgeInsets.only(left: 10, right: 10),
              child: SizedBox(width: cardWidth - 20, child: card),
            );
          }).toList(),
        );
      },
    );
  }
}
