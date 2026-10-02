import 'package:flutter/material.dart';

import '../../models/reservation.dart';
import '../../services/reservation_service.dart';
import '../../features/reservations/domain/reservation_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/borrow_log_states.dart';
import 'new_reservation_screen.dart';

class StudentReservationsScreen extends StatefulWidget {
  const StudentReservationsScreen({super.key});

  @override
  State<StudentReservationsScreen> createState() =>
      _StudentReservationsScreenState();
}

class _StudentReservationsScreenState
    extends State<StudentReservationsScreen> {
  final ReservationRepository _service = ReservationService();
  late Future<List<Reservation>> _future;
  String _statusFilter = 'all';
  bool _newestFirst = true;

  static const _filters = [
    ('all', 'All'),
    ('pending', 'Pending'),
    ('approved', 'Approved'),
    ('borrowed', 'Borrowed'),
    ('overdue', 'Overdue'),
    ('completed', 'Completed'),
  ];

  @override
  void initState() {
    super.initState();
    _future = _service.fetchMyReservations();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _service.fetchMyReservations();
    });
  }

  Future<void> _newReservation() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NewReservationScreen()),
    );
    if (created == true && mounted) await _refresh();
  }

  Future<void> _cancel(Reservation r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel reservation?'),
        content: Text(
            'Cancel reservation for ${r.equipmentTypeName ?? 'equipment'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    try {
      await _service.cancelReservation(r.id);
      if (!mounted) return;
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reservations'),
        actions: [
          PopupMenuButton<bool>(
            tooltip: 'Sort reservations',
            initialValue: _newestFirst,
            onSelected: (newestFirst) =>
                setState(() => _newestFirst = newestFirst),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: true,
                child: Text('Newest first'),
              ),
              PopupMenuItem(
                value: false,
                child: Text('Oldest first'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'New reservation',
            icon: const Icon(Icons.add),
            onPressed: _newReservation,
          ),
        ],
      ),
      body: FutureBuilder<List<Reservation>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const BorrowLogSkeletonList();
          }
          if (snap.hasError) {
            return BorrowLogErrorState(
              message: 'Failed to load reservations:\n${snap.error}',
              onRetry: _refresh,
            );
          }
          final list = snap.data ?? [];
          if (list.isEmpty) return _emptyView();
          final visible = _visibleReservations(list);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _filterBar(),
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No reservations match this filter.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ...visible.map(_card),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Reservation> _visibleReservations(List<Reservation> reservations) {
    final visible = reservations.where((reservation) {
      if (_statusFilter == 'all') return true;
      if (_statusFilter == 'overdue') return reservation.isOverdue;
      return reservation.status == _statusFilter;
    }).toList();

    visible.sort((a, b) {
      final aDate = a.createdAt ?? a.useDate;
      final bDate = b.createdAt ?? b.useDate;
      final result = aDate.compareTo(bDate);
      return _newestFirst ? -result : result;
    });
    return visible;
  }

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final filter in _filters) ...[
              ChoiceChip(
                label: Text(filter.$2),
                selected: _statusFilter == filter.$1,
                onSelected: (_) => setState(() => _statusFilter = filter.$1),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_note_outlined,
                size: 64, color: AppTheme.maroon),
            const SizedBox(height: 16),
            const Text('No reservations yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Tap the + button to submit a new reservation request.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _newReservation,
              icon: const Icon(Icons.add),
              label: const Text('New Reservation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.maroon,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Reservation r) {
    final overdue = r.isOverdue;
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
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                _statusChip(r, overdue),
              ],
            ),
            const SizedBox(height: 6),
            Text('Qty: ${r.quantityRequested}'),
            Text('Subject: ${r.subject}'
                '${r.subjectCode != null ? ' (${r.subjectCode})' : ''}'),
            Text('Instructor: ${r.instructor}'),
            Text('Use: ${r.useDateFormatted}'
                '${r.useTime != null ? ' · ${r.useTime}' : ''}'),
            if (r.dueDateFormatted != null)
              Text(
                'Due: ${r.dueDateFormatted}'
                '${overdue ? ' · OVERDUE' : ''}',
                style: TextStyle(
                  color: overdue ? Colors.red : null,
                  fontWeight: overdue ? FontWeight.bold : null,
                ),
              ),
            if (r.status == 'borrowed' && !overdue && r.dueDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  r.daysUntilDue == 0
                      ? 'Due today'
                      : '${r.daysUntilDue} day(s) until due',
                  style: const TextStyle(
                      color: Colors.orange,
                      fontStyle: FontStyle.italic),
                ),
              ),
            if (r.rejectionReason != null) ...[
              const SizedBox(height: 6),
              Text('Reason: ${r.rejectionReason}',
                  style: const TextStyle(color: Colors.red)),
            ],
            if (r.status == 'pending') ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _cancel(r),
                  icon: const Icon(Icons.cancel_outlined,
                      size: 18, color: Colors.red),
                  label: const Text('Cancel',
                      style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(Reservation r, bool overdue) =>
      BorrowLogStatusChip.reservation(r.status, overdue: overdue);
}