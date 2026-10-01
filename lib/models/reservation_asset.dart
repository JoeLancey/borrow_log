import 'equipment_asset.dart';

class ReservationAsset {
  final String id;
  final String reservationId;
  final String equipmentAssetId;
  final EquipmentAsset? asset;

  ReservationAsset({
    required this.id,
    required this.reservationId,
    required this.equipmentAssetId,
    this.asset,
  });

  factory ReservationAsset.fromMap(Map<String, dynamic> map) {
    final joined = map['equipment_assets'];
    return ReservationAsset(
      id: map['id'] as String,
      reservationId: map['reservation_id'] as String,
      equipmentAssetId: map['equipment_asset_id'] as String,
      asset: joined is Map<String, dynamic>
          ? EquipmentAsset.fromMap(joined)
          : null,
    );
  }
}