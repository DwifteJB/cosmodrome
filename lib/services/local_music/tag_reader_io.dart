import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:cosmodrome/services/local_music/local_tags.dart';

Future<LocalTags?> readLocalTags(String ref) async {
  try {
    return await Isolate.run(() => _read(ref));
  } catch (_) {
    return null;
  }
}

// get music id3 tags
LocalTags? _read(String path) {
  try {
    final meta = readMetadata(File(path), getImage: true);
    final pictures = [...meta.pictures]
      ..sort(
        (a, b) => (a.pictureType == PictureType.coverFront ? 0 : 1).compareTo(
          b.pictureType == PictureType.coverFront ? 0 : 1,
        ),
      );
    return LocalTags(
      title: _clean(meta.title),
      artist: _clean(meta.artist),
      albumArtist: _clean(meta.albumArtist),
      album: _clean(meta.album),
      track: meta.trackNumber,
      disc: meta.discNumber,
      duration: meta.duration?.inSeconds,
      year: meta.year?.year,
      genre: meta.genres.isEmpty ? null : _clean(meta.genres.first),
      bitRate: meta.bitrate == null ? null : _kbps(meta.bitrate!),
      sampleRate: meta.sampleRate,
      picture: pictures.firstOrNull?.bytes,
    );
  } catch (_) {
    return null;
  }
}

int _kbps(int bitrate) => bitrate > 10000 ? bitrate ~/ 1000 : bitrate;

String? _clean(String? value) {
  final trimmed = value?.replaceAll('\u0000', '').trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
