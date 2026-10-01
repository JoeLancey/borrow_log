class EquipmentAsset {
  final String id;
  final String equipmentTypeId;
  final String propertyNumber;
  final String status;
  final String? conditionNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EquipmentAsset({
    required this.id,
    required this.equipmentTypeId,
    required this.propertyNumber,
    required this.status,
    this.conditionNotes,
    this.createdAt,
    this.updatedAt,
  });

  factory EquipmentAsset.fromMap(Map<String, dynamic> map) {
    return EquipmentAsset(
      id: map['id'] as String,
      equipmentTypeId: map['equipment_type_id'] as String,
      propertyNumber: map['property_number'] as String,
      status: map['status'] as String,
      conditionNotes: map['condition_notes'] as String?,
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
      'equipment_type_id': equipmentTypeId,
      'property_number': propertyNumber,
      'status': status,
      'condition_notes': conditionNotes,
    };
  }

  /// Human-friendly status label.
  String get statusLabel {
    switch (status) {
      case 'available':
        return 'Available';
      case 'reserved':
        return 'Reserved';
      case 'borrowed':
        return 'Borrowed';
      case 'damaged':
        return 'Damaged';
      case 'lost':
        return 'Lost';
      case 'maintenance':
        return 'Maintenance';
      default:
        return status;
    }
  }
}