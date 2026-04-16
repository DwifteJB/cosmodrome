// figures out if a colour is too close to dark

import 'dart:math';
import 'dart:ui';

/// checks if a colour is too close to black, by calculating the distance from black in the RGB colour space and normalizing it to [0, 1]. If the normalized distance is below the given threshold, the colour is considered too dark.
/// [threshold] is a value between 0 and 1 that determines how close to black a colour can be before it's considered too dark. A lower threshold means only very dark colours will be flagged, while a higher threshold will flag more colours as too dark.
bool isColourTooDark(Color color, {double threshold = 0.0004}) {
  // sees if the colour is similar to black, by checking the distance from black in the RGB colour space
  final distanceFromBlack = sqrt(
    pow(color.r, 2) + pow(color.g, 2) + pow(color.b, 2),
  );
  final maxDistance = sqrt(
    pow(255, 2) * 3,
  ); // max distance from black in RGB space
  final normalizedDistance =
      distanceFromBlack / maxDistance; // normalize to [0, 1]
  return normalizedDistance < threshold;
}
