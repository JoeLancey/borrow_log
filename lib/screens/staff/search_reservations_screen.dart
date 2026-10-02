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

  static const _statuses = <String?>[
    null,
    'pending',
    'approved',
    'borrowed',
    'completed',
    'rejected',
    'cancelled',
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Search failed: $e';
        _searched = true;
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
      appBar: BorrowLogAppBar(
        title: 'Search Reservations',
        actions: [
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.clear_all),
            onPressed: _clearFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          _filters(),
          const Divider(height: 1),
          Expanded(child: _resultsArea()),
        ],
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _textController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _runSearch(),
            decoration: InputDecoration(
              hintText:
                  'Search name, subject, instructor, or Property Number',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
              suffixIcon: _textController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _textController.clear();
                        setState(() {});
                      },
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: _statusFilter,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: _statuses
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s == null
                          ? 'Any status'
                          : s[0].toUpperCase() + s.substring(1)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _statusFilter = v),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(true),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _fromDate == null ? 'From date' : _fmtDate(_fromDate!),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(false),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _toDate == null ? 'To date' : _fmtDate(_toDate!),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
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
              label: Text(_loading ? 'Searching…' : 'SEARCH'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.maroon,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultsArea() {
    if (!_searched) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Enter search criteria and tap SEARCH.',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No matching reservations.',
              style: TextStyle(color: Colors.black54)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _results.length,
      itemBuilder: (_, i) => _resultCard(_results[i]),
    );
  }

  Widget _resultCard(Reservation r) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.equipmentTypeName ?? 'Equipment',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                _statusChip(r),
              ],
            ),
            const SizedBox(height: 4),
            Text('Student: ${r.studentName ?? r.studentId}'),
            Text('Subject: ${r.subject}'
                '${r.subjectCode != null ? ' (${r.subjectCode})' : ''}'),
            Text('Instructor: ${r.instructor}'),
            Text('Use: ${r.useDateFormatted}'
                '${r.useTime != null ? ' · ${r.useTime}' : ''}'),
            if (r.dueDateFormatted != null)
              Text('Due: ${r.dueDateFormatted}'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BorrowerSlipScreen(reservationId: r.id),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long, size: 18),
                label: const Text('View slip'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(Reservation r) {
    Color color;
    String label = r.statusLabel;
    if (r.isOverdue) {
      color = Colors.red;
      label = 'Overdue';
    } else {
      switch (r.status) {
        case 'pending':
          color = Colors.orange;
          break;
        case 'approved':
          color = Colors.green;
          break;
        case 'rejected':
          color = Colors.red;
          break;
        case 'borrowed':
          color = Colors.blue;
          break;
        case 'completed':
          color = Colors.teal;
          break;
        case 'cancelled':
          color = Colors.grey;
          break;
        default:
          color = Colors.grey;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}