import 'package:flutter/material.dart';

import '../../models/equipment_type.dart';
import '../../models/laboratory.dart';
import '../../services/inventory_service.dart';
import '../../services/laboratory_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/borrow_log_app_bar.dart';

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

  void _stepCount(int delta) {
    final next = (_count + delta).clamp(1, 500);
    setState(() => _countController.text = '$next');
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
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
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 3,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      suffixIcon: suffix,
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

  String get _nameHelper {
    if (_loadingTypes) return 'Loading types in this lab…';
    if (_matchedType != null) {
      return 'Matches existing type: ${_matchedType!.name}';
    }
    if (_nameController.text.trim().isEmpty) return 'Type the equipment name.';
    return 'No exact match yet. Pick a suggestion or add the type first.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loadingLabs) {
      return const Scaffold(
        appBar: BorrowLogAppBar(title: 'Add equipment assets'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const BorrowLogAppBar(title: 'Add equipment assets'),
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
                    // ---- Which equipment ----
                    _section(
                      icon: Icons.memory,
                      title: 'Which equipment?',
                      subtitle: 'Pick the lab, then the equipment type.',
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
                                (l) => DropdownMenuItem(
                                  value: l,
                                  child: Text(
                                    l.displayLabel,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
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
                        _gap(),
                        TextFormField(
                          controller: _nameController,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.words,
                          onChanged: _onNameChanged,
                          decoration: _decoration(
                            'Equipment name *',
                            hint: 'Start typing… e.g. Keyboard',
                            icon: Icons.search,
                            helper: _nameHelper,
                            suffix: _matchedType != null
                                ? Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade700,
                                  )
                                : null,
                          ),
                        ),

                        // Suggestions
                        if (_showSuggestions && _suggestions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              border: Border.all(color: scheme.outlineVariant),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                for (var i = 0;
                                    i < _suggestions.length;
                                    i++) ...[
                                  ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.memory,
                                      size: 18,
                                      color: AppTheme.maroon,
                                    ),
                                    title: Text(_suggestions[i].name),
                                    trailing: const Icon(
                                      Icons.north_west,
                                      size: 16,
                                    ),
                                    onTap: () async {
                                      final t = _suggestions[i];
                                      _nameController.text = t.name;
                                      setState(() {
                                        _matchedType = t;
                                        _showSuggestions = false;
                                      });
                                      await _refreshNextStart(t);
                                    },
                                  ),
                                  if (i != _suggestions.length - 1)
                                    Divider(
                                      height: 1,
                                      color: scheme.outlineVariant,
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        // Next-start info (read-only)
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          alignment: Alignment.topCenter,
                          child: _matchedType == null
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.maroon
                                          .withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.tag,
                                          color: AppTheme.maroon,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _loadingStart
                                              ? const Text(
                                                  'Calculating next available number…',
                                                  style:
                                                      TextStyle(fontSize: 13),
                                                )
                                              : Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Next available number',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: scheme
                                                                .onSurfaceVariant,
                                                          ),
                                                    ),
                                                    Text(
                                                      '$_prefix-'
                                                      '${_nextStart.toString().padLeft(3, '0')}',
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontFamily: 'monospace',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ---- Units ----
                    _section(
                      icon: Icons.inventory_2_outlined,
                      title: 'Units to add',
                      subtitle: 'Numbers continue from the next available.',
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
                                  'Quantity *',
                                  hint: 'How many to create',
                                ),
                                validator: (v) {
                                  final n = int.tryParse(v?.trim() ?? '');
                                  if (n == null || n <= 0) {
                                    return 'Enter a number ≥ 1';
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
                                    onPressed: _saving || _count <= 1
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
                          'Status',
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
                            helper: 'Applies to every unit created.',
                            icon: Icons.sticky_note_2_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ---- Preview ----
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
                              : _count > 0
                                  ? 'Create $_count asset${_count == 1 ? '' : 's'}'
                                  : 'Create assets',
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
          if (_prefix.isEmpty)
            hint('Enter or pick an equipment name to see the preview.')
          else if (_matchedType == null)
            hint('Pick a matching type to compute the next number.')
          else if (_loadingStart)
            hint('Calculating…')
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