// TODO: if logged in, use subsonic to get tracks & info.
import 'package:cosmodrome/components/grid_based_layout.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridBasedLayoutBuilder(
        maxCardsPerLine: 4,
        cards: List.from(
          Iterable.generate(
            200,
            (i) => SizedBox(
              height: 100,
              child: Card(child: Center(child: Text('Card $i'))),
            ),
          ),
        ),
      ),
    );
  }
}
