import 'package:supabase_flutter/supabase_flutter.dart';

class AdminResult {
  final bool success;
  final String? errorMessage;
  final String? userId;

  AdminResult({required this.success, this.errorMessage, this.userId});
}

class AdminService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<AdminResult> createUser({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? studentId,
    String? course,
    String? college,
    String? employeeId,
    String? department,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'admin_create_user',
        body: {
          'email': email.trim(),
          'password': password,
          'full_name': fullName.trim(),
          'role': role,
          if (studentId != null && studentId.trim().isNotEmpty)
            'student_id': studentId.trim(),
          if (course != null && course.trim().isNotEmpty)
            'course': course.trim(),
          if (college != null && college.trim().isNotEmpty)
            'college': college.trim(),
          if (employeeId != null && employeeId.trim().isNotEmpty)
            'employee_id': employeeId.trim(),
          if (department != null && department.trim().isNotEmpty)
            'department': department.trim(),
        },
      );

      final data = res.data;
      if (data is Map && data['ok'] == true) {
        return AdminResult(
          success: true,
          userId: data['user_id'] as String?,
        );
      }

      final err = (data is Map ? data['error'] : null)?.toString() ??
          'Failed to create user.';
      return AdminResult(success: false, errorMessage: err);
    } on FunctionException catch (e) {
      return AdminResult(
        success: false,
        errorMessage: 'Server error (${e.status}): ${e.details}',
      );
    } catch (e) {
      return AdminResult(
        success: false,
        errorMessage: 'Unexpected error: $e',
      );
    }
  }
}