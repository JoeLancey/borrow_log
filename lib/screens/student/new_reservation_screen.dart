import 'package:flutter/material.dart';

import '../../models/equipment_type.dart';
import '../../models/laboratory.dart';
import '../../models/reservation_item.dart';
import '../../services/inventory_service.dart';
import '../../services/laboratory_service.dart';
import '../../services/reservation_service.dart';
import '../../theme/app_theme.dart';

class NewReservationScreen extends StatefulWidget {
  final String? preselectedLaboratoryId;
  final String? preselectedTypeId;

  const NewReservationScreen({
    super.key,
    this.preselectedLaboratoryId,
    this.preselectedTypeId,
  });

  @override
  State<NewReservationScreen> createState() => _NewReservationScreenState();
}

/// One row in the "Items to reserve" list.
class _DraftItem {
  final EquipmentType type;
  int quantity;
  _DraftItem({required this.type, this.quantity = 1});
}

class _NewReservationScreenState extends State<NewReservationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _subjectCodeController = TextEditingController();
  final _instructorController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _notesController = TextEditingController();

  final _inventoryService = InventoryService();
  final _labService = LaboratoryService();
  final _reservationService = ReservationService();

  List<Laboratory> _labs = [];
  List<EquipmentType> _typesForLab = [];
  Laboratory? _selectedLab;

  /// Working item currently being added (dropdown + quantity picker).
  EquipmentType? _pendingType;
  int _pendingQuantity = 1;

  /// Items the student has already added to this reservation.
  final List<_DraftItem> _items = [];

  DateTime? _useDate;

  bool _loading = true;
  bool _loadingTypes = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLabs();
  }

  Future<void> _loadLabs() async {
    try {
      final labs = await _labService.fetchMyAccessibleLaboratories();
      if (!mounted) return;

      Laboratory? preselected;
      if (widget.preselectedLaboratoryId != null) {
        preselected = labs.firstWhere(
          (l) => l.id == widget.preselectedLaboratoryId,
          orElse: () => labs.isEmpty
              ? Laboratory(id: '', name: '', building: '', department: '')
              : labs.first,
        );
        if (preselected.id.isEmpty) preselected = null;
      }

      setState(() {
        _labs = labs;
        _selectedLab = preselected;
        _loading = false;
      });

      if (preselected != null) {
        await _loadTypesForLab(preselected.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load laboratories: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadTypesForLab(String labId) async {
    setState(() {
      _loadingTypes = true;
      _typesForLab = [];
      _pendingType = null;
      _items.clear();
    });

    try {
      final types = await _inventoryService.fetchTypesForLab(labId);
      if (!mounted) return;

      EquipmentType? preselected;
      if (widget.preselectedTypeId != null) {
        preselected = types.firstWhere(
          (t) => t.id == widget.preselectedTypeId,
          orElse: () => types.isEmpty
              ? EquipmentType(id: '', name: '')
              : types.first,
        );
        if (preselected.id.isEmpty) preselected = null;
      }

      setState(() {
        _typesForLab = types;
        _pendingType = preselected;
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

  @override
  void dispose() {
    _subjectController.dispose();
    _subjectCodeController.dispose();
    _instructorController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _useDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _useDate = picked;
        _dateController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _addItem() {
    if (_pendingType == null) {
      setState(() => _error = 'Please choose an equipment type first.');
      return;
    }

    // If already added, just bump quantity.
    final existingIndex =
        _items.indexWhere((i) => i.type.id == _pendingType!.id);

    setState(() {
      if (existingIndex >= 0) {
        _items[existingIndex].quantity += _pendingQuantity;
      } else {
        _items.add(
          _DraftItem(type: _pendingType!, quantity: _pendingQuantity),
        );
      }
      _pendingType = null;
      _pendingQuantity = 1;
      _error = null;
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLab == null) {
      setState(() => _error = 'Please select a laboratory.');
      return;
    }
    if (_items.isEmpty) {
      setState(() => _error = 'Please add at least one equipment item.');
      return;
    }
    if (_useDate == null) {
      setState(() => _error = 'Please select a date of use.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Build ReservationItem objects for the service.
      // The service only needs equipmentTypeId + quantityRequested.
      // We reuse the ReservationItem class; id/reservationId are filled
      // with placeholders because the DB generates them.
      final items = _items
          .map((d) => ReservationItem(
                id: '',
                reservationId: '',
                equipmentTypeId: d.type.id,
                quantityRequested: d.quantity,
                equipmentTypeName: d.type.name,
              ))
          .toList();

      await _reservationService.createReservation(
        items: items,
        laboratoryId: _selectedLab!.id,
        subject: _subjectController.text.trim(),
        subjectCode: _subjectCodeController.text.trim().isEmpty
            ? null
            : _subjectCodeController.text.trim(),
        instructor: _instructorController.text.trim(),
        useDate: _useDate!,
        useTime: _timeController.text.trim().isEmpty
            ? null
            : _timeController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Failed to submit: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('New Reservation')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_labs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('New Reservation')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Your account has no laboratory access. '
              'Please contact the laboratory staff.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('New Reservation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---------------- Laboratory ----------------
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
                    : (v) {
                        setState(() => _selectedLab = v);
                        if (v != null) _loadTypesForLab(v.id);
                      },
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              _sectionHeading('Equipment'),
              const SizedBox(height: 12),

              if (_loadingTypes)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else ...[
                DropdownButtonFormField<EquipmentType>(
                  initialValue: _pendingType,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Equipment type',
                    hintText: _selectedLab == null
                        ? 'Choose a laboratory first'
                        : 'Select equipment',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.inventory_2_outlined),
                    helperText: _selectedLab == null
                        ? 'Choose a laboratory to enable equipment selection.'
                        : null,
                  ),
                  items: _typesForLab
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              t.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: _saving || _selectedLab == null
                      ? null
                      : (v) => setState(() => _pendingType = v),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    const Text('Quantity', style: TextStyle(fontSize: 15)),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _saving || _pendingQuantity <= 1
                          ? null
                          : () => setState(() => _pendingQuantity--),
                    ),
                    Text(
                      '$_pendingQuantity',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _saving
                          ? null
                          : () => setState(() => _pendingQuantity++),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _saving || _pendingType == null ? null : _addItem,
                      icon: const Icon(Icons.add),
                      label: const Text('ADD'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.maroon,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'No items added yet. Pick an equipment type and press ADD.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (int i = 0; i < _items.length; i++)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(_items[i].type.name),
                            subtitle: Text('Quantity: ${_items[i].quantity}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed:
                                  _saving ? null : () => _removeItem(i),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
              const SizedBox(height: 24),

              _sectionHeading('Class details'),
              const SizedBox(height: 12),

              TextFormField(
                controller: _subjectController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Subject *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.subject_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _subjectCodeController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Subject Code',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.code_outlined),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _instructorController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Instructor *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 24),

              _sectionHeading('Schedule'),
              const SizedBox(height: 12),

              TextFormField(
                readOnly: true,
                enabled: !_saving,
                onTap: _saving ? null : _pickDate,
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Date of Use *',
                  hintText: 'Pick a date',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                validator: (v) => _useDate == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _timeController,
                enabled: !_saving,
                keyboardType: TextInputType.datetime,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Time of Use',
                  hintText: 'e.g. 13:00-15:00',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time_outlined),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notesController,
                enabled: !_saving,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Purpose / Notes',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.maroon,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('SUBMIT REQUEST'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeading(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }
}