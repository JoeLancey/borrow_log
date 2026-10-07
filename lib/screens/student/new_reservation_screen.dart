import 'package:flutter/material.dart';

import '../../models/equipment_type.dart';
import '../../models/laboratory.dart';
import '../../models/reservation_item.dart';
import '../../services/inventory_service.dart';
import '../../services/laboratory_service.dart';
import '../../services/reservation_service.dart';
import '../../features/reservations/domain/reservation_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_feedback.dart';

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
  final ReservationRepository _reservationService = ReservationService();

  List<Laboratory> _labs = [];
  List<EquipmentType> _typesForLab = [];
  Laboratory? _selectedLab;

  EquipmentType? _pendingType;
  int _pendingQuantity = 1;

  final List<_DraftItem> _items = [];

  DateTime? _useDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

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
      // ignore: avoid_print
      print('📋 [new-reservation] load labs failed: $e');
      setState(() {
        _error = 'Could not load laboratories. Please try again.';
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
      // ignore: avoid_print
      print('📋 [new-reservation] load types failed: $e');
      setState(() {
        _error = 'Could not load equipment. Please try again.';
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
      helpText: 'Select date of use',
    );
    if (picked != null) {
      setState(() {
        _useDate = picked;
        _dateController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  String _fmt24(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmtDisplay(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  void _syncTimeText() {
    if (_startTime != null && _endTime != null) {
      _timeController.text = '${_fmt24(_startTime!)}-${_fmt24(_endTime!)}';
    } else if (_startTime != null) {
      _timeController.text = _fmt24(_startTime!);
    } else if (_endTime != null) {
      _timeController.text = _fmt24(_endTime!);
    } else {
      _timeController.text = '';
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final fallbackStart = const TimeOfDay(hour: 8, minute: 0);
    final fallbackEnd = _startTime != null
        ? TimeOfDay(hour: (_startTime!.hour + 1) % 24, minute: 0)
        : const TimeOfDay(hour: 9, minute: 0);

    final initial = isStart
        ? (_startTime ?? fallbackStart)
        : (_endTime ?? fallbackEnd);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isStart ? 'Select start time' : 'Select end time',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startTime = picked;
        if (_endTime != null) {
          final startMin = picked.hour * 60 + picked.minute;
          final endMin = _endTime!.hour * 60 + _endTime!.minute;
          if (endMin <= startMin) {
            _endTime = TimeOfDay(
              hour: (picked.hour + 1) % 24,
              minute: picked.minute,
            );
          }
        }
      } else {
        _endTime = picked;
        if (_startTime != null) {
          final startMin = _startTime!.hour * 60 + _startTime!.minute;
          final endMin = picked.hour * 60 + picked.minute;
          if (startMin >= endMin) {
            _startTime = TimeOfDay(
              hour: (picked.hour - 1 + 24) % 24,
              minute: picked.minute,
            );
          }
        }
      }
      _syncTimeText();
    });
  }

  void _clearTime() {
    setState(() {
      _startTime = null;
      _endTime = null;
      _timeController.text = '';
    });
  }

  String _durationLabel() {
    if (_startTime == null && _endTime == null) return '';
    if (_startTime == null || _endTime == null) {
      return 'Add the other time to see the duration.';
    }
    final startMin = _startTime!.hour * 60 + _startTime!.minute;
    final endMin = _endTime!.hour * 60 + _endTime!.minute;
    final diff = endMin - startMin;
    if (diff <= 0) return '';
    final h = diff ~/ 60;
    final m = diff % 60;
    final parts = <String>[];
    if (h > 0) parts.add('${h}h');
    if (m > 0) parts.add('${m}m');
    return 'Duration: ${parts.join(' ')}';
  }

  void _addItem() {
    if (_pendingType == null) {
      AppFeedback.info(context, 'Pick an equipment type first.');
      return;
    }

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

    AppFeedback.success(
      context,
      'Added to list · ${_items.length} '
      '${_items.length == 1 ? 'item' : 'items'}',
    );
  }

  void _removeItem(int index) {
    final removed = _items[index].type.name;
    setState(() => _items.removeAt(index));
    AppFeedback.info(context, 'Removed $removed from list.');
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('violates row-level security')) {
      return 'You do not have permission to submit this reservation.';
    }
    if (s.contains('duplicate key')) {
      return 'This reservation was already submitted.';
    }
    if (s.contains('network') ||
        s.contains('SocketException') ||
        s.contains('Failed host lookup')) {
      return 'Network error. Please check your connection and try again.';
    }
    return 'Could not submit your reservation. Please try again.';
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

      // ✅ Success toast BEFORE popping — visible on whichever screen
      //    the student lands on (My Reservations or Browse Equipment).
      AppFeedback.success(
        context,
        'Reservation submitted · ${_items.length} '
        '${_items.length == 1 ? 'item' : 'items'} · Waiting for staff approval',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('📋 [new-reservation] submit failed: $e');
      setState(() {
        _saving = false;
        _error = _friendlyError(e);
      });
    }
  }

  static const _pageBg = Color(0xFFF6F5F4);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _pageBg,
        appBar: AppBar(title: const Text('New Reservation')),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.maroon),
        ),
      );
    }

    if (_labs.isEmpty) {
      return Scaffold(
        backgroundColor: _pageBg,
        appBar: AppBar(title: const Text('New Reservation')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.maroon.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline,
                      size: 40, color: AppTheme.maroon),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No laboratory access',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your account has no laboratory access. '
                  'Please contact the laboratory staff.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(title: const Text('New Reservation')),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _section(
                  icon: Icons.meeting_room_outlined,
                  title: 'Laboratory',
                  children: [_labField()],
                ),
                const SizedBox(height: 16),
                _section(
                  icon: Icons.inventory_2_outlined,
                  title: 'Equipment',
                  trailing: _items.isEmpty ? null : _countBadge(_items.length),
                  children: _equipmentChildren(),
                ),
                const SizedBox(height: 16),
                _section(
                  icon: Icons.menu_book_outlined,
                  title: 'Class details',
                  children: _classChildren(),
                ),
                const SizedBox(height: 16),
                _section(
                  icon: Icons.event_outlined,
                  title: 'Schedule',
                  children: _scheduleChildren(),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  InputDecoration _dec(
    String label, {
    IconData? icon,
    String? hint,
    String? helper,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8F7F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.maroon, width: 1.5),
      ),
      floatingLabelStyle: const TextStyle(color: AppTheme.maroon),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.maroon),
              const SizedBox(width: 8),
              Expanded(child: _sectionHeading(title)),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _sectionHeading(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }

  Widget _countBadge(int n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.maroon.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$n ${n == 1 ? 'item' : 'items'}',
        style: const TextStyle(
          color: AppTheme.maroon,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _labField() {
    return DropdownButtonFormField<Laboratory>(
      initialValue: _selectedLab,
      isExpanded: true,
      decoration: _dec('Laboratory *', hint: 'Select a laboratory'),
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
    );
  }

  List<Widget> _equipmentChildren() {
    if (_loadingTypes) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.maroon,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      DropdownButtonFormField<EquipmentType>(
        initialValue: _pendingType,
        isExpanded: true,
        decoration: _dec(
          'Equipment type',
          icon: Icons.memory,
          hint: _selectedLab == null
              ? 'Choose a laboratory first'
              : 'Select equipment',
          helper: _selectedLab == null
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
          _quantityStepper(),
          const Spacer(),
          FilledButton.icon(
            onPressed: _saving || _pendingType == null ? null : _addItem,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add to list'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.maroon,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (_items.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7F6),
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.playlist_add, color: Colors.black38),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No items yet. Pick an equipment type, set the quantity, '
                  'then tap Add to list.',
                  style: TextStyle(color: Colors.black54, height: 1.35),
                ),
              ),
            ],
          ),
        )
      else
        Column(
          children: [for (int i = 0; i < _items.length; i++) _itemRow(i)],
        ),
    ];
  }

  Widget _quantityStepper() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Decrease quantity',
            icon: const Icon(Icons.remove),
            onPressed: _saving || _pendingQuantity <= 1
                ? null
                : () => setState(() => _pendingQuantity--),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$_pendingQuantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Increase quantity',
            icon: const Icon(Icons.add),
            onPressed:
                _saving ? null : () => setState(() => _pendingQuantity++),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(int i) {
    final item = _items[i];
    return Container(
      margin: EdgeInsets.only(bottom: i == _items.length - 1 ? 0 : 8),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.maroon.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '×${item.quantity}',
              style: const TextStyle(
                color: AppTheme.maroon,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.type.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Remove ${item.type.name}',
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _saving ? null : () => _removeItem(i),
          ),
        ],
      ),
    );
  }

  List<Widget> _classChildren() {
    return [
      TextFormField(
        controller: _subjectController,
        enabled: !_saving,
        decoration: _dec('Subject *', icon: Icons.subject_outlined),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Required' : null,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _subjectCodeController,
        enabled: !_saving,
        decoration: _dec('Subject code', icon: Icons.code_outlined),
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _instructorController,
        enabled: !_saving,
        decoration: _dec('Instructor *', icon: Icons.person_outline),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Required' : null,
        textInputAction: TextInputAction.next,
      ),
    ];
  }

  List<Widget> _scheduleChildren() {
    return [
      TextFormField(
        readOnly: true,
        enabled: !_saving,
        onTap: _saving ? null : _pickDate,
        controller: _dateController,
        decoration: _dec(
          'Date of use *',
          icon: Icons.calendar_today_outlined,
          hint: 'Pick a date',
        ),
        validator: (v) => _useDate == null ? 'Required' : null,
      ),
      const SizedBox(height: 14),
      _timeRow(),
      const SizedBox(height: 14),
      TextFormField(
        controller: _notesController,
        enabled: !_saving,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        decoration: _dec('Purpose / notes', icon: Icons.note_alt_outlined),
      ),
    ];
  }

  Widget _timeRow() {
    final hasAnyTime = _startTime != null || _endTime != null;

    final List<Widget> columnChildren = <Widget>[
      Row(
        children: [
          Expanded(
            child: _timeField(
              icon: Icons.access_time_outlined,
              label: 'Start time',
              value: _startTime,
              onTap: () => _pickTime(isStart: true),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'to',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: _timeField(
              icon: null,
              label: 'End time',
              value: _endTime,
              onTap: () => _pickTime(isStart: false),
            ),
          ),
        ],
      ),
    ];

    if (hasAnyTime) {
      columnChildren.add(const SizedBox(height: 6));
      columnChildren.add(
        Row(
          children: [
            Icon(
              Icons.timelapse,
              size: 14,
              color: Colors.black.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _durationLabel(),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            TextButton.icon(
              onPressed: _saving ? null : _clearTime,
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      );
    } else {
      columnChildren.add(
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Optional. Leave blank if unsure.',
            style: TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: columnChildren,
    );
  }

  Widget _timeField({
    required IconData? icon,
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _saving ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _dec(label, icon: icon),
        child: Text(
          value != null ? _fmtDisplay(value) : 'Tap to pick',
          style: TextStyle(
            fontSize: 15,
            fontWeight: value != null ? FontWeight.w600 : FontWeight.w400,
            color: value != null ? Colors.black87 : Colors.black38,
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black38,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
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
                      : Text(
                          _items.isEmpty
                              ? 'Submit request'
                              : 'Submit request  •  '
                                  '${_items.length} ${_items.length == 1 ? 'item' : 'items'}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}