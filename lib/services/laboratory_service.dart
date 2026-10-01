import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/college.dart';
import '../models/laboratory.dart';

class LaboratoryService {
  final SupabaseClient _client = Supabase.instance.client;

  // ---------------------------------------------------------
  // COLLEGES
  // ---------------------------------------------------------

  Future<List<College>> fetchColleges() async {
    final data = await _client
        .from('colleges')
        .select()
        .order('name', ascending: true);

    return (data as List)
        .map((row) => College.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------
  // LABORATORIES
  // ---------------------------------------------------------

  /// All laboratories, ordered by department then name. For staff views.
  Future<List<Laboratory>> fetchAllLaboratories() async {
    final data = await _client
        .from('laboratories')
        .select()
        .order('department', ascending: true)
        .order('name', ascending: true);

    return (data as List)
        .map((row) => Laboratory.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Labs accessible to a specific college (by college name string).
  /// Used by students.
  Future<List<Laboratory>> fetchLaboratoriesForCollegeName(
      String collegeName) async {
    // 1. Find the college row matching the name
    final collegeRow = await _client
        .from('colleges')
        .select('id')
        .eq('name', collegeName)
        .maybeSingle();

    if (collegeRow == null) return [];

    // 2. Fetch labs via the access table
    final data = await _client
        .from('college_laboratory_access')
        .select('laboratories(*)')
        .eq('college_id', collegeRow['id'] as String);

    return (data as List)
        .map((row) {
          final lab = row['laboratories'] as Map<String, dynamic>;
          return Laboratory.fromMap(lab);
        })
        .toList()
      ..sort((a, b) {
        final byDept = a.department.compareTo(b.department);
        if (byDept != 0) return byDept;
        return a.name.compareTo(b.name);
      });
  }

  /// Labs accessible to the currently signed-in user (based on their college).
  /// Returns empty list if the user has no college set.
  Future<List<Laboratory>> fetchMyAccessibleLaboratories() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];

    final profile = await _client
        .from('profiles')
        .select('college')
        .eq('id', uid)
        .maybeSingle();

    final collegeName = profile?['college'] as String?;
    if (collegeName == null || collegeName.trim().isEmpty) return [];

    return fetchLaboratoriesForCollegeName(collegeName.trim());
  }

  /// Fetch a single lab by id.
  Future<Laboratory?> fetchLaboratoryById(String id) async {
    final data = await _client
        .from('laboratories')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (data == null) return null;
    return Laboratory.fromMap(data);
  }

  /// Look up a lab by name (used when matching text values).
  Future<Laboratory?> fetchLaboratoryByName(String name) async {
    final data = await _client
        .from('laboratories')
        .select()
        .eq('name', name.trim())
        .maybeSingle();

    if (data == null) return null;
    return Laboratory.fromMap(data);
  }
}