class PlaylistModel {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final int itemCount;

  PlaylistModel({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    this.itemCount = 0,
  });

  factory PlaylistModel.fromMap(Map<String, dynamic> map, {int itemCount = 0}) {
    return PlaylistModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      itemCount: (map['item_count'] as int?) ?? itemCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
