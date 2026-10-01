class Laboratory {
  final String id;
  final String name;
  final String building;
  final String department;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Laboratory({
    required this.id,
    required this.name,
    required this.building,
    required this.department,
    this.createdAt,
    this.updatedAt,
  });

  factory Laboratory.fromMap(Map<String, dynamic> map) {
    return Laboratory(
      id: map['id'] as String,
      name: map['name'] as String,
      building: map['building'] as String,
      department: map['department'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  /// "Microbiology Laboratory · DPT Building"
  String get displayLabel => '$name · $building';
}