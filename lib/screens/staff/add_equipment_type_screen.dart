import 'package:flutter/material.dart';

import '../../models/laboratory.dart';
import '../../services/inventory_service.dart';
import '../../services/laboratory_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/borrow_log_app_bar.dart';

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
      // ignore: avoid_print
      print('📋 [add-type] load labs failed: $e');
      setState(() {
        _error = 'Could not load laboratories. Please try again.';
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

  void _stepCount(int delta) {
    final next = (_count + delta).clamp(0, 500);
    setState(() => _countController.text = '$next');
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
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

      // ✅ Clear, consistent success toast
      AppFeedback.success(
        context,
        _count > 0
            ? 'Type "${newType.name}" created · $_count asset${_count == 1 ? '' : 's'} added'
            : 'Type "${newType.name}" created',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      // Log raw error, show friendly message
      // ignore: avoid_print
      print('📋 [add-type] save failed: $e');
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
    if (s.contains('network') ||
        s.contains('SocketException') ||
        s.contains('Failed host lookup')) {
      return 'Network error. Please check your connection and try again.';
    }
    return 'Could not create equipment type. Please try again.';
  }

  // ---------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------

  Color _statusColor(String s) {
    switch (s) {
      case 'available':
        return const Color(0xFF2E7D32);
      case 'reserved':
        return const Color(0xFFB26A00);
      case 'borrowed':
        return const Color(0xFF1565C0);
      case 'maintenance':
        return const Color(0xFFEF6C00);
      case 'damaged':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF616161);
    }
  }

  InputDecoration _decoration(
    String label, {
    String? hint,
    String? helper,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 3,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.maroon.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppTheme.maroon),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 14);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loadingLabs) {
      return const Scaffold(
        appBar: BorrowLogAppBar(title: 'Add equipment type'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const BorrowLogAppBar(title: 'Add equipment type'),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---- Details ----
                    _section(
                      icon: Icons.memory,
                      title: 'Type details',
                      subtitle: 'What kind of equipment is this?',
                      children: [
                        DropdownButtonFormField<Laboratory>(
                          initialValue: _selectedLab,
                          isExpanded: true,
                          decoration: _decoration(
                            'Laboratory *',
                            icon: Icons.meeting_room_outlined,
                          ),
                          items: _labs
                              .map(
                                (lab) => DropdownMenuItem(
                                  value: lab,
                                  child: Text(
                                    lab.displayLabel,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _selectedLab = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        _gap(),
                        TextFormField(
                          controller: _nameController,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(() {}),
                          decoration: _decoration(
                            'Name *',
                            hint: 'e.g. Keyboard',
                            icon: Icons.label_outline,
                            helper:
                                'Property numbers are generated as LabPrefix-Name-001, LabPrefix-Name-002, …',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Name is required'
                              : null,
                        ),
                        _gap(),
                        TextFormField(
                          controller: _categoryController,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: _decoration(
                            'Category',
                            hint: 'e.g. Input Device',
                            icon: Icons.category_outlined,
                          ),
                        ),
                        _gap(),
                        TextFormField(
                          controller: _descriptionController,
                          enabled: !_saving,
                          maxLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _decoration(
                            'Description',
                            icon: Icons.notes_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ---- Initial units ----
                    _section(
                      icon: Icons.inventory_2_outlined,
                      title: 'Initial units',
                      subtitle: 'Optional. Set to 0 to add units later.',
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _countController,
                                enabled: !_saving,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                onChanged: (_) => setState(() {}),
                                decoration: _decoration(
                                  'How many units? *',
                                  hint: 'e.g. 10',
                                ),
                                validator: (v) {
                                  final n = int.tryParse(v?.trim() ?? '');
                                  if (n == null || n < 0) {
                                    return 'Enter 0 or more';
                                  }
                                  if (n > 500) return 'Max 500';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  IconButton.filledTonal(
                                    tooltip: 'Decrease',
                                    onPressed: _saving || _count <= 0
                                        ? null
                                        : () => _stepCount(-1),
                                    icon: const Icon(Icons.remove),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton.filledTonal(
                                    tooltip: 'Increase',
                                    onPressed: _saving || _count >= 500
                                        ? null
                                        : () => _stepCount(1),
                                    icon: const Icon(Icons.add),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        _gap(),
                        Text(
                          'Initial status',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _statuses.map((s) {
                            return ChoiceChip(
                              avatar: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _statusColor(s),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              label: Text(s[0].toUpperCase() + s.substring(1)),
                              selected: _status == s,
                              onSelected: _saving
                                  ? null
                                  : (_) => setState(() => _status = s),
                            );
                          }).toList(),
                        ),
                        _gap(),
                        TextFormField(
                          controller: _notesController,
                          enabled: !_saving,
                          maxLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _decoration(
                            'Condition notes',
                            helper: 'Applies to all initial units.',
                            icon: Icons.sticky_note_2_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ---- Live preview ----
                    _previewCard(scheme),

                    // ---- Error ----
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      alignment: Alignment.topCenter,
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Container(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 10, 6, 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.red.shade700
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red.shade700,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Dismiss',
                                      icon: Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.red.shade700,
                                      ),
                                      onPressed: () =>
                                          setState(() => _error = null),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
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
                              ? 'Creating…'
                              : _count > 0
                                  ? 'Create type + $_count asset${_count == 1 ? '' : 's'}'
                                  : 'Create type',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.maroon,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewCard(ColorScheme scheme) {
    final preview = _previewNumbers;
    final capped = _count > 20;

    Widget hint(String text) => Text(
          text,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.maroon.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.maroon.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.preview_outlined,
                  color: AppTheme.maroon, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Property number preview',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.maroon,
                  ),
                ),
              ),
              if (_count > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.maroon.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$_count total',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.maroon,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedLab == null)
            hint('Select a laboratory to see the preview.')
          else if (_nameController.text.trim().isEmpty)
            hint('Enter a name to see the preview.')
          else if (preview.isEmpty)
            hint('Enter a quantity to see the preview.')
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: preview
                            .map(
                              (pn) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  pn,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  if (capped)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '… and ${_count - 20} more',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}