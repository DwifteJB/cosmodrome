part of '../master_subsonic.dart';

class _LocalPlaylist {
  final String id;
  String name;
  String? comment;
  final DateTime created;
  DateTime changed;
  final List<String> songs;

  _LocalPlaylist({
    required this.id,
    required this.name,
    required this.created,
    required this.changed,
    required List<String> songs,
    this.comment,
  }) : songs = [...songs];

  factory _LocalPlaylist.fromJson(Map<String, dynamic> json) {
    final created =
        DateTime.tryParse(json['created'] as String? ?? '') ?? DateTime.now();
    return _LocalPlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      comment: json['comment'] as String?,
      created: created,
      changed: DateTime.tryParse(json['changed'] as String? ?? '') ?? created,
      songs: [for (final id in json['songs'] as List<dynamic>? ?? []) '$id'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'comment': ?comment,
    'created': created.toIso8601String(),
    'changed': changed.toIso8601String(),
    'songs': songs,
  };
}
