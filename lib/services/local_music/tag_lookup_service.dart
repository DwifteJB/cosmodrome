import 'package:cosmodrome/services/music_brainz.dart';
import 'package:cosmodrome/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

final tagLookupService = TagLookupService();

class TagMatch {
  final String source;
  final String? title;
  final String? artist;
  final String? albumArtist;
  final String? album;
  final int? track;
  final int? disc;
  final int? year;
  final String? genre;
  final String? imageUrl;

  const TagMatch({
    required this.source,
    this.title,
    this.artist,
    this.albumArtist,
    this.album,
    this.track,
    this.disc,
    this.year,
    this.genre,
    this.imageUrl,
  });

  TagMatch fillFrom(TagMatch other) => TagMatch(
    source: source.contains(other.source)
        ? source
        : '$source + ${other.source}',
    title: title ?? other.title,
    artist: artist ?? other.artist,
    albumArtist: albumArtist ?? other.albumArtist,
    album: album ?? other.album,
    track: track ?? other.track,
    disc: disc ?? other.disc,
    year: year ?? other.year,
    genre: genre ?? other.genre,
    imageUrl: imageUrl ?? other.imageUrl,
  );

  String get summary =>
      [?artist, ?album, if (year != null) '$year'].join(' · ');
}

class TagLookupService {
  static const _timeout = Duration(seconds: 12);

  Future<List<TagMatch>> lookup({
    required String title,
    String? artist,
    String? album,
  }) async {
    final query = _Query(title.trim(), _text(artist), _text(album));
    if (query.title.isEmpty) return const [];

    final results = await Future.wait([
      _musicBrainz(query),
      _itunes(query),
      _deezer(query),
      _wikipedia(query),
    ]);
    final matches = [for (final list in results) ...list];
    if (matches.isEmpty) return const [];

    final seen = <String>{};
    final unique = [
      for (final m in matches)
        if (seen.add(
          '${m.source}|${_norm(m.title)}|${_norm(m.artist)}|${_norm(m.album)}',
        ))
          m,
    ];

    final best = unique.firstWhere(
      (m) => m.title != null,
      orElse: () => unique.first,
    );
    var combined = best;
    for (final other in unique) {
      if (identical(other, best)) continue;
      final sameSong = other.title == null || _similar(other.title, best.title);
      final sameAlbum =
          other.album == null ||
          best.album == null ||
          _similar(other.album, best.album);
      if (sameSong && sameAlbum) combined = combined.fillFrom(other);
    }

    return [
      if (combined.source != best.source) combined,
      ...unique.where((m) => m.title != null),
    ];
  }

  List<String> artwork(List<TagMatch> matches) {
    final seen = <String>{};
    return [
      for (final m in matches)
        if (m.imageUrl case final url? when seen.add(url)) url,
    ];
  }

  Future<Uint8List?> image(String url) async {
    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {'User-Agent': musicApiHeaders['User-Agent']!},
          )
          .timeout(_timeout);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      final type = response.headers['content-type'] ?? 'image/';
      if (!type.startsWith('image/')) return null;
      return response.bodyBytes;
    } catch (e) {
      loggerPrint('TagLookup: failed to fetch image $url: $e');
      return null;
    }
  }

  Future<List<TagMatch>> _musicBrainz(_Query query) async {
    try {
      String quote(String v) =>
          '"${v.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
      final parts = [
        'recording:${quote(query.title)}',
        if (query.artist != null) 'artist:${quote(query.artist!)}',
      ];
      const studio =
          'status:official AND primarytype:album AND NOT secondarytype:live';
      var recordings = await _recordings([...parts, studio].join(' AND '));
      if (recordings.isEmpty) {
        recordings = await _recordings(parts.join(' AND '));
      }

      final found = <(TagMatch, String?)>[];
      for (final rec in recordings) {
        if ((rec['score'] as num? ?? 0) < 80) continue;
        if (!_similar(rec['title'] as String?, query.title)) continue;
        final artist = _credit(rec['artist-credit']);
        if (query.artist != null && !_similar(artist, query.artist)) continue;

        final release = _pickRelease(rec['releases'], query.album);
        final media = release?['media'];
        final medium = media is List && media.isNotEmpty ? media.first : null;
        final tracks = medium is Map ? medium['track'] : null;
        final track = tracks is List && tracks.isNotEmpty ? tracks.first : null;
        final group = release?['release-group'];
        final rgid = group is Map ? group['id'] as String? : null;
        final releaseId = release?['id'] as String?;

        found.add((
          TagMatch(
            source: 'MusicBrainz',
            title: _text(rec['title']),
            artist: artist,
            albumArtist: _credit(release?['artist-credit']),
            album: _text(release?['title']),
            track: track is Map
                ? int.tryParse('${track['number'] ?? ''}')
                : null,
            disc: medium is Map ? (medium['position'] as num?)?.toInt() : null,
            year: _year(release?['date']) ?? _year(rec['first-release-date']),
            genre: _topTag(rec['tags']),
            imageUrl: rgid != null
                ? 'https://coverartarchive.org/release-group/$rgid/front-500'
                : releaseId != null
                ? 'https://coverartarchive.org/release/$releaseId/front-500'
                : null,
          ),
          rgid,
        ));
      }

      int rank(TagMatch m) =>
          (_norm(m.title) == _norm(query.title) ? 0 : 4) +
          (query.artist == null || _norm(m.artist) == _norm(query.artist)
              ? 0
              : 2) +
          (query.artist == null || _similar(m.albumArtist, query.artist)
              ? 0
              : 1);
      final ranked = found.indexed.toList()
        ..sort((a, b) {
          final byRank = rank(a.$2.$1).compareTo(rank(b.$2.$1));
          return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
        });
      final matches = [for (final (_, (m, _)) in ranked.take(4)) m];
      final groupId = ranked.firstOrNull?.$2.$2;

      if (matches.isNotEmpty &&
          matches.first.genre == null &&
          groupId != null) {
        final group = await musicBrainz.get('release-group/$groupId', {
          'inc': 'genres+tags',
        });
        final genre = _topTag(group?['genres']) ?? _topTag(group?['tags']);
        if (genre != null) {
          matches[0] = matches.first.fillFrom(
            TagMatch(source: 'MusicBrainz', genre: genre),
          );
        }
      }
      return matches;
    } catch (e) {
      loggerPrint('TagLookup: MusicBrainz failed: $e');
      return const [];
    }
  }

  Future<List<TagMatch>> _itunes(_Query query) async {
    final result = await getMusicJson(
      Uri.https('itunes.apple.com', '/search', {
        'term': [?query.artist, query.title].join(' '),
        'media': 'music',
        'entity': 'song',
        'limit': '8',
      }),
    );
    final items = result?['results'];
    if (items is! List) return const [];
    return [
      for (final item in items.whereType<Map<String, dynamic>>())
        if (_similar(item['trackName'] as String?, query.title) &&
            (query.artist == null ||
                _similar(item['artistName'] as String?, query.artist)))
          TagMatch(
            source: 'iTunes',
            title: _text(item['trackName']),
            artist: _text(item['artistName']),
            albumArtist: _text(item['collectionArtistName']),
            album: _text(item['collectionName']),
            track: (item['trackNumber'] as num?)?.toInt(),
            disc: (item['discNumber'] as num?)?.toInt(),
            year: _year(item['releaseDate']),
            genre: _text(item['primaryGenreName']),
            imageUrl: (item['artworkUrl100'] as String?)?.replaceFirst(
              RegExp(r'\d+x\d+bb'),
              '600x600bb',
            ),
          ),
    ].take(4).toList();
  }

  Future<List<TagMatch>> _deezer(_Query query) async {
    final result = await getMusicJson(
      Uri.https('api.deezer.com', '/search', {
        'q': [?query.artist, query.title].join(' '),
        'limit': '6',
      }),
    );
    final items = result?['data'];
    if (items is! List) return const [];
    return [
      for (final item in items.whereType<Map<String, dynamic>>())
        if (_similar(item['title'] as String?, query.title) &&
            (query.artist == null ||
                _similar(
                  (item['artist'] as Map?)?['name'] as String?,
                  query.artist,
                )))
          TagMatch(
            source: 'Deezer',
            title: _text(item['title']),
            artist: _text((item['artist'] as Map?)?['name']),
            album: _text((item['album'] as Map?)?['title']),
            imageUrl: _text((item['album'] as Map?)?['cover_xl']),
          ),
    ].take(3).toList();
  }

  Future<List<TagMatch>> _wikipedia(_Query query) async {
    final album = query.album;
    if (album == null) return const [];
    final titles = [
      if (query.artist != null) '$album (${query.artist} album)',
      '$album (album)',
      album,
    ];
    for (final title in titles) {
      final page = Uri.encodeComponent(title.replaceAll(' ', '_'));
      final summary = await getMusicJson(
        Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$page'),
      );
      if (summary == null || summary['type'] != 'standard') continue;
      final description = _text(summary['description']) ?? '';
      if (!description.toLowerCase().contains('album')) continue;
      if (query.artist != null &&
          !_norm(
            '$description ${summary['extract'] ?? ''}',
          ).contains(_norm(query.artist))) {
        continue;
      }
      final image =
          _text((summary['originalimage'] as Map?)?['source']) ??
          _text((summary['thumbnail'] as Map?)?['source']);
      return [
        TagMatch(
          source: 'Wikipedia',
          album: album,
          albumArtist: query.artist,
          year: _year(RegExp(r'\b(19|20)\d{2}\b').stringMatch(description)),
          imageUrl: image,
        ),
      ];
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> _recordings(String query) async {
    final result = await musicBrainz.get('recording', {
      'query': query,
      'limit': '10',
    });
    final recordings = result?['recordings'];
    if (recordings is! List) return const [];
    return recordings.whereType<Map<String, dynamic>>().toList();
  }

  Map<String, dynamic>? _pickRelease(Object? releases, String? album) {
    if (releases is! List) return null;
    final list = releases.whereType<Map<String, dynamic>>().toList();
    if (list.isEmpty) return null;
    if (album != null) {
      final named = list.where((r) => _similar(r['title'] as String?, album));
      if (named.isNotEmpty) return named.first;
    }
    final albums =
        list.where((r) {
          final group = r['release-group'];
          return group is Map &&
              group['primary-type'] == 'Album' &&
              (group['secondary-types'] as List?)?.isEmpty != false &&
              r['status'] == 'Official';
        }).toList()..sort(
          (a, b) => ((a['date'] as String?) ?? '9999').compareTo(
            (b['date'] as String?) ?? '9999',
          ),
        );
    return albums.isNotEmpty ? albums.first : list.first;
  }

  String? _credit(Object? credit) {
    if (credit is! List || credit.isEmpty) return null;
    return _text(
      credit
          .whereType<Map>()
          .map((c) => '${c['name'] ?? ''}${c['joinphrase'] ?? ''}')
          .join(),
    );
  }

  String? _topTag(Object? tags) {
    if (tags is! List) return null;
    final sorted =
        tags
            .whereType<Map<String, dynamic>>()
            .where((t) => t['name'] is String && (t['count'] as num? ?? 0) > 0)
            .toList()
          ..sort((a, b) => (b['count'] as num).compareTo(a['count'] as num));
    final name = sorted.firstOrNull?['name'] as String?;
    if (name == null) return null;
    return name
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _norm(String? value) => (value ?? '').toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]', unicode: true),
    '',
  );

  bool _similar(String? a, String? b) {
    final x = _norm(a);
    final y = _norm(b);
    if (x.isEmpty || y.isEmpty) return false;
    return x == y || x.contains(y) || y.contains(x);
  }

  String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  int? _year(Object? value) => value is String && value.length >= 4
      ? int.tryParse(value.substring(0, 4))
      : null;
}

class _Query {
  final String title;
  final String? artist;
  final String? album;

  const _Query(this.title, this.artist, this.album);
}
