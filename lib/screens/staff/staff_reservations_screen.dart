import 'package:flutter/material.dart';

import '../../models/equipment_asset.dart';
import '../../models/reservation.dart';
import '../../models/reservation_asset.dart';
import '../../services/inventory_service.dart';
import '../../services/reservation_service.dart';
import '../../features/reservations/domain/reservation_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/borrow_log_app_bar.dart';
import '../../widgets/borrow_log_states.dart';
import '../shared/borrower_slip_screen.dart';

const _red = Color(0xFFC62828);
const _green = Color(0xFF2E7D32);
const _amber = Color(0xFFB26A00);
const _blue = Color(0xFF1565C0);

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class StaffReservationsScreen extends StatefulWidget {
  const StaffReservationsScreen({super.key});

  @override
  State<StaffReservationsScreen> createState() =>
      _StaffReservationsScreenState();
}

class _StaffReservationsScreenState extends State<StaffReservationsScreen>
    with SingleTickerProviderStateMixin {
  final ReservationRepository _service = ReservationService();
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

  // ---------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------

  /// Tab with a small count pill. Counts are 0 until data has loaded.
  Tab _tab(String label, int? count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Reservation>>(
      future: _future,
      builder: (context, snap) {
        final loaded =
            snap.connectionState != ConnectionState.waiting && !snap.hasError;
        final all = loaded ? (snap.data ?? <Reservation>[]) : <Reservation>[];
        final pending = all.where((r) => r.status == 'pending').toList();
        final active = all.where((r) => r.isActive && !r.isOverdue).toList();
        final overdue = all.where((r) => r.isOverdue).toList();
        final history = all
            .where((r) =>
                r.status == 'completed' ||
                r.status == 'rejected' ||
                r.status == 'cancelled')
            .toList();

        Widget body;
        if (snap.connectionState == ConnectionState.waiting) {
          body = const BorrowLogSkeletonList();
        } else if (snap.hasError) {
          body = BorrowLogErrorState(
            message: 'Failed to load reservations:\n${snap.error}',
            onRetry: _refresh,
          );
        } else {
          body = TabBarView(
            controller: _tabController,
            children: [
              _listView(
                pending,
                icon: Icons.inbox_outlined,
                empty: 'No pending requests.',
                hint: 'New requests will show up here for approval.',
              ),
              _listView(
                active,
                icon: Icons.play_circle_outline,
                empty: 'No active reservations.',
                hint: 'Approved and borrowed items appear here.',
              ),
              _listView(
                overdue,
                icon: Icons.check_circle_outline,
                empty: 'No overdue equipment.',
                hint: 'Everything is on time. Nice work.',
              ),
              _listView(
                history,
                icon: Icons.history,
                empty: 'No history yet.',
                hint: 'Completed, rejected and cancelled requests go here.',
              ),
            ],
          );
        }

        return Scaffold(
          appBar: BorrowLogAppBar(
            title: 'Reservations',
            // Refresh action removed — pull-to-refresh on each tab
            // still works via RefreshIndicator.
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                _tab('Pending', loaded ? pending.length : null),
                _tab('Active', loaded ? active.length : null),
                _tab('Overdue', loaded ? overdue.length : null),
                _tab('History', loaded ? history.length : null),
              ],
            ),
          ),
          body: body,
        );
      },
    );
  }

  Widget _listView(
    List<Reservation> items, {
    required IconData icon,
    required String empty,
    required String hint,
  }) {
    final scheme = Theme.of(context).colorScheme;

    if (items.isEmpty) {
      // Scrollable so pull-to-refresh still works on an empty tab.
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppTheme.maroon.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 42, color: AppTheme.maroon),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      empty,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            itemBuilder: (_, i) => _card(items[i]),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // CARD
  // ---------------------------------------------------------

  Color _accent(Reservation r) {
    if (r.isOverdue) return _red;
    switch (r.status) {
      case 'pending':
        return _amber;
      case 'approved':
        return _green;
      case 'borrowed':
        return _blue;
      case 'completed':
        return Colors.teal.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  Widget _infoRow(
    IconData icon,
    String text, {
    Color? color,
    bool bold = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                color: color ?? scheme.onSurface,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Reservation r) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _accent(r);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.equipmentTypeName ?? 'Equipment',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Quantity: ${r.quantityRequested}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _statusChip(r),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      Icons.person_outline,
                      r.studentName ?? r.studentId,
                    ),
                    _infoRow(
                      Icons.menu_book_outlined,
                      '${r.subject}'
                      '${r.subjectCode != null ? ' (${r.subjectCode})' : ''}',
                    ),
                    _infoRow(Icons.school_outlined, r.instructor),
                    _infoRow(
                      Icons.event_outlined,
                      '${r.useDateFormatted}'
                      '${r.useTime != null ? ' Â· ${r.useTime}' : ''}',
                    ),
                    if (r.dueDateFormatted != null)
                      _infoRow(
                        Icons.schedule,
                        'Due: ${r.dueDateFormatted}',
                        color: r.isOverdue ? _red : null,
                        bold: r.isOverdue,
                      ),
                    if (r.rejectionReason != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _red.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Reason: ${r.rejectionReason}',
                          style: const TextStyle(color: _red, fontSize: 13),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Divider(height: 1, color: scheme.outlineVariant),
                    const SizedBox(height: 8),
                    _actions(r),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(Reservation r) {
    final primaryStyle = FilledButton.styleFrom(
      backgroundColor: AppTheme.maroon,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 42),
    );

    Widget? primary;
    Widget? secondary;

    if (r.status == 'pending') {
      secondary = OutlinedButton.icon(
        onPressed: () => _showRejectDialog(r),
        icon: const Icon(Icons.close, size: 18),
        label: const Text('Reject'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _red,
          side: const BorderSide(color: _red),
          minimumSize: const Size(0, 42),
        ),
      );
      primary = FilledButton.icon(
        onPressed: () => _showApproveDialog(r),
        icon: const Icon(Icons.check, size: 18),
        label: const Text('Approve'),
        style: primaryStyle,
      );
    } else if (r.status == 'approved') {
      primary = FilledButton.icon(
        onPressed: () => _showReleaseDialog(r),
        icon: const Icon(Icons.assignment_turned_in_outlined, size: 18),
        label: const Text('Release'),
        style: primaryStyle,
      );
    } else if (r.status == 'borrowed') {
      primary = FilledButton.icon(
        onPressed: () => _showReturnDialog(r),
        icon: const Icon(Icons.assignment_return_outlined, size: 18),
        label: const Text('Receive return'),
        style: primaryStyle,
      );
    }

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 8,
      spacing: 8,
      children: [
        TextButton.icon(
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
        if (primary != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (secondary != null) ...[secondary, const SizedBox(width: 8)],
              primary,
            ],
          ),
      ],
    );
  }

  Widget _statusChip(Reservation r) {
    return BorrowLogStatusChip.reservation(r.status, overdue: r.isOverdue);
  }

  // ---------------------------------------------------------
  // SHARED DIALOG PIECES
  // ---------------------------------------------------------

  Future<void> _showInfoDialog({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(icon, size: 34, color: color),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.maroon,
              foregroundColor: Colors.white,
              minimumSize: const Size(110, 44),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
      _showInfoDialog(
        icon: Icons.inventory_2_outlined,
        color: _amber,
        title: 'No available assets',
        message: 'There are no available units of '
            '"${r.equipmentTypeName ?? 'this equipment'}".',
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
      _showInfoDialog(
        icon: Icons.warning_amber_rounded,
        color: _amber,
        title: 'Quantity mismatch',
        message:
            'You must select exactly ${r.quantityRequested} property number(s).',
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
    bool showError = false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          icon: const Icon(Icons.cancel_outlined, size: 34, color: _red),
          title: const Text('Reject reservation?', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rejecting request from ${r.studentName ?? 'the student'}. '
                'They will see your reason.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  if (showError) setLocal(() => showError = false);
                },
                decoration: InputDecoration(
                  labelText: 'Reason *',
                  errorText: showError ? 'Please enter a reason' : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  setLocal(() => showError = true);
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ],
        ),
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
          builder: (ctx, setLocal) {
            final scheme = Theme.of(ctx).colorScheme;
            final now = DateTime.now();

            Widget quick(String label, int days) {
              final target = DateTime(now.year, now.month, now.day)
                  .add(Duration(days: days));
              final selected = dueDate != null &&
                  _fmtDate(dueDate!) == _fmtDate(target);
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => setLocal(() => dueDate = target),
              );
            }

            return AlertDialog(
              icon: const Icon(
                Icons.assignment_turned_in_outlined,
                size: 34,
                color: AppTheme.maroon,
              ),
              title: const Text(
                'Release equipment',
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Releasing ${r.quantityRequested} unit(s) of '
                    '"${r.equipmentTypeName ?? 'equipment'}" to '
                    '${r.studentName ?? 'the student'}.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'DUE DATE *',
                    style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      quick('Tomorrow', 1),
                      quick('In 3 days', 3),
                      quick('In 1 week', 7),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: dueDate ?? now.add(const Duration(days: 1)),
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 90)),
                      );
                      if (picked != null) {
                        setLocal(() => dueDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      dueDate == null ? 'Pick a date' : _fmtDate(dueDate!),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 46),
                    ),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: dueDate == null
                      ? null
                      : () => Navigator.pop(ctx, dueDate),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.maroon,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Release'),
                ),
              ],
            );
          },
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
    final scheme = Theme.of(context).colorScheme;
    final needed = widget.reservation.quantityRequested;
    final complete = _selected.length == needed;
    final tone = complete ? _green : _amber;

    return AlertDialog(
      title: const Text('Assign property numbers'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select exactly $needed unit(s) of '
              '"${widget.reservation.equipmentTypeName ?? 'equipment'}".',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: needed == 0 ? 0 : _selected.length / needed,
                      minHeight: 6,
                      color: tone,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_selected.length} / $needed',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: tone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.available.length,
                itemBuilder: (_, i) {
                  final a = widget.available[i];
                  final isSelected = _selected.contains(a.id);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: CheckboxListTile(
                      dense: true,
                      value: isSelected,
                      selected: isSelected,
                      selectedTileColor:
                          AppTheme.maroon.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        a.propertyNumber,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: a.conditionNotes != null
                          ? Text(a.conditionNotes!)
                          : null,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            if (_selected.length >= needed) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('You only need $needed unit(s).'),
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
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: complete
              ? () => Navigator.pop(context, _selected.toList())
              : null,
          style: FilledButton.styleFrom(
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

  Color _conditionColor(String c) {
    switch (c) {
      case 'damaged':
        return _amber;
      case 'lost':
        return _red;
      default:
        return _green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final problems =
        _entries.values.where((e) => e.condition != 'good').length;

    return AlertDialog(
      title: const Text('Receive return'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Record the condition of each property number returned by '
              '${widget.reservation.studentName ?? 'the student'}.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            ...widget.links.map((link) {
              final pn = link.asset?.propertyNumber ?? link.equipmentAssetId;
              final entry = _entries[link.id]!;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: entry.condition == 'good'
                        ? scheme.outlineVariant
                        : _conditionColor(entry.condition)
                            .withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.qr_code_2,
                            size: 18, color: AppTheme.maroon),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pn,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ConditionPill(
                            label: 'Good',
                            value: 'good',
                            current: entry.condition,
                            color: _green,
                            onTap: () =>
                                setState(() => entry.condition = 'good'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _ConditionPill(
                            label: 'Damaged',
                            value: 'damaged',
                            current: entry.condition,
                            color: _amber,
                            onTap: () =>
                                setState(() => entry.condition = 'damaged'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _ConditionPill(
                            label: 'Lost',
                            value: 'lost',
                            current: entry.condition,
                            color: _red,
                            onTap: () =>
                                setState(() => entry.condition = 'lost'),
                          ),
                        ),
                      ],
                    ),
                    if (entry.condition != 'good') ...[
                      const SizedBox(height: 12),
                      TextField(
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Notes',
                          hintText: entry.condition == 'lost'
                              ? 'Last known details'
                              : 'Describe the damage',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                        onChanged: (v) => entry.notes = v,
                      ),
                    ],
                  ],
                ),
              );
            }),
            if (problems > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  '$problems item${problems == 1 ? '' : 's'} flagged as damaged or lost.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _amber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _entries),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.maroon,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text(
                  'Confirm',
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Small pill used in the Receive Return dialog to pick condition.
class _ConditionPill extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final Color color;
  final VoidCallback onTap;

  const _ConditionPill({
    required this.label,
    required this.value,
    required this.current,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return Material(
      color: selected
          ? color.withValues(alpha: 0.16)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.black26,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? color : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
} 