class Category {
  final int? id;
  final String name;
  /// 'income' | 'expense'
  final String type;
  /// id de la categoría padre (para subcategorías)
  final int? parentId;

  const Category({
    this.id,
    required this.name,
    required this.type,
    this.parentId,
  });

  factory Category.fromMap(Map<String, dynamic> m) => Category(
    id: m['id'] as int?,
    name: m['name'] as String,
    type: m['type'] as String,
    parentId: m['parent_id'] as int?,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'type': type,
    'parent_id': parentId,
  };

  Category copyWith({
    int? id,
    String? name,
    String? type,
    int? parentId,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
    );
  }
}
