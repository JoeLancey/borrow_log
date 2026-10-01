import 'package:flutter/material.dart';

import '../../models/equipment_asset.dart';
import '../../models/reservation.dart';
import '../../models/reservation_asset.dart';
import '../../services/inventory_service.dart';
import '../../services/reservation_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/borrow_log_states.dart';
import '../shared/borrower_slip_screen.dart';

class StaffReservationsScreen extends StatefulWidget {
  const StaffReservationsScreen({super.key});

  @override
  State<StaffReservationsScreen> createState() =>
      _StaffReservationsScreenState();
}

class _StaffReservationsScreenState extends State<StaffReservationsScreen>
    with SingleTickerProviderStateMixin {
  final _service = ReservationService();
  late TabController _tabController;
  late Future<List<Reservation>> _future;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _future = _service.fetchAllReservations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _service.fetchAllReservations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'Overdue'),
            Tab(text: 'History'),
          ],
        ),
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
          final all = snap.data ?? [];
          final pending = all.where((r) => r.status == 'pending').toList();
          final active = all
              .where((r) => r.isActive && !r.isOverdue)
              .toList();
          final overdue = all.where((r) => r.isOverdue).toList();
          final history = all
              .where((r) =>
                  r.status == 'completed' ||
                  r.status == 'rejected' ||
                  r.status == 'cancelled')
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _listView(pending, empty: 'No pending requests.'),
              _listView(active, empty: 'No active reservations.'),
              _listView(overdue, empty: 'No overdue equipment.'),
              _listView(history, empty: 'No history yet.'),
            ],
          );
        },
      ),
    );
  }

  Widget _listView(List<Reservation> items, {required String empty}) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(empty, style: const TextStyle(color: Colors.black54)),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (_, i) => _card(items[i]),
      ),
    );
  }

  Widget _card(Reservation r) {
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
                _statusChip(r),
              ],
            ),
            const SizedBox(height: 4),
            Text('Student: ${r.studentName ?? r.studentId}'),
            Text('Qty: ${r.quantityRequested}'),
            Text('Subject: ${r.subject}'
                '${r.subjectCode != null ? ' (${r.subjectCode})' : ''}'),
            Text('Instructor: ${r.instructor}'),
            Text('Use: ${r.useDateFormatted}'
                '${r.useTime != null ? ' · ${r.useTime}' : ''}'),
            if (r.dueDateFormatted != null)
              Text('Due: ${r.dueDateFormatted}',
                  style: TextStyle(
                    color: r.isOverdue ? Colors.red : null,
                    fontWeight: r.isOverdue ? FontWeight.bold : null,
                  )),
            if (r.rejectionReason != null)
              Text('Reason: ${r.rejectionReason}',
                  style: const TextStyle(color: Colors.red)),

            // Actions
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BorrowerSlipScreen(
                          reservationId: r.id,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('View slip'),
                ),
                if (r.status == 'pending') ...[
                  TextButton.icon(
                    onPressed: () => _showRejectDialog(r),
                    icon: const Icon(Icons.close,
                        color: Colors.red, size: 18),
                    label: const Text('Reject',
                        style: TextStyle(color: Colors.red)),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showApproveDialog(r),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.maroon,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else if (r.status == 'approved') ...[
                  ElevatedButton.icon(
                    onPressed: () => _showReleaseDialog(r),
                    icon: const Icon(Icons.assignment_turned_in_outlined,
                        size: 18),
                    label: const Text('Release'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.maroon,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else if (r.status == 'borrowed') ...[
                  ElevatedButton.icon(
                    onPressed: () => _showReturnDialog(r),
                    icon:
                        const Icon(Icons.assignment_return_outlined, size: 18),
                    label: const Text('Receive return'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.maroon,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(Reservation r) {
    return BorrowLogStatusChip.reservation(r.status, overdue: r.isOverdue);
  }

  // ---------------------------------------------------------
  // APPROVE DIALOG
  // ---------------------------------------------------------

  Future<void> _showApproveDialog(Reservation r) async {
    final inventoryService = InventoryService();

    List<EquipmentAsset> available;
    try {
      final all = await inventoryService.fetchAssetsForType(r.equipmentTypeId);
      available = all.where((a) => a.status == 'available').toList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load assets: $e')),
      );
      return;
    }

    if (!mounted) return;

    if (available.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No available assets'),
          content: Text(
            'There are no available units of '
            '"${r.equipmentTypeName ?? 'this equipment'}".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final selected = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => _AssetPickerDialog(
        reservation: r,
        available: available,
      ),
    );

    if (selected == null) return;
    if (!mounted) return;

    if (selected.length != r.quantityRequested) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Quantity mismatch'),
          content: Text(
            'You must select exactly ${r.quantityRequested} property number(s).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      await _service.approveReservation(
        reservationId: r.id,
        assetIds: selected,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation approved.')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approve failed: $e')),
      );
    }
  }

  // ---------------------------------------------------------
  // REJECT DIALOG
  // ---------------------------------------------------------

  Future<void> _showRejectDialog(Reservation r) async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject reservation?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Rejecting request from ${r.studentName ?? 'the student'}.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Reject',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      await _service.rejectReservation(
        reservationId: r.id,
        reason: controller.text.trim(),
      );
      if (!mounted) return;
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reject failed: $e')),
      );
    }
  }

  // ---------------------------------------------------------
  // RELEASE DIALOG
  // ---------------------------------------------------------

  Future<void> _showReleaseDialog(Reservation r) async {
    DateTime? dueDate;

    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('Release equipment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Releasing ${r.quantityRequested} unit(s) of '
                  '"${r.equipmentTypeName ?? 'equipment'}" to '
                  '${r.studentName ?? 'the student'}.',
                ),
                const SizedBox(height: 16),
                const Text('Select due date *',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: dueDate ??
                          now.add(const Duration(days: 1)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 90)),
                    );
                    if (picked != null) {
                      setLocal(() => dueDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    dueDate == null
                        ? 'Pick due date'
                        : '${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: dueDate == null
                    ? null
                    : () => Navigator.pop(ctx, dueDate),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.maroon,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Release'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;
    if (!mounted) return;

    try {
      await _service.releaseReservation(
        reservationId: r.id,
        dueDate: result,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Equipment released.')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Release failed: $e')),
      );
    }
  }

  // ---------------------------------------------------------
  // RETURN DIALOG
  // ---------------------------------------------------------

  Future<void> _showReturnDialog(Reservation r) async {
    List<ReservationAsset> links;
    try {
      links = await _service.fetchReservationAssets(r.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load assets: $e')),
      );
      return;
    }

    if (!mounted) return;

    if (links.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No assets assigned to this reservation.')),
      );
      return;
    }

    final result = await showDialog<Map<String, _ReturnEntry>>(
      context: context,
      builder: (ctx) => _ReturnDialog(
        reservation: r,
        links: links,
      ),
    );

    if (result == null) return;
    if (!mounted) return;

    try {
      for (final link in links) {
        final entry = result[link.id];
        if (entry == null) continue;
        await _service.recordAssetReturn(
          reservationAssetId: link.id,
          equipmentAssetId: link.equipmentAssetId,
          condition: entry.condition,
          notes: entry.notes,
        );
      }
      await _service.completeReservation(r.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Return recorded. Reservation completed.')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Return failed: $e')),
      );
    }
  }
}

// =========================================================
// ASSET PICKER DIALOG (approve)
// =========================================================

class _AssetPickerDialog extends StatefulWidget {
  final Reservation reservation;
  final List<EquipmentAsset> available;

  const _AssetPickerDialog({
    required this.reservation,
    required this.available,
  });

  @override
  State<_AssetPickerDialog> createState() => _AssetPickerDialogState();
}

class _AssetPickerDialogState extends State<_AssetPickerDialog> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final needed = widget.reservation.quantityRequested;

    return AlertDialog(
      title: const Text('Assign Property Numbers'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select exactly $needed unit(s) of '
              '"${widget.reservation.equipmentTypeName ?? 'equipment'}".',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Selected: ${_selected.length} / $needed',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _selected.length == needed
                    ? Colors.green
                    : Colors.orange.shade800,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.available.length,
                itemBuilder: (_, i) {
                  final a = widget.available[i];
                  final isSelected = _selected.contains(a.id);
                  return CheckboxListTile(
                    dense: true,
                    value: isSelected,
                    title: Text(a.propertyNumber),
                    subtitle: a.conditionNotes != null
                        ? Text(a.conditionNotes!)
                        : null,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          if (_selected.length >= needed) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'You only need $needed unit(s).'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                            return;
                          }
                          _selected.add(a.id);
                        } else {
                          _selected.remove(a.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selected.length == needed
              ? () => Navigator.pop(context, _selected.toList())
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.maroon,
            foregroundColor: Colors.white,
          ),
          child: const Text('Approve'),
        ),
      ],
    );
  }
}

// =========================================================
// RETURN DIALOG
// =========================================================

class _ReturnEntry {
  String condition = 'good'; // 'good' | 'damaged' | 'lost'
  String? notes;
}

class _ReturnDialog extends StatefulWidget {
  final Reservation reservation;
  final List<ReservationAsset> links;

  const _ReturnDialog({
    required this.reservation,
    required this.links,
  });

  @override
  State<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<_ReturnDialog> {
  late final Map<String, _ReturnEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = {
      for (final l in widget.links) l.id: _ReturnEntry(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Receive return'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Record the condition of each Property Number returned by '
              '${widget.reservation.studentName ?? 'the student'}.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            ...widget.links.map((link) {
              final pn = link.asset?.propertyNumber ?? link.equipmentAssetId;
              final entry = _entries[link.id]!;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pn,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'good', label: Text('Good')),
                          ButtonSegment(
                              value: 'damaged', label: Text('Damaged')),
                          ButtonSegment(value: 'lost', label: Text('Lost')),
                        ],
                        selected: {entry.condition},
                        onSelectionChanged: (set) {
                          setState(() {
                            entry.condition = set.first;
                          });
                        },
                      ),
                      if (entry.condition != 'good') ...[
                        const SizedBox(height: 8),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) => entry.notes = v,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _entries),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.maroon,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm return'),
        ),
      ],
    );
  }
}