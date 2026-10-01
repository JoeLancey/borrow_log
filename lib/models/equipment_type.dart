class EquipmentType {
  final String id;
  final String name;
  final String? description;
  final String? category;
  final String? laboratoryId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EquipmentType({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.laboratoryId,
    this.createdAt,
    this.updatedAt,
  });

  factory EquipmentType.fromMap(Map<String, dynamic> map) {
    return EquipmentType(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      category: map['category'] as String?,
      laboratoryId: map['laboratory_id'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'laboratory_id': laboratoryId,
    };
  }
}