// lib/models/account_group.dart
class AccountGroup {
  final int? id;
  final String name;
  final int sortOrder;
  final String? color;
  final int collapsed; // 0 o 1

  const AccountGroup({
    this.id,
    required this.name,
    this.sortOrder = 0,
    this.color,
    this.collapsed = 0,
  });

  factory AccountGroup.fromMap(Map<String, dynamic> map) => AccountGroup(
    id: map['id'] as int?,
    name: (map['name'] ?? '') as String,
    sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    color: map['color'] as String?,
    collapsed: (map['collapsed'] as int?) ?? 0,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'sort_order': sortOrder,
    'color': color,
    'collapsed': collapsed,
  };

  AccountGroup copyWith({
    int? id,
    String? name,
    int? sortOrder,
    String? color,
    int? collapsed,
  }) => AccountGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    color: color ?? this.color,
    collapsed: collapsed ?? this.collapsed,
  );
}
