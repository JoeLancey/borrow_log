class ReservationAssetReturn {
  final String id;
  final String reservationAssetId;
  final String condition; // good | damaged | lost
  final String? notes;
  final String? recordedBy;
  final DateTime? recordedAt;

  ReservationAssetReturn({
    required this.id,
    required this.reservationAssetId,
    required this.condition,
    this.notes,
    this.recordedBy,
    this.recordedAt,
  });

  factory ReservationAssetReturn.fromMap(Map<String, dynamic> map) {
    return ReservationAssetReturn(
      id: map['id'] as String,
      reservationAssetId: map['reservation_asset_id'] as String,
      condition: map['condition'] as String,
      notes: map['notes'] as String?,
      recordedBy: map['recorded_by'] as String?,
      recordedAt: map['recorded_at'] != null
          ? DateTime.tryParse(map['recorded_at'].toString())
          : null,
    );
  }
}