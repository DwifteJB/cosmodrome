import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:cosmodrome/services/local_music/local_tags.dart';
import 'package:cosmodrome/utils/logger/logger.dart';

const canWriteLocalTags = true;

Future<bool> writeLocalTags(String ref, LocalTagEdit edit) async {
  try {
    await Isolate.run(() => _write(ref, edit));
    return true;
  } catch (e) {
    loggerPrint('LocalMusic: failed to write tags to $ref: $e');
    return false;
  }
}

void _write(String path, LocalTagEdit edit) {
  final file = File(path);
  if (path.toLowerCase().endsWith('.mp3') && !_hasId3v2(file)) {
    Id3v4Writer().write(file, Mp3Metadata());
  }

  updateMetadata(file, (meta) {
    meta
      ..setTitle(edit.title)
      ..setArtist(edit.artist)
      ..setAlbum(edit.album)
      ..setTrackNumber(edit.track)
      ..setYear(edit.year == null ? null : DateTime(edit.year!))
      ..setGenres([?edit.genre]);
    _setExtras(meta, edit);
    if (edit.pictureChanged) {
      final picture = edit.picture;
      meta.setPictures([
        if (picture != null && picture.isNotEmpty)
          Picture(picture, _mimeType(picture), PictureType.coverFront),
      ]);
    }
  });

  if (readMetadata(file).title != edit.title) {
    throw StateError('tags were not written');
  }
}

bool _hasId3v2(File file) {
  final reader = file.openSync();
  try {
    return MP3Parser.hasID3v2Tag(reader);
  } finally {
    reader.closeSync();
  }
}

void _setExtras(Object meta, LocalTagEdit edit) {
  switch (meta) {
    case Mp3Metadata m:
      m.partOfSet = edit.disc?.toString();
      m.bandOrOrchestra = edit.albumArtist;
      m.contentType = null;
    case Mp4Metadata m:
      m.discNumber = edit.disc;
    case VorbisMetadata m:
      m.discNumber = edit.disc;
      m.albumArtist = [?edit.albumArtist];
    case ApeMetadata m:
      m.discNumber = edit.disc;
      m.albumArtist = edit.albumArtist;
  }
}

String _mimeType(Uint8List bytes) {
  if (bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50) {
    return 'image/png';
  }
  if (bytes.length > 3 && bytes[0] == 0x47 && bytes[1] == 0x49) {
    return 'image/gif';
  }
  if (bytes.length > 11 && bytes[8] == 0x57 && bytes[9] == 0x45) {
    return 'image/webp';
  }
  return 'image/jpeg';
}
