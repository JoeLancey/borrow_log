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

  factory Reservation.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'];
    final equipmentType = json['equipment_types'];

    return Reservation(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      equipmentTypeId: json['equipment_type_id'] as String,
      quantityRequested: json['quantity_requested'] as int,
      subject: json['subject'] as String,
      subjectCode: json['subject_code'] as String?,
      instructor: json['instructor'] as String,
      useDate: DateTime.parse(json['use_date'] as String),
      useTime: json['use_time'] as String?,
      notes: json['notes'] as String?,
      status: json['status'] as String,
      rejectionReason: json['rejection_reason'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'].toString())
          : null,
      releasedAt: json['released_at'] != null
          ? DateTime.tryParse(json['released_at'].toString())
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString())
          : null,
      returnedAt: json['returned_at'] != null
          ? DateTime.tryParse(json['returned_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      studentName: profile is Map ? profile['full_name'] as String? : null,
      equipmentTypeName:
          equipmentType is Map ? equipmentType['name'] as String? : null,
    );
  }

  factory Reservation.fromMap(Map<String, dynamic> map) =>
      Reservation.fromJson(map);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'equipment_type_id': equipmentTypeId,
      'quantity_requested': quantityRequested,
      'subject': subject,
      'subject_code': subjectCode,
      'instructor': instructor,
      'use_date': useDate.toIso8601String().split('T').first,
      'use_time': useTime,
      'notes': notes,
      'status': status,
      'rejection_reason': rejectionReason,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'released_at': releasedAt?.toIso8601String(),
      'due_date': dueDate?.toIso8601String().split('T').first,
      'returned_at': returnedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Reservation copyWith({
    String? id,
    String? studentId,
    String? equipmentTypeId,
    int? quantityRequested,
    String? subject,
    String? subjectCode,
    String? instructor,
    DateTime? useDate,
    String? useTime,
    String? notes,
    String? status,
    String? rejectionReason,
    String? reviewedBy,
    DateTime? reviewedAt,
    DateTime? releasedAt,
    DateTime? dueDate,
    DateTime? returnedAt,
    DateTime? createdAt,
    String? studentName,
    String? equipmentTypeName,
  }) {
    return Reservation(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      equipmentTypeId: equipmentTypeId ?? this.equipmentTypeId,
      quantityRequested: quantityRequested ?? this.quantityRequested,
      subject: subject ?? this.subject,
      subjectCode: subjectCode ?? this.subjectCode,
      instructor: instructor ?? this.instructor,
      useDate: useDate ?? this.useDate,
      useTime: useTime ?? this.useTime,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      releasedAt: releasedAt ?? this.releasedAt,
      dueDate: dueDate ?? this.dueDate,
      returnedAt: returnedAt ?? this.returnedAt,
      createdAt: createdAt ?? this.createdAt,
      studentName: studentName ?? this.studentName,
      equipmentTypeName: equipmentTypeName ?? this.equipmentTypeName,
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