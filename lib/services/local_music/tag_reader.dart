// web cannot read tags, so we stub it out
export 'tag_reader_stub.dart' if (dart.library.io) 'tag_reader_io.dart';
