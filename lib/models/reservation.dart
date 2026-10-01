class Reservation {
  final String id;
  final String studentId;
  final String equipmentTypeId;
  final int quantityRequested;

  final String subject;
  final String? subjectCode;
  final String instructor;

  final DateTime useDate;
  final String? useTime;
  final String? notes;

  final String status;
  final String? rejectionReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  // Lifecycle
  final DateTime? releasedAt;
  final DateTime? dueDate;
  final DateTime? returnedAt;

  final DateTime? createdAt;

  // Joined fields
  final String? studentName;
  final String? equipmentTypeName;

  Reservation({
    required this.id,
    required this.studentId,
    required this.equipmentTypeId,
    required this.quantityRequested,
    required this.subject,
    this.subjectCode,
    required this.instructor,
    required this.useDate,
    this.useTime,
    this.notes,
    required this.status,
    this.rejectionReason,
    this.reviewedBy,
    this.reviewedAt,
    this.releasedAt,
    this.dueDate,
    this.returnedAt,
    this.createdAt,
    this.studentName,
    this.equipmentTypeName,
  });

  factory Reservation.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'];
    final equipmentType = map['equipment_types'];

    return Reservation(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      equipmentTypeId: map['equipment_type_id'] as String,
      quantityRequested: map['quantity_requested'] as int,
      subject: map['subject'] as String,
      subjectCode: map['subject_code'] as String?,
      instructor: map['instructor'] as String,
      useDate: DateTime.parse(map['use_date'] as String),
      useTime: map['use_time'] as String?,
      notes: map['notes'] as String?,
      status: map['status'] as String,
      rejectionReason: map['rejection_reason'] as String?,
      reviewedBy: map['reviewed_by'] as String?,
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.tryParse(map['reviewed_at'].toString())
          : null,
      releasedAt: map['released_at'] != null
          ? DateTime.tryParse(map['released_at'].toString())
          : null,
      dueDate: map['due_date'] != null
          ? DateTime.tryParse(map['due_date'].toString())
          : null,
      returnedAt: map['returned_at'] != null
          ? DateTime.tryParse(map['returned_at'].toString())
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      studentName: profile is Map ? profile['full_name'] as String? : null,
      equipmentTypeName:
          equipmentType is Map ? equipmentType['name'] as String? : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'borrowed':
        return 'Borrowed';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  bool get isActive =>
      status == 'approved' || status == 'borrowed';

  bool get isOverdue {
    if (dueDate == null) return false;
    if (status != 'borrowed') return false;
    final today = DateTime.now();
    final d = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final t = DateTime(today.year, today.month, today.day);
    return t.isAfter(d);
  }

  int get daysUntilDue {
    if (dueDate == null) return 0;
    final today = DateTime.now();
    final d = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final t = DateTime(today.year, today.month, today.day);
    return d.difference(t).inDays;
  }

  String get useDateFormatted {
    final d = useDate;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String? get dueDateFormatted {
    if (dueDate == null) return null;
    final d = dueDate!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}