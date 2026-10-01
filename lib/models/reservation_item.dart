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

  factory ReservationItem.fromMap(Map<String, dynamic> map) {
    final type = map['equipment_types'];
    return ReservationItem(
      id: map['id'] as String,
      reservationId: map['reservation_id'] as String,
      equipmentTypeId: map['equipment_type_id'] as String,
      quantityRequested: map['quantity_requested'] as int,
      equipmentTypeName:
          type is Map ? type['name'] as String? : null,
    );
  }
}