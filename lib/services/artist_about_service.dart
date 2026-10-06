import 'dart:async';
import 'dart:convert';

import 'package:cosmodrome/services/offline_cache_service.dart';
import 'package:cosmodrome/utils/logger/logger.dart';
import 'package:http/http.dart' as http;

final artistAboutService = ArtistAboutService();

class ArtistAbout {
  final String? bio;
  final String? tagline;
  final String? type;
  final String? origin;
  final String? begin;
  final String? end;
  final List<String> genres;
  final String? imageUrl;
  final String? wikipediaUrl;
  final String? musicBrainzUrl;

  const ArtistAbout({
    this.bio,
    this.tagline,
    this.type,
    this.origin,
    this.begin,
    this.end,
    this.genres = const [],
    this.imageUrl,
    this.wikipediaUrl,
    this.musicBrainzUrl,
  });

  factory ArtistAbout.fromJson(Map<String, dynamic> json) => ArtistAbout(
    bio: json['bio'] as String?,
    tagline: json['tagline'] as String?,
    type: json['type'] as String?,
    origin: json['origin'] as String?,
    begin: json['begin'] as String?,
    end: json['end'] as String?,
    genres: (json['genres'] as List<dynamic>? ?? []).cast<String>(),
    imageUrl: json['imageUrl'] as String?,
    wikipediaUrl: json['wikipediaUrl'] as String?,
    musicBrainzUrl: json['musicBrainzUrl'] as String?,
  );

  String get beginLabel => switch (type) {
    'Person' || 'Character' => 'Born',
    'Group' || 'Orchestra' || 'Choir' => 'Formed',
    _ => 'Active since',
  };

  String get endLabel => switch (type) {
    'Person' || 'Character' => 'Died',
    'Group' || 'Orchestra' || 'Choir' => 'Disbanded',
    _ => 'Active until',
  };

  bool get isEmpty =>
      bio == null &&
      tagline == null &&
      origin == null &&
      begin == null &&
      genres.isEmpty;

  Map<String, dynamic> toJson() => {
    'bio': bio,
    'tagline': tagline,
    'type': type,
    'origin': origin,
    'begin': begin,
    'end': end,
    'genres': genres,
    'imageUrl': imageUrl,
    'wikipediaUrl': wikipediaUrl,
    'musicBrainzUrl': musicBrainzUrl,
  };
}

class ArtistAboutService {
  static const _headers = {
    'User-Agent': 'Cosmodrome/1.0 (cosmodrome-app)',
    'Accept': 'application/json',
  };
  static const _timeout = Duration(seconds: 8);
  static const _musicBrainzGap = Duration(milliseconds: 1100);
  static final _musical = RegExp(
    r'\b(band|musician|singer|rapper|songwriter|composer|producer|dj|duo|trio|group|orchestra|vocalist|guitarist|pianist|drummer|music|musical)\b',
    caseSensitive: false,
  );

  final _memory = <String, ArtistAbout>{};
  final _pending = <String, Future<ArtistAbout?>>{};
  Future<void> _musicBrainzQueue = Future.value();
  DateTime _lastMusicBrainzCall = DateTime.fromMillisecondsSinceEpoch(0);

  Future<ArtistAbout?> load(
    String accountId, {
    required String artistId,
    required String name,
    String? musicBrainzId,
  }) {
    final key = '$accountId:$artistId';
    final known = _memory[key];
    if (known != null) return Future.value(known);
    return _pending[key] ??=
        _load(key, accountId, artistId, name, musicBrainzId).whenComplete(() {
          _pending.remove(key);
        });
  }

  ArtistAbout _build(Map<String, dynamic>? artist, Map<String, dynamic>? wiki) {
    final span = artist?['life-span'];
    final area = _name(artist?['area']);
    final beginArea = _name(artist?['begin-area']);
    final mbid = artist?['id'] as String?;
    final desktop = (wiki?['content_urls'] as Map?)?['desktop'];

    return ArtistAbout(
      bio: _text(wiki?['extract']),
      tagline: _text(wiki?['description']) ?? _text(artist?['disambiguation']),
      type: _text(artist?['type']),
      origin: _text({?beginArea, ?area}.join(', ')),
      begin: span is Map ? _year(span['begin']) : null,
      end: span is Map ? _year(span['end']) : null,
      genres: _genres(artist),
      imageUrl: _text((wiki?['thumbnail'] as Map?)?['source']),
      wikipediaUrl: desktop is Map ? _text(desktop['page']) : null,
      musicBrainzUrl: mbid != null
          ? 'https://musicbrainz.org/artist/$mbid'
          : null,
    );
  }

  Future<ArtistAbout?> _fetch(String name, String? musicBrainzId) async {
    try {
      Map<String, dynamic>? artist;
      if (musicBrainzId != null && musicBrainzId.isNotEmpty) {
        artist = await _lookupArtist(musicBrainzId);
      }
      if (artist == null) {
        final match = await _searchArtist(name);
        final id = match?['id'] as String?;
        if (id != null) artist = await _lookupArtist(id) ?? match;
      }

      final title = artist != null ? await _wikipediaTitle(artist) : null;
      var wiki = title != null ? await _wikipediaSummary(title) : null;
      if (wiki == null) {
        final guess = await _wikipediaSummary(name);
        final about =
            '${guess?['description'] ?? ''} ${guess?['extract'] ?? ''}';
        if (guess != null && _musical.hasMatch(about)) wiki = guess;
      }

      if (artist == null && wiki == null) return null;
      return _build(artist, wiki);
    } catch (e) {
      loggerPrint("Error fetching artist about for '$name': $e");
      return null;
    }
  }

  List<String> _genres(Map<String, dynamic>? artist) {
    final raw = artist?['genres'] ?? artist?['tags'];
    if (raw is! List) return const [];
    final entries =
        raw
            .whereType<Map<String, dynamic>>()
            .where((g) => g['name'] is String && (g['count'] as num? ?? 0) > 0)
            .toList()
          ..sort((a, b) => (b['count'] as num).compareTo(a['count'] as num));
    return entries.take(4).map((g) => _titleCase(g['name'] as String)).toList();
  }

  Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    try {
      final response = await http.get(uri, headers: _headers).timeout(_timeout);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      return body is Map<String, dynamic> ? body : null;
    } catch (_) {
      return null;
    }
  }

  Future<ArtistAbout?> _load(
    String key,
    String accountId,
    String artistId,
    String name,
    String? musicBrainzId,
  ) async {
    final stored = await offlineCacheService.loadArtistAbout(
      accountId,
      artistId,
    );
    if (stored != null) {
      try {
        return _memory[key] = ArtistAbout.fromJson(stored);
      } catch (_) {}
    }

    final about = await _fetch(name, musicBrainzId);
    if (about == null || about.isEmpty) return about;
    _memory[key] = about;
    unawaited(
      offlineCacheService.saveArtistAbout(accountId, artistId, about.toJson()),
    );
    return about;
  }

  Future<Map<String, dynamic>?> _lookupArtist(String musicBrainzId) =>
      _musicBrainz('artist/$musicBrainzId', {'inc': 'url-rels+genres'});

  Future<Map<String, dynamic>?> _musicBrainz(
    String path,
    Map<String, String> params,
  ) {
    final run = _musicBrainzQueue.then((_) async {
      final wait =
          _musicBrainzGap - DateTime.now().difference(_lastMusicBrainzCall);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      try {
        return await _getJson(
          Uri.https('musicbrainz.org', '/ws/2/$path', {
            ...params,
            'fmt': 'json',
          }),
        );
      } finally {
        _lastMusicBrainzCall = DateTime.now();
      }
    });
    _musicBrainzQueue = run.then((_) {}, onError: (_) {});
    return run;
  }

  String? _name(Object? value) => value is Map ? _text(value['name']) : null;

  Future<Map<String, dynamic>?> _searchArtist(String name) async {
    final quoted = name.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    final result = await _musicBrainz('artist', {
      'query': 'artist:"$quoted" OR alias:"$quoted"',
      'limit': '5',
    });
    final artists = result?['artists'];
    if (artists is! List) return null;

    final wanted = name.trim().toLowerCase();
    bool same(Object? value) =>
        value is String && value.trim().toLowerCase() == wanted;

    for (final artist in artists.whereType<Map<String, dynamic>>()) {
      if ((artist['score'] as num? ?? 0) < 90) continue;
      final aliases = artist['aliases'];
      final known =
          same(artist['name']) ||
          (aliases is List && aliases.any((a) => a is Map && same(a['name'])));
      if (known) return artist;
    }
    return null;
  }

  String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  String _titleCase(String value) => value
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  Future<Map<String, dynamic>?> _wikipediaSummary(String title) async {
    final page = Uri.encodeComponent(title.trim().replaceAll(' ', '_'));
    if (page.isEmpty) return null;
    final summary = await _getJson(
      Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$page'),
    );
    return summary?['type'] == 'standard' ? summary : null;
  }

  Future<String?> _wikipediaTitle(Map<String, dynamic> artist) async {
    final relations = artist['relations'];
    if (relations is! List) return null;

    Uri? link(String type) {
      for (final relation in relations) {
        if (relation is! Map || relation['type'] != type) continue;
        final url = relation['url'];
        final resource = url is Map ? url['resource'] : null;
        if (resource is String) return Uri.tryParse(resource);
      }
      return null;
    }

    final wikipedia = link('wikipedia');
    if (wikipedia != null &&
        wikipedia.host == 'en.wikipedia.org' &&
        wikipedia.pathSegments.length > 1) {
      return wikipedia.pathSegments.last;
    }

    final wikidata = link('wikidata');
    if (wikidata == null || wikidata.pathSegments.isEmpty) return null;
    final entity = wikidata.pathSegments.last;
    final data = await _getJson(
      Uri.https('www.wikidata.org', '/w/api.php', {
        'action': 'wbgetentities',
        'ids': entity,
        'props': 'sitelinks',
        'sitefilter': 'enwiki',
        'format': 'json',
        'origin': '*',
      }),
    );
    final entities = data?['entities'];
    final item = entities is Map ? entities[entity] : null;
    final sitelinks = item is Map ? item['sitelinks'] : null;
    final enwiki = sitelinks is Map ? sitelinks['enwiki'] : null;
    return enwiki is Map ? _text(enwiki['title']) : null;
  }

  String? _year(Object? value) =>
      value is String && value.length >= 4 ? value.substring(0, 4) : null;
}
