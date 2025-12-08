class SongList {
  final String id;
  final String name;
  final List<String> hymnIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDefault;
  final bool isBuiltIn;

  static const int maxHymnsPerList = 120;

  SongList({
    required this.id,
    required this.name,
    required this.hymnIds,
    required this.createdAt,
    required this.updatedAt,
    this.isDefault = false,
    this.isBuiltIn = false,
  });

  // Create a copy with updated fields
  SongList copyWith({
    String? id,
    String? name,
    List<String>? hymnIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDefault,
    bool? isBuiltIn,
  }) {
    return SongList(
      id: id ?? this.id,
      name: name ?? this.name,
      hymnIds: hymnIds ?? List.from(this.hymnIds),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDefault: isDefault ?? this.isDefault,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  // Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hymnIds': hymnIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDefault': isDefault,
      'isBuiltIn': isBuiltIn,
    };
  }

  // Deserialize from JSON
  factory SongList.fromJson(Map<String, dynamic> json) {
    return SongList(
      id: json['id'] as String,
      name: json['name'] as String,
      hymnIds: (json['hymnIds'] as List<dynamic>).cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isDefault: json['isDefault'] as bool? ?? false,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  // Check if hymn is in this list
  bool containsHymn(String hymnId) {
    return hymnIds.contains(hymnId);
  }

  // Check if list is full
  bool isFull() {
    return hymnIds.length >= maxHymnsPerList;
  }

  // Get hymn count
  int get hymnCount => hymnIds.length;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SongList && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
