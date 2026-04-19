import 'dart:io';

import 'package:flutter/widgets.dart';

ImageProvider<Object> coverArtProvider(String url) {
  final uri = Uri.tryParse(url);
  if (uri != null && uri.scheme == 'file') {
    return FileImage(File.fromUri(uri));
  }
  return NetworkImage(url);
}
