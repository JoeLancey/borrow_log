import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reservation.dart';
import '../models/reservation_asset.dart';
import '../models/reservation_item.dart';
import '../models/equipment_asset.dart';
import '../features/reservations/domain/reservation_repository.dart';
import 'email_service.dart';
import 'notification_service.dart';

class ReservationService implements ReservationRepository {
  final SupabaseClient _client = Supabase.instance.client;

  static const _joinedSelect =
      '*, equipment_types(name), laboratories(name), profiles!reservations_student_id_fkey(full_name)';

  // ---------------------------------------------------------
  // READS
  // ---------------------------------------------------------

  @override
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

  @override
  Future<List<Reservation>> fetchAllReservations() async {
    final data = await _client
        .from('reservations')
        .select(_joinedSelect)
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => Reservation.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  @override
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
  @override
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

  @override
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

  @override
  Future<List<EquipmentAsset>> fetchAssignedAssets(
      String reservationId) async {
    final links = await fetchReservationAssets(reservationId);
    return links.map((l) => l.asset).whereType<EquipmentAsset>().toList();
  }

  @override
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

  @override
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

  @override
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
  @override
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

  @override
  Future<void> cancelReservation(String id) async {
    final updated = await _client
        .from('reservations')
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .eq('status', 'pending')
        .select('id');
    if ((updated as List).isEmpty) {
      throw StateError('Only pending reservations can be cancelled.');
    }
  }

  // ---------------------------------------------------------
  // STAFF WRITES
  // ---------------------------------------------------------

  @override
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
      final updated = await _client
          .from('equipment_assets')
          .update({
            'status': 'reserved',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .eq('status', 'available')
          .select('id');
      if ((updated as List).isEmpty) {
        throw StateError('One or more selected assets are no longer available.');
      }
    }

    final updated = await _client
        .from('reservations')
        .update({
          'status': 'approved',
          'reviewed_by': uid,
          'reviewed_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', reservationId)
        .eq('status', 'pending')
        .select('id');
    if ((updated as List).isEmpty) {
      throw StateError('Only pending reservations can be approved.');
    }

    // ---------------------------------------------
    // Notify + email (best-effort, with diagnostics)
    // ---------------------------------------------
    // ignore: avoid_print
    print('📧 [approveReservation] Entering notify block');
    try {
      final row = await _client
          .from('reservations')
          .select(
              'student_id, profiles!reservations_student_id_fkey(email, full_name), equipment_types(name)')
          .eq('id', reservationId)
          .maybeSingle();

      if (row == null) {
        // ignore: avoid_print
        print('📧 [approveReservation] ⚠️ row is null');
        return;
      }

      final studentId = row['student_id'] as String;
      final typeName =
          (row['equipment_types'] as Map?)?['name']?.toString() ??
              'laboratory equipment';
      final email = (row['profiles'] as Map?)?['email']?.toString();
      final name =
          (row['profiles'] as Map?)?['full_name']?.toString() ?? 'Student';

      // ignore: avoid_print
      print('📧 [approveReservation] Student: $name <$email>');

      await NotificationService().insertNotification(
        userId: studentId,
        title: 'Reservation approved',
        body:
            'Your reservation for $typeName has been approved. Please wait for the equipment to be released.',
        kind: 'reservation_approved',
        reservationId: reservationId,
      );

      if (email == null) {
        // ignore: avoid_print
        print('📧 [approveReservation] ⚠️ Email is null — skipping send');
        return;
      }

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
      // ignore: avoid_print
      print('📧 [approveReservation] ✅ sendEmail returned');
    } catch (e, stack) {
      // ignore: avoid_print
      print('📧 [approveReservation] ❌ FAILED: $e');
      // ignore: avoid_print
      print('📧 [approveReservation] STACK: $stack');
    }
  }

  @override
  Future<void> rejectReservation({
    required String reservationId,
    required String reason,
  }) async {
    final uid = _client.auth.currentUser!.id;

    final updated = await _client
        .from('reservations')
        .update({
          'status': 'rejected',
          'rejection_reason': reason,
          'reviewed_by': uid,
          'reviewed_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', reservationId)
        .eq('status', 'pending')
        .select('id');
    if ((updated as List).isEmpty) {
      throw StateError('Only pending reservations can be rejected.');
    }

    // ignore: avoid_print
    print('📧 [rejectReservation] Entering notify block');
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

        // ignore: avoid_print
        print('📧 [rejectReservation] Student: $name <$email>');

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
          // ignore: avoid_print
          print('📧 [rejectReservation] ✅ sendEmail returned');
        } else {
          // ignore: avoid_print
          print('📧 [rejectReservation] ⚠️ Email is null');
        }
      }
    } catch (e, stack) {
      // ignore: avoid_print
      print('📧 [rejectReservation] ❌ FAILED: $e');
      // ignore: avoid_print
      print('📧 [rejectReservation] STACK: $stack');
    }
  }

  @override
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

    final updated = await _client
        .from('reservations')
        .update({
          'status': 'borrowed',
          'released_at': now,
          'due_date': dueDate.toIso8601String().split('T').first,
          'updated_at': now,
        })
        .eq('id', reservationId)
        .eq('status', 'approved')
        .select('id');
    if ((updated as List).isEmpty) {
      throw StateError('Only approved reservations can be released.');
    }

    // ignore: avoid_print
    print('📧 [releaseReservation] Entering notify block');
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

        // ignore: avoid_print
        print('📧 [releaseReservation] Student: $name <$email>');

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
          // ignore: avoid_print
          print('📧 [releaseReservation] ✅ sendEmail returned');
        } else {
          // ignore: avoid_print
          print('📧 [releaseReservation] ⚠️ Email is null');
        }
      }
    } catch (e, stack) {
      // ignore: avoid_print
      print('📧 [releaseReservation] ❌ FAILED: $e');
      // ignore: avoid_print
      print('📧 [releaseReservation] STACK: $stack');
    }
  }

  @override
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

  @override
  Future<void> completeReservation(String reservationId) async {
    final now = DateTime.now().toIso8601String();
    final updated = await _client
        .from('reservations')
        .update({
          'status': 'completed',
          'returned_at': now,
          'updated_at': now,
        })
        .eq('id', reservationId)
        .eq('status', 'borrowed')
        .select('id');
    if ((updated as List).isEmpty) {
      throw StateError('Only borrowed reservations can be completed.');
    }

    // ignore: avoid_print
    print('📧 [completeReservation] Entering notify block');
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

        // ignore: avoid_print
        print('📧 [completeReservation] Student: $name <$email>');

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
          // ignore: avoid_print
          print('📧 [completeReservation] ✅ sendEmail returned');
        } else {
          // ignore: avoid_print
          print('📧 [completeReservation] ⚠️ Email is null');
        }
      }
    } catch (e, stack) {
      // ignore: avoid_print
      print('📧 [completeReservation] ❌ FAILED: $e');
      // ignore: avoid_print
      print('📧 [completeReservation] STACK: $stack');
    }
  }
}