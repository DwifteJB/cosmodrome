// TYPES FOR LYRICS-RELATED (OPENSUBSONIC) API RESPONSES
//
// https://opensubsonic.netlify.app/docs/endpoints/getlyricsbysongid/
// https://opensubsonic.netlify.app/docs/responses/structuredlyrics/

/// The primary lyric-layer classification of a [StructuredLyrics] entry.
enum LyricsKind {
  /// primary vocals 
  main,

  /// translation
  translation,

  /// phonetic / romanised 
  pronunciation;

  static LyricsKind fromString(String? raw) {
    switch (raw) {
      case 'translation':
        return LyricsKind.translation;
      case 'pronunciation':
        return LyricsKind.pronunciation;
      default:
        return LyricsKind.main;
    }
  }
}

class LyricLine {
  final int? start;
  final String value;

  const LyricLine({this.start, required this.value});

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
    start: (json['start'] as num?)?.toInt(),
    value: json['value'] as String? ?? '',
  );
}

// single word
class LyricCue {
  final int start;
  final int? end;
  final String value;
  final int byteStart;
  final int byteEnd;

  const LyricCue({
    required this.start,
    this.end,
    required this.value,
    required this.byteStart,
    required this.byteEnd,
  });

  factory LyricCue.fromJson(Map<String, dynamic> json) => LyricCue(
    start: (json['start'] as num?)?.toInt() ?? 0,
    end: (json['end'] as num?)?.toInt(),
    value: json['value'] as String? ?? '',
    byteStart: (json['byteStart'] as num?)?.toInt() ?? 0,
    byteEnd: (json['byteEnd'] as num?)?.toInt() ?? 0,
  );
}

// word level cue time
class LyricCueLine {
  final int index;
  final String? agentId;
  final int start;
  final int? end;
  final String value;
  final List<LyricCue> cues;

  const LyricCueLine({
    required this.index,
    this.agentId,
    required this.start,
    this.end,
    required this.value,
    required this.cues,
  });

  factory LyricCueLine.fromJson(Map<String, dynamic> json) => LyricCueLine(
    index: (json['index'] as num?)?.toInt() ?? 0,
    agentId: json['agentId'] as String?,
    start: (json['start'] as num?)?.toInt() ?? 0,
    end: (json['end'] as num?)?.toInt(),
    value: json['value'] as String? ?? '',
    cues: (json['cue'] as List<dynamic>? ?? [])
        .map((c) => LyricCue.fromJson(c as Map<String, dynamic>))
        .toList(),
  );
}

// attribute of a lyric line, e.g. "main vocals", "backing vocals", "group vocals"
class LyricAgent {
  final String id;
  final String role; // main | voice | bg | group
  final String? name;

  const LyricAgent({required this.id, required this.role, this.name});

  factory LyricAgent.fromJson(Map<String, dynamic> json) => LyricAgent(
    id: json['id'] as String? ?? '',
    role: json['role'] as String? ?? 'main',
    name: json['name'] as String?,
  );
}

// the meat of what we want!!
class StructuredLyrics {
  final LyricsKind kind;
  final String lang;
  final bool synced;

  final int offset;
  final String? displayArtist;
  final String? displayTitle;
  final List<LyricLine> lines;
  final List<LyricCueLine> cueLines;
  final List<LyricAgent> agents;

  const StructuredLyrics({
    required this.kind,
    required this.lang,
    required this.synced,
    this.offset = 0,
    this.displayArtist,
    this.displayTitle,
    required this.lines,
    this.cueLines = const [],
    this.agents = const [],
  });

  /// `xxx` and `und` both mean "unknown language"
  bool get hasKnownLanguage =>
      lang.isNotEmpty && lang != 'xxx' && lang != 'und';

  bool get hasCues => cueLines.isNotEmpty;

  factory StructuredLyrics.fromJson(Map<String, dynamic> json) {
    return StructuredLyrics(
      kind: LyricsKind.fromString(json['kind'] as String?),
      lang: json['lang'] as String? ?? 'und',
      synced: json['synced'] as bool? ?? false,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      displayArtist: json['displayArtist'] as String?,
      displayTitle: json['displayTitle'] as String?,
      lines: (json['line'] as List<dynamic>? ?? [])
          .map((l) => LyricLine.fromJson(l as Map<String, dynamic>))
          .toList(),
      cueLines: (json['cueLine'] as List<dynamic>? ?? [])
          .map((c) => LyricCueLine.fromJson(c as Map<String, dynamic>))
          .toList(),
      agents: (json['agents'] as List<dynamic>? ?? [])
          .map((a) => LyricAgent.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }

  // build from text
  factory StructuredLyrics.fromPlainText(
    String text, {
    String? artist,
    String? title,
  }) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => LyricLine(value: l))
        .toList();
    return StructuredLyrics(
      kind: LyricsKind.main,
      lang: 'und',
      synced: false,
      displayArtist: artist,
      displayTitle: title,
      lines: lines,
    );
  }
}

// to see if we can use any of the OpenSubsonic extensions for lyrics
class OpenSubsonicExtension {
  final String name;
  final List<int> versions;

  const OpenSubsonicExtension({required this.name, required this.versions});

  factory OpenSubsonicExtension.fromJson(Map<String, dynamic> json) =>
      OpenSubsonicExtension(
        name: json['name'] as String? ?? '',
        versions: (json['versions'] as List<dynamic>? ?? [])
            .map((v) => (v as num).toInt())
            .toList(),
      );

  int get maxVersion =>
      versions.isEmpty ? 0 : versions.reduce((a, b) => a > b ? a : b);
}
