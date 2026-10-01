import 'package:flutter/material.dart';

import '../../models/equipment_type.dart';
import '../../models/laboratory.dart';
import '../../services/inventory_service.dart';
import '../../services/laboratory_service.dart';
import '../../theme/app_theme.dart';

class AddEquipmentAssetScreen extends StatefulWidget {
  final List<EquipmentType> types;
  final String? preselectedTypeId;

  const AddEquipmentAssetScreen({
    super.key,
    required this.types,
    this.preselectedTypeId,
  });

  @override
  State<AddEquipmentAssetScreen> createState() =>
      _AddEquipmentAssetScreenState();
}

class _AddEquipmentAssetScreenState extends State<AddEquipmentAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _countController = TextEditingController(text: '1');
  final _notesController = TextEditingController();

  final _service = InventoryService();
  final _labService = LaboratoryService();

  List<Laboratory> _labs = [];
  Laboratory? _selectedLab;
  List<EquipmentType> _labTypes = [];
  EquipmentType? _matchedType;

  /// The counter that will be used next. Auto-computed, read-only.
  int _nextStart = 1;

  String _status = 'available';
  bool _loadingLabs = true;
  bool _loadingTypes = false;
  bool _loadingStart = false;
  bool _saving = false;
  String? _error;
  bool _showSuggestions = false;

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

      Laboratory? initialLab;
      if (widget.preselectedTypeId != null) {
        final t = widget.types.firstWhere(
          (t) => t.id == widget.preselectedTypeId,
          orElse: () => widget.types.isEmpty
              ? EquipmentType(id: '', name: '')
              : widget.types.first,
        );
        if (t.id.isNotEmpty && t.laboratoryId != null) {
          initialLab = labs.firstWhere(
            (l) => l.id == t.laboratoryId,
            orElse: () => labs.isEmpty
                ? Laboratory(id: '', name: '', building: '', department: '')
                : labs.first,
          );
          if (initialLab.id.isEmpty) initialLab = null;
        }
      }

      setState(() {
        _labs = labs;
        _selectedLab = initialLab;
        _loadingLabs = false;
      });

      if (initialLab != null) {
        await _loadTypesForLab(initialLab.id);

        if (widget.preselectedTypeId != null) {
          final t = _labTypes.firstWhere(
            (t) => t.id == widget.preselectedTypeId,
            orElse: () => _labTypes.isEmpty
                ? EquipmentType(id: '', name: '')
                : _labTypes.first,
          );
          if (t.id.isNotEmpty) {
            _nameController.text = t.name;
            _matchedType = t;
            await _refreshNextStart(t);
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load laboratories: $e';
        _loadingLabs = false;
      });
    }
  }

  Future<void> _loadTypesForLab(String labId) async {
    setState(() {
      _loadingTypes = true;
      _labTypes = [];
      _matchedType = null;
      _nextStart = 1;
    });

    try {
      final types = await _service.fetchTypesForLab(labId);
      if (!mounted) return;
      setState(() {
        _labTypes = types;
        _loadingTypes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load equipment: $e';
        _loadingTypes = false;
      });
    }
  }

  Future<void> _refreshNextStart(EquipmentType type) async {
    setState(() => _loadingStart = true);
    try {
      final next = await _service.nextAvailableCounter(
        equipmentTypeId: type.id,
        typeName: type.name,
      );
      if (!mounted) return;
      setState(() {
        _nextStart = next;
        _loadingStart = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStart = false);
    }
  }

  void _onNameChanged(String value) {
    final trimmed = value.trim().toLowerCase();
    EquipmentType? match;
    if (trimmed.isNotEmpty) {
      for (final t in _labTypes) {
        if (t.name.toLowerCase() == trimmed) {
          match = t;
          break;
        }
      }
    }

    setState(() {
      _showSuggestions = trimmed.isNotEmpty && match == null;
      _matchedType = match;
    });

    if (match != null) {
      _refreshNextStart(match);
    }
  }

  List<EquipmentType> get _suggestions {
    final q = _nameController.text.trim().toLowerCase();
    if (q.isEmpty) return [];
    return _labTypes
        .where((t) => t.name.toLowerCase().contains(q))
        .take(8)
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _count => int.tryParse(_countController.text.trim()) ?? 0;

  String get _prefix {
    final name = _matchedType?.name ?? _nameController.text.trim();
    return name.replaceAll(RegExp(r'\s+'), '');
  }

  List<String> get _previewNumbers {
    if (_prefix.isEmpty || _count <= 0) return [];
    final displayCount = _count > 20 ? 20 : _count;
    return List.generate(
      displayCount,
      (i) => '$_prefix-${(_nextStart + i).toString().padLeft(3, '0')}',
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLab == null) {
      setState(() => _error = 'Please select a laboratory.');
      return;
    }
    if (_matchedType == null) {
      setState(() {
        _error = 'No equipment named "${_nameController.text.trim()}" '
            'in this laboratory. Add the type first.';
      });
      return;
    }
    if (_count <= 0) {
      setState(() => _error = 'Quantity must be at least 1.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final pns = _service.generatePropertyNumbers(
        typeName: _matchedType!.name,
        start: _nextStart,
        count: _count,
      );
      final created = await _service.bulkCreateAssets(
        equipmentTypeId: _matchedType!.id,
        propertyNumbers: pns,
        status: _status,
        conditionNotes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$created asset(s) created.')),
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
    if (s.contains('duplicate key') && s.contains('property_number')) {
      return 'Some property numbers already exist. Please refresh and '
          'try again.';
    }
    if (s.contains('violates row-level security')) {
      return 'Permission denied. Only staff can add equipment.';
    }
    return 'Failed to create assets: $s';
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingLabs) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Equipment Assets')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Add Equipment Assets')),
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
                    .map((l) => DropdownMenuItem(
                          value: l,
                          child: Text(
                            l.displayLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) async {
                        setState(() {
                          _selectedLab = v;
                          _nameController.clear();
                          _matchedType = null;
                          _showSuggestions = false;
                        });
                        if (v != null) await _loadTypesForLab(v.id);
                      },
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Equipment name (free text with suggestions)
              TextFormField(
                controller: _nameController,
                enabled: !_saving,
                onChanged: _onNameChanged,
                decoration: InputDecoration(
                  labelText: 'Equipment name *',
                  hintText: 'Start typing… e.g. Keyboard',
                  border: const OutlineInputBorder(),
                  suffixIcon: _matchedType != null
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  helperText: _loadingTypes
                      ? 'Loading types in this lab…'
                      : _matchedType != null
                          ? 'Matches existing type: ${_matchedType!.name}'
                          : _nameController.text.trim().isEmpty
                              ? 'Type the equipment name.'
                              : 'No exact match yet. Pick a suggestion or '
                                  'add the type first.',
                ),
              ),

              // Suggestions
              if (_showSuggestions && _suggestions.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: _suggestions
                        .map(
                          (t) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.memory,
                                size: 18, color: AppTheme.maroon),
                            title: Text(t.name),
                            onTap: () async {
                              _nameController.text = t.name;
                              setState(() {
                                _matchedType = t;
                                _showSuggestions = false;
                              });
                              await _refreshNextStart(t);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Next-start info card (read-only)
              if (_matchedType != null)
                Card(
                  elevation: 0,
                  color: AppTheme.maroon.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppTheme.maroon, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _loadingStart
                              ? const Text(
                                  'Calculating next available number…',
                                  style: TextStyle(fontSize: 13),
                                )
                              : Text(
                                  'Next available: $_prefix-'
                                  '${_nextStart.toString().padLeft(3, '0')}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Quantity
              TextFormField(
                controller: _countController,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Quantity *',
                  hintText: 'How many to create',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'Enter a number ≥ 1';
                  if (n > 500) return 'Max 500';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Status
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
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

              // Notes
              TextFormField(
                controller: _notesController,
                enabled: !_saving,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Condition notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Preview
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
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.playlist_add),
                  label: Text(
                    _saving
                        ? 'Creating…'
                        : 'CREATE $_count ASSET(S)',
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
            if (_prefix.isEmpty)
              const Text(
                'Enter or pick an equipment name to see the preview.',
                style: TextStyle(
                    color: Colors.black54, fontStyle: FontStyle.italic),
              )
            else if (_matchedType == null)
              const Text(
                'Pick a matching type to compute the next number.',
                style: TextStyle(
                    color: Colors.black54, fontStyle: FontStyle.italic),
              )
            else if (_loadingStart)
              const Text(
                'Calculating…',
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
                          '… and ${_count - 20} more',
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