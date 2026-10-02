class Borrower {
  const Borrower({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.studentId,
    this.course,
    this.college,
    this.employeeId,
    this.department,
  });

  factory Borrower.fromJson(Map<String, dynamic> json) {
    return Borrower(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      studentId: json['student_id'] as String?,
      course: json['course'] as String?,
      college: json['college'] as String?,
      employeeId: json['employee_id'] as String?,
      department: json['department'] as String?,
    );
  }

  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? studentId;
  final String? course;
  final String? college;
  final String? employeeId;
  final String? department;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'student_id': studentId,
      'course': course,
      'college': college,
      'employee_id': employeeId,
      'department': department,
    };
  }

  Borrower copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    String? studentId,
    String? course,
    String? college,
    String? employeeId,
    String? department,
  }) {
    return Borrower(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      studentId: studentId ?? this.studentId,
      course: course ?? this.course,
      college: college ?? this.college,
      employeeId: employeeId ?? this.employeeId,
      department: department ?? this.department,
    );
  }
}
