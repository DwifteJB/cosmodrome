import 'package:flutter/widgets.dart';

ImageProvider<Object> coverArtProvider(String url) {
  return NetworkImage(url);
}
