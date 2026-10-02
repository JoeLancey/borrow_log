import '../../../models/equipment_asset.dart';
import '../../../models/reservation.dart';
import '../../../models/reservation_asset.dart';
import '../../../models/reservation_item.dart';

abstract interface class ReservationRepository {
  Future<List<Reservation>> fetchMyReservations();

  Future<List<Reservation>> fetchAllReservations();

  Future<Reservation?> fetchReservationById(String id);

  Future<List<ReservationItem>> fetchReservationItems(String reservationId);

  Future<List<ReservationAsset>> fetchReservationAssets(String reservationId);

  Future<List<EquipmentAsset>> fetchAssignedAssets(String reservationId);

  Future<Map<String, String>> fetchReturnConditions(String reservationId);

  Future<List<Reservation>> searchReservations({
    String? text,
    String? status,
    DateTime? useDateFrom,
    DateTime? useDateTo,
  });

  Future<List<Reservation>> searchByPropertyNumber(String propertyNumber);

  Future<void> createReservation({
    required List<ReservationItem> items,
    required String subject,
    String? subjectCode,
    required String instructor,
    required DateTime useDate,
    String? useTime,
    String? notes,
    String? laboratoryId,
  });

  Future<void> cancelReservation(String id);

  Future<void> approveReservation({
    required String reservationId,
    required List<String> assetIds,
  });

  Future<void> rejectReservation({
    required String reservationId,
    required String reason,
  });

  Future<void> releaseReservation({
    required String reservationId,
    required DateTime dueDate,
  });

  Future<void> recordAssetReturn({
    required String reservationAssetId,
    required String equipmentAssetId,
    required String condition,
    String? notes,
  });

  Future<void> completeReservation(String reservationId);
}
