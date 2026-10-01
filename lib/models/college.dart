class College {
  final String id;
  final String code;
  final String name;
  final DateTime? createdAt;

  College({
    required this.id,
    required this.code,
    required this.name,
    this.createdAt,
  });

  factory College.fromMap(Map<String, dynamic> map) {
    return College(
      id: map['id'] as String,
      code: map['code'] as String,
      name: map['name'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }
}