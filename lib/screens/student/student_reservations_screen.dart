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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel reservation?'),
        content: Text(
            'Cancel reservation for ${r.equipmentTypeName ?? 'equipment'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, cancel'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Cancel failed: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F4),
      appBar: AppBar(
        title: const Text('My Reservations'),
        actions: [
          PopupMenuButton<bool>(
            tooltip: 'Sort reservations',
            icon: const Icon(Icons.sort),
            initialValue: _newestFirst,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (newestFirst) =>
                setState(() => _newestFirst = newestFirst),
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: true,
                checked: _newestFirst,
                child: const Text('Newest first'),
              ),
              CheckedPopupMenuItem(
                value: false,
                checked: !_newestFirst,
                child: const Text('Oldest first'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newReservation,
        backgroundColor: AppTheme.maroon,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New reservation'),
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
          return Column(
            children: [
              _filterBar(list),
              Expanded(
                child: RefreshIndicator(
                  color: AppTheme.maroon,
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      if (visible.isEmpty)
                        _noMatches()
                      else ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 6, 2, 2),
                          child: Text(
                            '${visible.length} '
                            '${visible.length == 1 ? 'reservation' : 'reservations'}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        ...visible.map(_card),
                      ],
                    ],
                  ),
                ),
              ),
            ],
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

  int _countFor(String key, List<Reservation> all) {
    if (key == 'all') return all.length;
    if (key == 'overdue') return all.where((r) => r.isOverdue).length;
    return all.where((r) => r.status == key).length;
  }

  // ───────────────────────── Filter bar ─────────────────────────

  Widget _filterBar(List<Reservation> all) {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black26,
      child: SizedBox(
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemCount: _filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final filter = _filters[i];
            final selected = _statusFilter == filter.$1;
            final count = _countFor(filter.$1, all);
            return ChoiceChip(
              label: Text('${filter.$2} $count'),
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
              onSelected: (_) => setState(() => _statusFilter = filter.$1),
            );
          },
        ),
      ),
    );
  }

  // ───────────────────────── Empty states ─────────────────────────

  Widget _noMatches() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Column(
        children: [
          const Icon(Icons.filter_list_off, size: 48, color: Colors.black38),
          const SizedBox(height: 12),
          const Text(
            'No reservations match this filter',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _statusFilter = 'all'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.maroon),
            child: const Text('Show all'),
          ),
        ],
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.maroon.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_note_outlined,
                  size: 44, color: AppTheme.maroon),
            ),
            const SizedBox(height: 16),
            const Text('No reservations yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Request laboratory equipment and it will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _newReservation,
              icon: const Icon(Icons.add),
              label: const Text('New reservation'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.maroon,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Card ─────────────────────────

  Color _accentFor(Reservation r) {
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
      default:
        return Colors.grey;
    }
  }

  Widget _card(Reservation r) {
    final overdue = r.isOverdue;
    final subjectLine = '${r.subject}'
        '${r.subjectCode != null ? ' (${r.subjectCode})' : ''}';
    final useLine = '${r.useDateFormatted}'
        '${r.useTime != null ? ' at ${r.useTime}' : ''}';

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0x14000000)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: _accentFor(r)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
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
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _statusChip(r, overdue),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _infoRow(Icons.inventory_2_outlined,
                        'Quantity: ${r.quantityRequested}'),
                    _infoRow(Icons.menu_book_outlined, subjectLine),
                    _infoRow(Icons.school_outlined, r.instructor),
                    _infoRow(Icons.event_outlined, useLine),
                    if (r.dueDateFormatted != null)
                      _infoRow(
                        Icons.assignment_return_outlined,
                        'Due ${r.dueDateFormatted}'
                        '${overdue ? ' · Overdue' : ''}',
                        color: overdue ? Colors.red : null,
                        bold: overdue,
                      ),
                    if (r.status == 'borrowed' &&
                        !overdue &&
                        r.dueDate != null)
                      _callout(
                        Icons.timer_outlined,
                        r.daysUntilDue == 0
                            ? 'Due today'
                            : '${r.daysUntilDue} day(s) until due',
                        Colors.orange,
                      ),
                    if (r.rejectionReason != null)
                      _callout(
                        Icons.info_outline,
                        'Reason: ${r.rejectionReason}',
                        Colors.red,
                      ),
                    if (r.status == 'pending')
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _cancel(r),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Cancel request'),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text,
      {Color? color, bool bold = false}) {
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
                color: color ?? Colors.black87,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _callout(IconData icon, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(Reservation r, bool overdue) =>
      BorrowLogStatusChip.reservation(r.status, overdue: overdue);
}