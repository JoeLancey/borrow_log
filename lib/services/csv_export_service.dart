import 'package:csv/csv.dart';

import '../models/equipment_asset.dart';
import '../models/reservation.dart';
import '../models/reservation_asset.dart';

class CsvExportService {
  /// Builds a CSV string from a list of reservations.
  /// [assetsByReservation] maps reservationId -> assigned Property Numbers.
  /// [conditionsByReservation] maps reservationId -> {reservation_asset_id: condition}.
  String buildReservationsCsv({
    required List<Reservation> reservations,
    required Map<String, List<ReservationAsset>> assetsByReservation,
    required Map<String, Map<String, String>> conditionsByReservation,
  }) {
    final rows = <List<dynamic>>[
      [
        'Slip ID',
        'Student',
        'Equipment Type',
        'Qty',
        'Subject',
        'Subject Code',
        'Instructor',
        'Use Date',
        'Use Time',
        'Due Date',
        'Status',
        'Released At',
        'Returned At',
        'Property Numbers',
        'Conditions',
        'Notes',
        'Rejection Reason',
      ],
    ];

    for (final r in reservations) {
      final links = assetsByReservation[r.id] ?? const <ReservationAsset>[];
      final conditions = conditionsByReservation[r.id] ?? const {};

      final propertyNumbers = links
          .map((l) => l.asset?.propertyNumber ?? l.equipmentAssetId)
          .toList();

      // Sort so conditions line up with the right Property Number
      propertyNumbers.sort();

      final conditionList = links
          .where((l) => conditions.containsKey(l.id))
          .map((l) =>
              '${l.asset?.propertyNumber ?? l.equipmentAssetId}: ${conditions[l.id]}')
          .toList()
        ..sort();

      rows.add([
        _shortId(r.id),
        r.studentName ?? r.studentId,
        r.equipmentTypeName ?? '',
        r.quantityRequested,
        r.subject,
        r.subjectCode ?? '',
        r.instructor,
        r.useDateFormatted,
        r.useTime ?? '',
        r.dueDateFormatted ?? '',
        r.isOverdue ? 'overdue' : r.status,
        _fmtDateTime(r.releasedAt),
        _fmtDateTime(r.returnedAt),
        propertyNumbers.join(' | '),
        conditionList.join(' | '),
        r.notes ?? '',
        r.rejectionReason ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Builds a CSV string of the equipment inventory.
  String buildInventoryCsv(List<EquipmentAsset> assets) {
    final rows = <List<dynamic>>[
      [
        'Property Number',
        'Status',
        'Condition Notes',
        'Created At',
        'Updated At',
      ],
    ];

    for (final a in assets) {
      rows.add([
        a.propertyNumber,
        a.status,
        a.conditionNotes ?? '',
        _fmtDateTime(a.createdAt),
        _fmtDateTime(a.updatedAt),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  String _shortId(String id) {
    if (id.length <= 8) return id.toUpperCase();
    return id.substring(0, 8).toUpperCase();
  }

  String _fmtDateTime(DateTime? dt) {
    if (dt == null) return '';
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}