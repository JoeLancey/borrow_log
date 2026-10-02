class ReservationItem {
  final String id;
  final String reservationId;
  final String equipmentTypeId;
  final int quantityRequested;

  // Joined field (optional)
  final String? equipmentTypeName;

  ReservationItem({
    required this.id,
    required this.reservationId,
    required this.equipmentTypeId,
    required this.quantityRequested,
    this.equipmentTypeName,
  });

  factory ReservationItem.fromJson(Map<String, dynamic> json) {
    final type = json['equipment_types'];
    return ReservationItem(
      id: json['id'] as String,
      reservationId: json['reservation_id'] as String,
      equipmentTypeId: json['equipment_type_id'] as String,
      quantityRequested: json['quantity_requested'] as int,
      equipmentTypeName:
          type is Map ? type['name'] as String? : null,
    );
  }

  factory ReservationItem.fromMap(Map<String, dynamic> map) =>
      ReservationItem.fromJson(map);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reservation_id': reservationId,
      'equipment_type_id': equipmentTypeId,
      'quantity_requested': quantityRequested,
    };
  }

  ReservationItem copyWith({
    String? id,
    String? reservationId,
    String? equipmentTypeId,
    int? quantityRequested,
    String? equipmentTypeName,
  }) {
    return ReservationItem(
      id: id ?? this.id,
      reservationId: reservationId ?? this.reservationId,
      equipmentTypeId: equipmentTypeId ?? this.equipmentTypeId,
      quantityRequested: quantityRequested ?? this.quantityRequested,
      equipmentTypeName: equipmentTypeName ?? this.equipmentTypeName,
    );
  }
}