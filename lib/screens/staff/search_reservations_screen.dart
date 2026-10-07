import 'package:flutter/material.dart';

import '../../models/reservation.dart';
import '../../services/reservation_service.dart';
import '../../features/reservations/domain/reservation_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/borrow_log_app_bar.dart';
import '../shared/borrower_slip_screen.dart';

class SearchReservationsScreen extends StatefulWidget {
  const SearchReservationsScreen({super.key});

  @override
  State<SearchReservationsScreen> createState() =>
      _SearchReservationsScreenState();
}

class _SearchReservationsScreenState extends State<SearchReservationsScreen> {
  final ReservationRepository _service = ReservationService();
  final _textController = TextEditingController();

  String? _statusFilter;
  DateTime? _fromDate;
  DateTime? _toDate;

  bool _loading = false;
  bool _searched = false;
  String? _error;
  List<Reservation> _results = [];

  // UI-only: whether the filter panel is expanded.
  bool _filtersExpanded = true;

  static const _statuses = <String?>[
    null,
    'pending',
    'approved',
    'borrowed',
    'completed',
    'rejected',
    'cancelled',
  ];

  bool get _hasActiveFilters =>
      _textController.text.trim().isNotEmpty ||
      _statusFilter != null ||
      _fromDate != null ||
      _toDate != null;

  int get _activeFilterCount =>
      (_statusFilter != null ? 1 : 0) +
      (_fromDate != null ? 1 : 0) +
      (_toDate != null ? 1 : 0);

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final text = _textController.text.trim();

      // If the text looks like a Property Number (e.g. ARD-001), also try PN lookup
      List<Reservation> results;
      final pnPattern = RegExp(r'^[A-Za-z]{2,6}-\d{3,}$');
      if (pnPattern.hasMatch(text)) {
        results = await _service.searchByPropertyNumber(text);
      } else {
        results = await _service.searchReservations(
          text: text,
          status: _statusFilter,
          useDateFrom: _fromDate,
          useDateTo: _toDate,
        );
      }

      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        _searched = true;
        _filtersExpanded = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Search failed: $e';
        _searched = true;
        _filtersExpanded = false;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _textController.clear();
      _statusFilter = null;
      _fromDate = null;
      _toDate = null;
      _results = [];
      _searched = false;
      _error = null;
      _filtersExpanded = true;
    });
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final initial = isFrom
        ? (_fromDate ?? now.subtract(const Duration(days: 30)))
        : (_toDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365 * 3)),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F4),
      appBar: BorrowLogAppBar(
        title: 'Search Reservations',
        actions: [
          IconButton(
            tooltip: 'Reset search',
            icon: const Icon(Icons.restart_alt),
            onPressed: _hasActiveFilters || _searched ? _clearFilters : null,
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            _filters(),
            Expanded(child: _resultsArea()),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // Filters
  // ---------------------------------------------------------

  Widget _filters() {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _searchField(),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _filtersExpanded
                  ? _expandedFilters()
                  : _collapsedSummary(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _textController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _runSearch(),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Name, subject, instructor or Property No.',
        hintStyle: const TextStyle(fontSize: 14, color: Colors.black45),
        prefixIcon: const Icon(Icons.search, color: Colors.black54),
        filled: true,
        fillColor: const Color(0xFFF3F1F0),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.maroon, width: 1.5),
        ),
        suffixIcon: _textController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear text',
                icon: const Icon(Icons.cancel, size: 20),
                color: Colors.black38,
                onPressed: () {
                  _textController.clear();
                  setState(() {});
                },
              ),
      ),
    );
  }

  Widget _collapsedSummary() {
    final parts = <String>[
      if (_statusFilter != null) _capitalize(_statusFilter!),
      if (_fromDate != null) 'From ${_fmtDate(_fromDate!)}',
      if (_toDate != null) 'To ${_fmtDate(_toDate!)}',
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              parts.isEmpty ? 'No filters applied' : parts.join('  •  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _filtersExpanded = true),
            icon: Badge(
              isLabelVisible: _activeFilterCount > 0,
              label: Text('$_activeFilterCount'),
              backgroundColor: AppTheme.maroon,
              child: const Icon(Icons.tune, size: 18),
            ),
            label: const Text('Filters'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.maroon),
          ),
        ],
      ),
    );
  }

  Widget _expandedFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        _sectionLabel('Status'),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _statuses.length,
            // ✅ FIXED: (_, _) instead of (_, __)
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final s = _statuses[i];
              final selected = _statusFilter == s;
              return ChoiceChip(
                label: Text(s == null ? 'Any' : _capitalize(s)),
                selected: selected,
                showCheckmark: false,
                selectedColor: AppTheme.maroon,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selected ? AppTheme.maroon : Colors.black12,
                ),
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
                onSelected: (_) => setState(() => _statusFilter = s),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        _sectionLabel('Date of use'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _dateButton('From', _fromDate, true)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, size: 16, color: Colors.black38),
            ),
            Expanded(child: _dateButton('To', _toDate, false)),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: _loading ? null : _runSearch,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.search),
            label: Text(
              _loading ? 'Searching…' : 'Search',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.maroon,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
        ),
      );

  Widget _dateButton(String label, DateTime? value, bool isFrom) {
    final hasValue = value != null;
    return OutlinedButton(
      onPressed: () => _pickDate(isFrom),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.only(left: 12, right: 4),
        foregroundColor: hasValue ? AppTheme.maroon : Colors.black54,
        side: BorderSide(
          color: hasValue ? AppTheme.maroon : Colors.black26,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasValue ? _fmtDate(value) : label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.left,
            ),
          ),
          if (hasValue)
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() {
                if (isFrom) {
                  _fromDate = null;
                } else {
                  _toDate = null;
                }
              }),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.close, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Results
  // ---------------------------------------------------------

  Widget _resultsArea() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.maroon),
      );
    }
    if (!_searched) {
      return _message(
        icon: Icons.manage_search,
        title: 'Find a reservation',
        body:
            'Search by student, subject, instructor or Property Number, then narrow it down with filters.',
      );
    }
    if (_error != null) {
      return _message(
        icon: Icons.error_outline,
        iconColor: Colors.red,
        title: 'Something went wrong',
        body: _error!,
        action: OutlinedButton.icon(
          onPressed: _runSearch,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.maroon),
        ),
      );
    }
    if (_results.isEmpty) {
      return _message(
        icon: Icons.search_off,
        title: 'No matching reservations',
        body: 'Check the spelling or loosen your filters.',
        action: _hasActiveFilters
            ? TextButton(
                onPressed: _clearFilters,
                style: TextButton.styleFrom(foregroundColor: AppTheme.maroon),
                child: const Text('Reset search'),
              )
            : null,
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _results.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
            child: Text(
              '${_results.length} ${_results.length == 1 ? 'reservation' : 'reservations'} found',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          );
        }
        return _resultCard(_results[i - 1]);
      },
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String body,
    Color iconColor = Colors.black38,
    Widget? action,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: iconColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, height: 1.4),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultCard(Reservation r) {
    final accent = _statusColor(r);
    final useLine = '${r.useDateFormatted}'
        '${r.useTime != null ? ' at ${r.useTime}' : ''}';
    final subjectLine = '${r.subject}'
        '${r.subjectCode != null ? ' (${r.subjectCode})' : ''}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0x14000000)),
      ),
      child: InkWell(
        onTap: () => _openSlip(r),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                r.equipmentTypeName ?? 'Equipment',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _statusChip(r),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // ✅ FIXED: removed pointless string interpolation
                      _infoRow(Icons.person_outline,
                          r.studentName ?? r.studentId),
                      _infoRow(Icons.menu_book_outlined, subjectLine),
                      _infoRow(Icons.school_outlined, r.instructor),
                      _infoRow(Icons.event_outlined, useLine),
                      if (r.dueDateFormatted != null)
                        _infoRow(
                          Icons.assignment_return_outlined,
                          'Due ${r.dueDateFormatted}',
                          color: r.isOverdue ? Colors.red : null,
                          bold: r.isOverdue,
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _openSlip(r),
                          icon: const Icon(Icons.receipt_long, size: 18),
                          label: const Text('View slip'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.maroon,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSlip(Reservation r) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BorrowerSlipScreen(reservationId: r.id),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? color, bool bold = false}) {
    final c = color ?? Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color ?? Colors.black45),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.25,
                color: c,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(Reservation r) {
    if (r.isOverdue) return Colors.red;
    switch (r.status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'borrowed':
        return Colors.blue;
      case 'completed':
        return Colors.teal;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _statusChip(Reservation r) {
    final color = _statusColor(r);
    final label = r.isOverdue ? 'Overdue' : r.statusLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}