class MusicFolder {
  String id;
  String name;

  MusicFolder({required this.id, required this.name});

  factory MusicFolder.fromJson(Map<String, dynamic> json) {
    return MusicFolder(id: json['id'] as String, name: json['name'] as String);
  }
}
