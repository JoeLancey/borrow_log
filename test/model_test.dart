import 'package:borrow_log/models/borrower.dart';
import 'package:borrow_log/models/reservation.dart';
import 'package:borrow_log/models/reservation_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Borrower', () {
    test('round-trips JSON and supports copyWith', () {
      const borrower = Borrower(
        id: 'user-1',
        email: 'student@example.com',
        fullName: 'Test Student',
        role: 'student',
        studentId: 'S-001',
      );

      final decoded = Borrower.fromJson(borrower.toJson());

      expect(decoded.id, borrower.id);
      expect(decoded.fullName, borrower.fullName);
      expect(decoded.copyWith(fullName: 'Updated').fullName, 'Updated');
    });
  });

  group('Reservation', () {
    test('round-trips core JSON fields and preserves overdue behavior', () {
      final reservation = Reservation.fromJson({
        'id': 'reservation-1',
        'student_id': 'user-1',
        'equipment_type_id': 'type-1',
        'quantity_requested': 2,
        'subject': 'Chemistry',
        'subject_code': 'CHEM101',
        'instructor': 'Dr. Test',
        'use_date': '2026-01-01',
        'use_time': '09:00',
        'notes': 'Handle carefully',
        'status': 'borrowed',
        'due_date': '2025-12-01',
      });

      final decoded = Reservation.fromJson(reservation.toJson());

      expect(decoded.id, reservation.id);
      expect(decoded.quantityRequested, 2);
      expect(decoded.isOverdue, isTrue);
      expect(decoded.copyWith(status: 'completed').status, 'completed');
    });
  });

  test('ReservationItem serializes database fields', () {
    final item = ReservationItem(
      id: 'item-1',
      reservationId: 'reservation-1',
      equipmentTypeId: 'type-1',
      quantityRequested: 3,
    );

    expect(ReservationItem.fromJson(item.toJson()).quantityRequested, 3);
  });
}
