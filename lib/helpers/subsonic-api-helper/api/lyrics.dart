// lyrics + opensubsonic extension discovery
//
// https://opensubsonic.netlify.app/docs/endpoints/getopensubsonicextensions/
// https://opensubsonic.netlify.app/docs/endpoints/getlyricsbysongid/
// https://www.subsonic.org/pages/api.jsp#getLyrics

import 'package:cosmodrome/helpers/subsonic-api-helper/subsonic.dart';
import 'package:cosmodrome/helpers/subsonic-api-helper/types/lyrics.dart';
import 'package:cosmodrome/utils/logger/logger.dart';

const songLyricsExtension = 'songLyrics';

// to cache since they cannot change
final Map<String, List<OpenSubsonicExtension>> _extensionCache = {};

extension SubsonicLyricsApi on Subsonic {
  String get _extensionCacheKey => '$baseUrl|${auth.username}';

  // lists all extensions
  Future<List<OpenSubsonicExtension>> getOpenSubsonicExtensions({
    bool forceRefresh = false,
  }) async {
    final cached = _extensionCache[_extensionCacheKey];
    if (cached != null && !forceRefresh) return cached;

    try {
      final response = await apiRequest(
        'getOpenSubsonicExtensions',
        forceRefresh: forceRefresh,
      );
      final raw = response['openSubsonicExtensions'] as List<dynamic>? ?? [];
      final extensions = raw
          .map((e) => OpenSubsonicExtension.fromJson(e as Map<String, dynamic>))
          .toList();
      _extensionCache[_extensionCacheKey] = extensions;
      return extensions;
    } catch (e) {
      loggerPrint('Error fetching OpenSubsonic extensions: $e');
      // remember failure, as it may not be opensubsonic
      _extensionCache[_extensionCacheKey] = const [];
      return const [];
    }
  }

  // highest supported version of the songLyrics extension, or null if not supported
  Future<int?> songLyricsVersion() async {
    final extensions = await getOpenSubsonicExtensions();
    for (final ext in extensions) {
      if (ext.name == songLyricsExtension) {
        return ext.maxVersion == 0 ? 1 : ext.maxVersion;
      }
    }
    return null;
  }

  // get all structured lyrics via songID
  Future<List<StructuredLyrics>> getLyricsBySongId(
    String id, {
    bool enhanced = false,
  }) async {
    try {
      final response = await apiRequest(
        'getLyricsBySongId',
        params: {'id': id, if (enhanced) 'enhanced': 'true'},
      );
      final list = response['lyricsList'] as Map<String, dynamic>?;
      final raw = list?['structuredLyrics'];
      if (raw == null) return const [];
      // some servers return a single object instead of an array
      final entries = raw is List ? raw : [raw];
      return entries
          .map((e) => StructuredLyrics.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      loggerPrint('Error fetching lyrics for song $id: $e');
      return const [];
    }
  }

  // legacy lyrics, which is just a text blob, no structure
  Future<String?> getLyrics({String? artist, String? title}) async {
    try {
      final response = await apiRequest(
        'getLyrics',
        params: {
          if (artist != null && artist.isNotEmpty) 'artist': artist,
          if (title != null && title.isNotEmpty) 'title': title,
        },
      );
      final lyrics = response['lyrics'] as Map<String, dynamic>?;
      final value = lyrics?['value'] as String?;
      if (value == null || value.trim().isEmpty) return null;
      return value;
    } catch (e) {
      loggerPrint('Error fetching lyrics for $artist - $title: $e');
      return null;
    }
  }
}
