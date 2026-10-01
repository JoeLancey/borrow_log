import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reservation.dart';
import '../models/reservation_asset.dart';
import '../models/reservation_item.dart';
import '../models/equipment_asset.dart';
import 'email_service.dart';
import 'notification_service.dart';

class ReservationService {
  final SupabaseClient _client = Supabase.instance.client;

  static const _joinedSelect =
      '*, equipment_types(name), laboratories(name), profiles!reservations_student_id_fkey(full_name)';

  // ---------------------------------------------------------
  // READS
  // ---------------------------------------------------------

  Future<List<Reservation>> fetchMyReservations() async {
    final uid = _client.auth.currentUser!.id;
    final data = await _client
        .from('reservations')
        .select(_joinedSelect)
        .eq('student_id', uid)
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => Reservation.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<Reservation>> fetchAllReservations() async {
    final data = await _client
        .from('reservations')
        .select(_joinedSelect)
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => Reservation.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<Reservation?> fetchReservationById(String id) async {
    final data = await _client
        .from('reservations')
        .select(_joinedSelect)
        .eq('id', id)
        .maybeSingle();

    if (data == null) return null;
    return Reservation.fromMap(data);
  }

  /// Items (equipment types + quantities) for a reservation.
  Future<List<ReservationItem>> fetchReservationItems(
      String reservationId) async {
    final data = await _client
        .from('reservation_items')
        .select('*, equipment_types(name)')
        .eq('reservation_id', reservationId);

    return (data as List)
        .map((row) => ReservationItem.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<ReservationAsset>> fetchReservationAssets(
      String reservationId) async {
    final data = await _client
        .from('reservation_assets')
        .select('*, equipment_assets(*)')
        .eq('reservation_id', reservationId);

    return (data as List)
        .map((row) => ReservationAsset.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<EquipmentAsset>> fetchAssignedAssets(
      String reservationId) async {
    final links = await fetchReservationAssets(reservationId);
    return links.map((l) => l.asset).whereType<EquipmentAsset>().toList();
  }

  Future<Map<String, String>> fetchReturnConditions(
      String reservationId) async {
    final links = await fetchReservationAssets(reservationId);
    if (links.isEmpty) return {};

    final linkIds = links.map((l) => l.id).toList();

    final data = await _client
        .from('reservation_asset_returns')
        .select('reservation_asset_id, condition')
        .inFilter('reservation_asset_id', linkIds);

    final map = <String, String>{};
    for (final row in (data as List)) {
      map[row['reservation_asset_id'] as String] = row['condition'] as String;
    }
    return map;
  }

  // ---------------------------------------------------------
  // SEARCH
  // ---------------------------------------------------------

  Future<List<Reservation>> searchReservations({
    String? text,
    String? status,
    DateTime? useDateFrom,
    DateTime? useDateTo,
  }) async {
    var query = _client.from('reservations').select(_joinedSelect);

    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }
    if (useDateFrom != null) {
      query = query.gte(
          'use_date', useDateFrom.toIso8601String().split('T').first);
    }
    if (useDateTo != null) {
      query = query.lte(
          'use_date', useDateTo.toIso8601String().split('T').first);
    }

    final data = await query.order('created_at', ascending: false);
    var results = (data as List)
        .map((row) => Reservation.fromMap(row as Map<String, dynamic>))
        .toList();

    if (text != null && text.trim().isNotEmpty) {
      final q = text.trim().toLowerCase();
      results = results.where((r) {
        if (r.studentName?.toLowerCase().contains(q) ?? false) return true;
        if (r.subject.toLowerCase().contains(q)) return true;
        if ((r.subjectCode ?? '').toLowerCase().contains(q)) return true;
        if (r.instructor.toLowerCase().contains(q)) return true;
        return false;
      }).toList();
    }

    return results;
  }

  Future<List<Reservation>> searchByPropertyNumber(
      String propertyNumber) async {
    final pn = propertyNumber.trim().toUpperCase();
    if (pn.isEmpty) return [];

    final assetRow = await _client
        .from('equipment_assets')
        .select('id')
        .eq('property_number', pn)
        .maybeSingle();

    if (assetRow == null) return [];
    final assetId = assetRow['id'] as String;

    final links = await _client
        .from('reservation_assets')
        .select('reservation_id')
        .eq('equipment_asset_id', assetId);

    final reservationIds = (links as List)
        .map((r) => r['reservation_id'] as String)
        .toSet()
        .toList();

    if (reservationIds.isEmpty) return [];

    final data = await _client
        .from('reservations')
        .select(_joinedSelect)
        .inFilter('id', reservationIds)
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => Reservation.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------
  // STUDENT WRITES
  // ---------------------------------------------------------

  /// Create a reservation with one or more equipment items.
  ///
  /// The first item is also written to the legacy
  /// `reservations.equipment_type_id` and `reservations.quantity_requested`
  /// columns (both NOT NULL) so existing screens keep working.
  Future<void> createReservation({
    required List<ReservationItem> items,
    required String subject,
    String? subjectCode,
    required String instructor,
    required DateTime useDate,
    String? useTime,
    String? notes,
    String? laboratoryId,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('At least one equipment item is required.');
    }

    final uid = _client.auth.currentUser!.id;
    final first = items.first;

    // 1. Insert reservation header
    final inserted = await _client
        .from('reservations')
        .insert({
          'student_id': uid,
          'equipment_type_id': first.equipmentTypeId,
          'laboratory_id': laboratoryId,
          'quantity_requested': first.quantityRequested,
          'subject': subject,
          'subject_code': subjectCode,
          'instructor': instructor,
          'use_date': useDate.toIso8601String().split('T').first,
          'use_time': useTime,
          'notes': notes,
          'status': 'pending',
        })
        .select('id')
        .single();

    final reservationId = inserted['id'] as String;

    // 2. Insert all items
    await _client.from('reservation_items').insert(
          items
              .map((item) => {
                    'reservation_id': reservationId,
                    'equipment_type_id': item.equipmentTypeId,
                    'quantity_requested': item.quantityRequested,
                  })
              .toList(),
        );
  }

  Future<void> cancelReservation(String id) async {
    await _client.from('reservations').update({
      'status': 'cancelled',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ---------------------------------------------------------
  // STAFF WRITES
  // ---------------------------------------------------------

  Future<void> approveReservation({
    required String reservationId,
    required List<String> assetIds,
  }) async {
    final uid = _client.auth.currentUser!.id;

    if (assetIds.isNotEmpty) {
      await _client.from('reservation_assets').insert(
            assetIds
                .map((assetId) => {
                      'reservation_id': reservationId,
                      'equipment_asset_id': assetId,
                    })
                .toList(),
          );
    }

    for (final id in assetIds) {
      await _client.from('equipment_assets').update({
        'status': 'reserved',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    }

    await _client.from('reservations').update({
      'status': 'approved',
      'reviewed_by': uid,
      'reviewed_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', reservationId);

    // Notify + email (best-effort)
    try {
      final row = await _client
          .from('reservations')
          .select(
              'student_id, profiles!reservations_student_id_fkey(email, full_name), equipment_types(name)')
          .eq('id', reservationId)
          .maybeSingle();

      if (row != null) {
        final studentId = row['student_id'] as String;
        final typeName =
            (row['equipment_types'] as Map?)?['name']?.toString() ??
                'laboratory equipment';
        final email = (row['profiles'] as Map?)?['email']?.toString();
        final name =
            (row['profiles'] as Map?)?['full_name']?.toString() ?? 'Student';

        await NotificationService().insertNotification(
          userId: studentId,
          title: 'Reservation approved',
          body:
              'Your reservation for $typeName has been approved. Please wait for the equipment to be released.',
          kind: 'reservation_approved',
          reservationId: reservationId,
        );

        if (email != null) {
          final emailSvc = EmailService();
          await emailSvc.sendEmail(
            to: email,
            subject: 'BORROW LOG: Reservation approved',
            html: emailSvc.wrapHtml(
              title: 'Reservation approved',
              bodyHtml: '''
                <p>Hi $name,</p>
                <p>Your reservation for <strong>$typeName</strong> has been approved.</p>
                <p>Please wait for the laboratory staff to release the equipment to you.</p>
              ''',
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> rejectReservation({
    required String reservationId,
    required String reason,
  }) async {
    final uid = _client.auth.currentUser!.id;

    await _client.from('reservations').update({
      'status': 'rejected',
      'rejection_reason': reason,
      'reviewed_by': uid,
      'reviewed_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', reservationId);

    try {
      final row = await _client
          .from('reservations')
          .select(
              'student_id, profiles!reservations_student_id_fkey(email, full_name), equipment_types(name)')
          .eq('id', reservationId)
          .maybeSingle();

      if (row != null) {
        final studentId = row['student_id'] as String;
        final typeName =
            (row['equipment_types'] as Map?)?['name']?.toString() ??
                'laboratory equipment';
        final email = (row['profiles'] as Map?)?['email']?.toString();
        final name =
            (row['profiles'] as Map?)?['full_name']?.toString() ?? 'Student';

        await NotificationService().insertNotification(
          userId: studentId,
          title: 'Reservation rejected',
          body: reason.isEmpty ? null : 'Reason: $reason',
          kind: 'reservation_rejected',
          reservationId: reservationId,
        );

        if (email != null) {
          final emailSvc = EmailService();
          await emailSvc.sendEmail(
            to: email,
            subject: 'BORROW LOG: Reservation rejected',
            html: emailSvc.wrapHtml(
              title: 'Reservation rejected',
              bodyHtml: '''
                <p>Hi $name,</p>
                <p>Your reservation for <strong>$typeName</strong> was not approved.</p>
                ${reason.isEmpty ? '' : '<p><strong>Reason:</strong> $reason</p>'}
              ''',
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> releaseReservation({
    required String reservationId,
    required DateTime dueDate,
  }) async {
    final now = DateTime.now().toIso8601String();

    final links = await fetchReservationAssets(reservationId);
    for (final link in links) {
      await _client.from('equipment_assets').update({
        'status': 'borrowed',
        'updated_at': now,
      }).eq('id', link.equipmentAssetId);
    }

    await _client.from('reservations').update({
      'status': 'borrowed',
      'released_at': now,
      'due_date': dueDate.toIso8601String().split('T').first,
      'updated_at': now,
    }).eq('id', reservationId);

    try {
      final row = await _client
          .from('reservations')
          .select(
              'student_id, profiles!reservations_student_id_fkey(email, full_name), equipment_types(name)')
          .eq('id', reservationId)
          .maybeSingle();

      if (row != null) {
        final studentId = row['student_id'] as String;
        final typeName =
            (row['equipment_types'] as Map?)?['name']?.toString() ??
                'laboratory equipment';
        final email = (row['profiles'] as Map?)?['email']?.toString();
        final name =
            (row['profiles'] as Map?)?['full_name']?.toString() ?? 'Student';

        final due = dueDate.toIso8601String().split('T').first;

        await NotificationService().insertNotification(
          userId: studentId,
          title: 'Equipment released',
          body:
              'Your equipment is now in your possession. Please return it by $due.',
          kind: 'equipment_released',
          reservationId: reservationId,
        );

        if (email != null) {
          final emailSvc = EmailService();
          await emailSvc.sendEmail(
            to: email,
            subject: 'BORROW LOG: Equipment released',
            html: emailSvc.wrapHtml(
              title: 'Equipment released',
              bodyHtml: '''
                <p>Hi $name,</p>
                <p>Your reserved <strong>$typeName</strong> has been released to you.</p>
                <p><strong>Please return it by $due.</strong></p>
                <p>You can view the full details in the app under "My Reservations".</p>
              ''',
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> recordAssetReturn({
    required String reservationAssetId,
    required String equipmentAssetId,
    required String condition,
    String? notes,
  }) async {
    final uid = _client.auth.currentUser!.id;
    final now = DateTime.now().toIso8601String();

    await _client.from('reservation_asset_returns').upsert({
      'reservation_asset_id': reservationAssetId,
      'condition': condition,
      'notes': notes,
      'recorded_by': uid,
      'recorded_at': now,
    });

    final newStatus = condition == 'good' ? 'available' : 'maintenance';
    await _client.from('equipment_assets').update({
      'status': newStatus,
      'updated_at': now,
    }).eq('id', equipmentAssetId);
  }

  Future<void> completeReservation(String reservationId) async {
    final now = DateTime.now().toIso8601String();
    await _client.from('reservations').update({
      'status': 'completed',
      'returned_at': now,
      'updated_at': now,
    }).eq('id', reservationId);

    try {
      final row = await _client
          .from('reservations')
          .select(
              'student_id, profiles!reservations_student_id_fkey(email, full_name), equipment_types(name)')
          .eq('id', reservationId)
          .maybeSingle();

      if (row != null) {
        final studentId = row['student_id'] as String;
        final typeName =
            (row['equipment_types'] as Map?)?['name']?.toString() ??
                'laboratory equipment';
        final email = (row['profiles'] as Map?)?['email']?.toString();
        final name =
            (row['profiles'] as Map?)?['full_name']?.toString() ?? 'Student';

        await NotificationService().insertNotification(
          userId: studentId,
          title: 'Return recorded',
          body: 'Thank you. Your reservation has been completed.',
          kind: 'return_recorded',
          reservationId: reservationId,
        );

        if (email != null) {
          final emailSvc = EmailService();
          await emailSvc.sendEmail(
            to: email,
            subject: 'BORROW LOG: Return recorded',
            html: emailSvc.wrapHtml(
              title: 'Return recorded',
              bodyHtml: '''
                <p>Hi $name,</p>
                <p>Thank you for returning the <strong>$typeName</strong>.</p>
                <p>Your reservation is now marked as <strong>completed</strong>.</p>
              ''',
            ),
          );
        }
      }
    } catch (_) {}
  }
}