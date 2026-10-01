import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/equipment_type.dart';
import '../models/equipment_asset.dart';

/// Handles all equipment inventory operations against Supabase.
class InventoryService {
  final SupabaseClient _client = Supabase.instance.client;

  // ---------------------------------------------------------
  // EQUIPMENT TYPES
  // ---------------------------------------------------------

  /// Fetch all equipment types, sorted by name.
  Future<List<EquipmentType>> fetchTypes() async {
    final data = await _client
        .from('equipment_types')
        .select()
        .order('name', ascending: true);

    return (data as List)
        .map((row) => EquipmentType.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetch equipment types belonging to a specific laboratory.
  Future<List<EquipmentType>> fetchTypesForLab(String laboratoryId) async {
    final data = await _client
        .from('equipment_types')
        .select()
        .eq('laboratory_id', laboratoryId)
        .order('name', ascending: true);

    return (data as List)
        .map((row) => EquipmentType.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetch equipment types across a set of laboratory ids.
  Future<List<EquipmentType>> fetchTypesForLabs(
      List<String> laboratoryIds) async {
    if (laboratoryIds.isEmpty) return [];
    final data = await _client
        .from('equipment_types')
        .select()
        .inFilter('laboratory_id', laboratoryIds)
        .order('name', ascending: true);

    return (data as List)
        .map((row) => EquipmentType.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Insert a new equipment type.
  Future<void> createType({
    required String name,
    String? description,
    String? category,
    String? laboratoryId,
  }) async {
    await _client.from('equipment_types').insert({
      'name': name,
      'description': description,
      'category': category,
      'laboratory_id': laboratoryId,
    });
  }

  /// Delete an equipment type (cascades to its assets).
  Future<void> deleteType(String id) async {
    await _client.from('equipment_types').delete().eq('id', id);
  }

  // ---------------------------------------------------------
  // EQUIPMENT ASSETS
  // ---------------------------------------------------------

  /// Fetch every asset.
  Future<List<EquipmentAsset>> fetchAssets() async {
    final data = await _client
        .from('equipment_assets')
        .select()
        .order('property_number', ascending: true);

    return (data as List)
        .map((row) => EquipmentAsset.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetch assets belonging to a specific type.
  Future<List<EquipmentAsset>> fetchAssetsForType(String typeId) async {
    final data = await _client
        .from('equipment_assets')
        .select()
        .eq('equipment_type_id', typeId)
        .order('property_number', ascending: true);

    return (data as List)
        .map((row) => EquipmentAsset.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Insert a single new asset.
  Future<void> createAsset({
    required String equipmentTypeId,
    required String propertyNumber,
    String status = 'available',
    String? conditionNotes,
  }) async {
    await _client.from('equipment_assets').insert({
      'equipment_type_id': equipmentTypeId,
      'property_number': propertyNumber,
      'status': status,
      'condition_notes': conditionNotes,
    });
  }

  /// Insert multiple assets at once. Returns the count created.
  Future<int> bulkCreateAssets({
    required String equipmentTypeId,
    required List<String> propertyNumbers,
    String status = 'available',
    String? conditionNotes,
  }) async {
    if (propertyNumbers.isEmpty) return 0;
    await _client.from('equipment_assets').insert(
          propertyNumbers
              .map((pn) => {
                    'equipment_type_id': equipmentTypeId,
                    'property_number': pn,
                    'status': status,
                    'condition_notes': conditionNotes,
                  })
              .toList(),
        );
    return propertyNumbers.length;
  }

  /// Update an asset's status and/or notes.
  Future<void> updateAsset({
    required String id,
    String? status,
    String? conditionNotes,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (status != null) updates['status'] = status;
    if (conditionNotes != null) updates['condition_notes'] = conditionNotes;

    await _client.from('equipment_assets').update(updates).eq('id', id);
  }

  /// Update status for multiple assets in one round-trip.
  Future<void> bulkUpdateStatus({
    required List<String> assetIds,
    required String status,
  }) async {
    if (assetIds.isEmpty) return;
    await _client.from('equipment_assets').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).inFilter('id', assetIds);
  }

  /// Delete multiple assets in one round-trip.
  Future<void> bulkDeleteAssets(List<String> assetIds) async {
    if (assetIds.isEmpty) return;
    await _client.from('equipment_assets').delete().inFilter('id', assetIds);
  }

  /// Delete a single asset.
  Future<void> deleteAsset(String id) async {
    await _client.from('equipment_assets').delete().eq('id', id);
  }

  // ---------------------------------------------------------
  // PROPERTY NUMBER GENERATION
  // ---------------------------------------------------------

  /// Strips whitespace from a type name to form the property-number prefix.
  /// "Arduino Uno" → "ArduinoUno"
  String _sanitizePrefix(String typeName) {
    return typeName.replaceAll(RegExp(r'\s+'), '');
  }

  /// Returns the first N letters (A–Z, case preserved) of a lab name.
  /// "Acer / Google / Multimedia Labs" → "Ace"
  /// "Networking Lab"                 → "Net"
  ///
  /// If the name contains fewer than [length] letters, returns what exists.
  /// If it contains zero letters, returns "Lab".
  String labPrefix(String labName, {int length = 3}) {
    final lettersOnly = labName.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (lettersOnly.isEmpty) return 'Lab';
    if (lettersOnly.length <= length) return lettersOnly;
    return lettersOnly.substring(0, length);
  }

  /// Finds the next available counter for a given type (within one lab only).
  /// Example: existing PNs are ArduinoUno-001, ArduinoUno-005 → returns 6.
  ///
  /// Kept for backwards compatibility with Add Equipment Asset screen.
  Future<int> nextAvailableCounter({
    required String equipmentTypeId,
    required String typeName,
  }) async {
    final assets = await fetchAssetsForType(equipmentTypeId);
    final safePrefix = _sanitizePrefix(typeName);
    final pattern = RegExp('^${RegExp.escape(safePrefix)}-(\\d+)\$');

    int max = 0;
    for (final a in assets) {
      final m = pattern.firstMatch(a.propertyNumber);
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > max) max = n;
      }
    }
    return max + 1;
  }

  /// Generates a list of property numbers like
  /// ["ArduinoUno-001", "ArduinoUno-002", ...].
  ///
  /// Kept for backwards compatibility with Add Equipment Asset screen.
  List<String> generatePropertyNumbers({
    required String typeName,
    required int start,
    required int count,
  }) {
    final safePrefix = _sanitizePrefix(typeName);
    return List.generate(
      count,
      (i) => '$safePrefix-${(start + i).toString().padLeft(3, '0')}',
    );
  }

  /// Finds the next available counter for the SAME equipment name
  /// WITHIN THE SAME LAB.
  ///
  /// Example: lab "Networking Lab" + name "Router" already has
  /// Net-Router-001 and Net-Router-003 → returns 4.
  ///
  /// Uses the property-number prefix convention:
  ///   {labPrefix}-{typeName}-{NNN}
  Future<int> nextAvailableCounterForLabAndName({
    required String labName,
    required String typeName,
  }) async {
    final lab = labPrefix(labName);
    final type = _sanitizePrefix(typeName);
    if (type.isEmpty) return 1;

    final prefix = '$lab-$type-';
    final pattern = RegExp('^${RegExp.escape(prefix)}(\\d+)\$');

    final rows = await _client
        .from('equipment_assets')
        .select('property_number')
        .like('property_number', '$prefix%');

    int max = 0;
    for (final row in (rows as List)) {
      final pn = (row['property_number'] as String?) ?? '';
      final m = pattern.firstMatch(pn);
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > max) max = n;
      }
    }
    return max + 1;
  }

  /// Generates a list of property numbers in the format:
  ///   {labPrefix}-{typeName}-{NNN}
  /// e.g. ["Ace-Router-001", "Ace-Router-002", ...]
  List<String> generateLabAwarePropertyNumbers({
    required String labName,
    required String typeName,
    required int start,
    required int count,
  }) {
    final lab = labPrefix(labName);
    final type = _sanitizePrefix(typeName);
    return List.generate(
      count,
      (i) => '$lab-$type-${(start + i).toString().padLeft(3, '0')}',
    );
  }

  // ---------------------------------------------------------
  // COLLISION-SAFE INSERT
  // ---------------------------------------------------------

  /// Inserts assets using the lab-aware property-number format.
  ///
  /// On a duplicate property_number collision, it retries ONCE with an
  /// extended lab prefix (4 letters, then 5, then the full sanitized
  /// lab name). This keeps numbers short in the common case and
  /// resolves rare collisions automatically.
  Future<void> createLabAwareAssets({
    required String equipmentTypeId,
    required String labName,
    required String typeName,
    required int count,
    String status = 'available',
    String? conditionNotes,
  }) async {
    if (count <= 0) return;

    final fullNameLetters = labName.replaceAll(RegExp(r'[^A-Za-z]'), '');
    final attempts = <int>[3, 4, 5, fullNameLetters.length];
    final tried = <int>{};

    Object? lastError;

    for (final len in attempts) {
      if (len < 3) continue;
      if (tried.contains(len)) continue;
      tried.add(len);

      final lab = labPrefix(labName, length: len);
      final type = _sanitizePrefix(typeName);

      // Compute next counter for this lab+type at this prefix length.
      final prefix = '$lab-$type-';
      final pattern = RegExp('^${RegExp.escape(prefix)}(\\d+)\$');

      final rows = await _client
          .from('equipment_assets')
          .select('property_number')
          .like('property_number', '$prefix%');

      int max = 0;
      for (final row in (rows as List)) {
        final pn = (row['property_number'] as String?) ?? '';
        final m = pattern.firstMatch(pn);
        if (m != null) {
          final n = int.tryParse(m.group(1)!) ?? 0;
          if (n > max) max = n;
        }
      }
      final start = max + 1;

      final pns = List.generate(
        count,
        (i) => '$prefix${(start + i).toString().padLeft(3, '0')}',
      );

      try {
        await bulkCreateAssets(
          equipmentTypeId: equipmentTypeId,
          propertyNumbers: pns,
          status: status,
          conditionNotes: conditionNotes,
        );
        return; // success
      } catch (e) {
        lastError = e;
        // Only retry on a property_number duplicate.
        final s = e.toString();
        if (!(s.contains('duplicate key') &&
            s.contains('property_number'))) {
          rethrow;
        }
      }
    }

    // All attempts failed — surface the last error.
    throw lastError ?? Exception('Failed to create assets.');
  }

  // ---------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------

  /// Count assets of a given type that have a specific status.
  int countByStatus(List<EquipmentAsset> assets, String status) {
    return assets.where((a) => a.status == status).length;
  }
}