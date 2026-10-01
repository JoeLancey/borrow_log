import 'package:flutter/material.dart';

import '../../models/laboratory.dart';
import '../../services/inventory_service.dart';
import '../../services/laboratory_service.dart';
import '../../theme/app_theme.dart';

class AddEquipmentTypeScreen extends StatefulWidget {
  const AddEquipmentTypeScreen({super.key});

  @override
  State<AddEquipmentTypeScreen> createState() => _AddEquipmentTypeScreenState();
}

class _AddEquipmentTypeScreenState extends State<AddEquipmentTypeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _countController = TextEditingController(text: '1');
  final _notesController = TextEditingController();
  final _service = InventoryService();
  final _labService = LaboratoryService();

  List<Laboratory> _labs = [];
  Laboratory? _selectedLab;
  String _status = 'available';

  bool _loadingLabs = true;
  bool _saving = false;
  String? _error;

  static const _statuses = [
    'available',
    'reserved',
    'borrowed',
    'damaged',
    'lost',
    'maintenance',
  ];

  @override
  void initState() {
    super.initState();
    _loadLabs();
  }

  Future<void> _loadLabs() async {
    try {
      final labs = await _labService.fetchAllLaboratories();
      if (!mounted) return;
      setState(() {
        _labs = labs;
        _loadingLabs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load laboratories: $e';
        _loadingLabs = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _countController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _count => int.tryParse(_countController.text.trim()) ?? 0;

  /// Prefix used in the preview: "{labPrefix}-{typeName}-".
  /// Empty when either lab or name is not yet chosen.
  String get _previewPrefix {
    if (_selectedLab == null) return '';
    final name = _nameController.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (name.isEmpty) return '';
    final lab = _service.labPrefix(_selectedLab!.name);
    return '$lab-$name-';
  }

  List<String> get _previewNumbers {
    if (_previewPrefix.isEmpty || _count <= 0) return [];
    final displayCount = _count > 20 ? 20 : _count;
    return List.generate(
      displayCount,
      (i) => '$_previewPrefix${(i + 1).toString().padLeft(3, '0')}',
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLab == null) {
      setState(() => _error = 'Please select a laboratory.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // 1. Create the type
      await _service.createType(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        laboratoryId: _selectedLab!.id,
      );

      // 2. Fetch the just-created type so we know its id
      final allTypes = await _service.fetchTypes();
      final newType = allTypes.firstWhere(
        (t) =>
            t.name.toLowerCase() ==
                _nameController.text.trim().toLowerCase() &&
            t.laboratoryId == _selectedLab!.id,
        orElse: () => throw Exception('Failed to locate new type.'),
      );

      // 3. Bulk-create assets if quantity > 0 (lab-aware, collision-safe)
      if (_count > 0) {
        await _service.createLabAwareAssets(
          equipmentTypeId: newType.id,
          labName: _selectedLab!.name,
          typeName: newType.name,
          count: _count,
          status: _status,
          conditionNotes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Created "${newType.name}" with $_count asset(s).',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _readableError(e);
      });
    }
  }

  String _readableError(Object e) {
    final s = e.toString();
    if (s.contains('duplicate key') &&
        (s.contains('equipment_types_name_lab_key') ||
            s.contains('equipment_types_name_key'))) {
      return 'A type with this name already exists in this laboratory.';
    }
    if (s.contains('duplicate key') && s.contains('property_number')) {
      return 'Some property numbers already exist. Try a different quantity.';
    }
    if (s.contains('violates row-level security')) {
      return 'Permission denied. Only staff can add equipment.';
    }
    return 'Failed to save: $s';
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingLabs) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Equipment Type')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Add Equipment Type')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Laboratory
              DropdownButtonFormField<Laboratory>(
                initialValue: _selectedLab,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Laboratory *',
                  border: OutlineInputBorder(),
                ),
                items: _labs
                    .map((lab) => DropdownMenuItem(
                          value: lab,
                          child: Text(
                            lab.displayLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _selectedLab = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Name
              TextFormField(
                controller: _nameController,
                enabled: !_saving,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'e.g. Keyboard',
                  border: OutlineInputBorder(),
                  helperText:
                      'Property numbers will be generated as LabPrefix-Name-001, LabPrefix-Name-002, ...',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              // Category
              TextFormField(
                controller: _categoryController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: 'e.g. Input Device',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                enabled: !_saving,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Divider between metadata and units
              const Divider(thickness: 1),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'INITIAL UNITS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.maroon,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Quantity
              TextFormField(
                controller: _countController,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'How many units? *',
                  hintText: 'e.g. 10',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n < 0) return 'Enter 0 or more';
                  if (n > 500) return 'Max 500';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Status
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Initial status',
                  border: OutlineInputBorder(),
                ),
                items: _statuses
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            s[0].toUpperCase() + s.substring(1),
                          ),
                        ))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _status = v ?? 'available'),
              ),
              const SizedBox(height: 16),

              // Condition notes
              TextFormField(
                controller: _notesController,
                enabled: !_saving,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Condition notes (applies to all initial units)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Live preview
              _previewCard(),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _saving
                        ? 'Creating...'
                        : 'CREATE TYPE + $_count ASSET(S)',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.maroon,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewCard() {
    final preview = _previewNumbers;
    final capped = _count > 20;

    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.preview,
                    color: AppTheme.maroon, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Property Number Preview',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.maroon,
                  ),
                ),
                const Spacer(),
                if (_count > 0)
                  Text(
                    '$_count total',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_selectedLab == null)
              const Text(
                'Select a laboratory to see the preview.',
                style: TextStyle(
                    color: Colors.black54, fontStyle: FontStyle.italic),
              )
            else if (_nameController.text.trim().isEmpty)
              const Text(
                'Enter a name to see the preview.',
                style: TextStyle(
                    color: Colors.black54, fontStyle: FontStyle.italic),
              )
            else if (preview.isEmpty)
              const Text(
                'Enter a quantity to see the preview.',
                style: TextStyle(
                    color: Colors.black54, fontStyle: FontStyle.italic),
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...preview.map(
                      (pn) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          pn,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    if (capped)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '... and ${_count - 20} more',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}