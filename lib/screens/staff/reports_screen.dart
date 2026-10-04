import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/equipment_asset.dart';
import '../../models/equipment_type.dart';
import '../../models/reservation.dart';
import '../../models/reservation_asset.dart';
import '../../services/csv_export_service.dart';
import '../../services/inventory_service.dart';
import '../../services/reservation_service.dart';
import '../../features/reservations/domain/reservation_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/csv_download.dart';
import '../../widgets/borrow_log_app_bar.dart';
import '../../widgets/borrow_log_states.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReservationRepository _reservationService = ReservationService();
  final _inventoryService = InventoryService();

  late Future<_ReportData> _future;
  String _range = 'month';

  // UI-only: which donut slice is currently touched.
  int _touchedPie = -1;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ReportData> _load() async {
    final reservations = await _reservationService.fetchAllReservations();
    final types = await _inventoryService.fetchTypes();
    final assets = await _inventoryService.fetchAssets();
    return _ReportData(
      reservations: reservations,
      types: types,
      assets: assets,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  // ---------------------------------------------------------
  // CSV EXPORT
  // ---------------------------------------------------------

  Future<void> _exportCsv(_ReportData data) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Export as CSV',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Choose what to export',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const _IconTile(
                icon: Icons.event_note_outlined,
                color: AppTheme.maroon,
              ),
              title: const Text('Reservations'),
              subtitle: Text('${data.reservations.length} row(s)'),
              onTap: () => Navigator.pop(ctx, 'reservations'),
            ),
            ListTile(
              leading: const _IconTile(
                icon: Icons.inventory_2_outlined,
                color: AppTheme.maroon,
              ),
              title: const Text('Inventory'),
              subtitle: Text('${data.assets.length} row(s)'),
              onTap: () => Navigator.pop(ctx, 'inventory'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected == null) return;
    if (!mounted) return;

    try {
      if (selected == 'inventory') {
        final csv = CsvExportService().buildInventoryCsv(data.assets);
        await _deliverCsv('inventory_${_timestamp()}.csv', csv);
      } else {
        final assetsByRes = <String, List<ReservationAsset>>{};
        final conditionsByRes = <String, Map<String, String>>{};

        final relevant = data.reservations.where(
          (r) =>
              r.status == 'approved' ||
              r.status == 'borrowed' ||
              r.status == 'completed',
        );

        for (final r in relevant) {
          final links = await _reservationService.fetchReservationAssets(r.id);
          final conditions = await _reservationService.fetchReturnConditions(
            r.id,
          );
          assetsByRes[r.id] = links;
          conditionsByRes[r.id] = conditions;
        }

        final csv = CsvExportService().buildReservationsCsv(
          reservations: data.reservations,
          assetsByReservation: assetsByRes,
          conditionsByReservation: conditionsByRes,
        );
        await _deliverCsv('reservations_${_timestamp()}.csv', csv);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _deliverCsv(String filename, String csv) async {
    try {
      await downloadCsv(filename, csv);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Downloading $filename')));
    } on UnsupportedError {
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('CSV copied to clipboard.')));
    }
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BorrowLogAppBar(
        title: 'Reports',
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Export data',
            icon: const Icon(Icons.file_download_outlined),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (value) {
              if (value == 'csv') {
                _future.then((data) {
                  if (mounted) _exportCsv(data);
                });
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Export CSV'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<_ReportData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const BorrowLogSkeletonList(itemCount: 5);
          }
          if (snap.hasError) {
            return BorrowLogErrorState(
              message: 'Failed to load reports:\n${snap.error}',
              onRetry: _refresh,
            );
          }
          return _body(snap.data!);
        },
      ),
    );
  }

  String get _rangeLabel {
    switch (_range) {
      case 'week':
        return 'This week';
      case 'all':
        return 'All time';
      default:
        return 'This month';
    }
  }

  Widget _body(_ReportData data) {
    final now = DateTime.now();
    final all = _reservationsForRange(data.reservations, now);
    final thisMonth = data.reservations.where((r) {
      final created = r.createdAt;
      return created != null &&
          created.year == now.year &&
          created.month == now.month;
    }).toList();

    final pending = all.where((r) => r.status == 'pending').length;
    final active = all.where((r) => r.isActive).length;
    final overdue = all.where((r) => r.isOverdue).length;
    final completed = all.where((r) => r.status == 'completed').length;
    final rejected = all.where((r) => r.status == 'rejected').length;

    final damagedAssets = data.assets
        .where((a) => a.status == 'damaged' || a.status == 'maintenance')
        .length;
    final lostAssets = data.assets.where((a) => a.status == 'lost').length;
    final availableAssets =
        data.assets.where((a) => a.status == 'available').length;
    final borrowedAssets =
        data.assets.where((a) => a.status == 'borrowed').length;
    final reservedAssets =
        data.assets.where((a) => a.status == 'reserved').length;

    final counts = <String, int>{};
    for (final r in all) {
      if (r.status == 'borrowed' ||
          r.status == 'completed' ||
          r.status == 'approved') {
        final name = r.equipmentTypeName ?? 'Unknown';
        counts[name] = (counts[name] ?? 0) + r.quantityRequested;
      }
    }
    final topTypes = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = topTypes.take(5).toList();

    final monthlyCounts = <String, int>{};
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = _monthKey(d);
      monthlyCounts[key] = 0;
    }
    for (final r in all) {
      if (r.createdAt == null) continue;
      final key = _monthKey(DateTime(r.createdAt!.year, r.createdAt!.month, 1));
      if (monthlyCounts.containsKey(key)) {
        monthlyCounts[key] = monthlyCounts[key]! + 1;
      }
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'week', label: Text('Week')),
                    ButtonSegment(value: 'month', label: Text('Month')),
                    ButtonSegment(value: 'all', label: Text('All time')),
                  ],
                  selected: {_range},
                  onSelectionChanged: (selection) =>
                      setState(() => _range = selection.first),
                ),
              ),
              const SizedBox(height: 20),
              _sectionTitle('Overview', subtitle: _rangeLabel),
              Row(
                children: [
                  Expanded(
                    child: _HeroTile(
                      label: 'Reservations',
                      caption: _rangeLabel,
                      value: '${all.length}',
                      icon: Icons.list_alt_rounded,
                      filled: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HeroTile(
                      label: 'Created',
                      caption: 'This month',
                      value: '${thisMonth.length}',
                      icon: Icons.calendar_month_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _statusBreakdown(
                total: all.length,
                rows: [
                  _StatusRow('Pending', pending, Icons.pending_actions,
                      Colors.orange.shade800),
                  _StatusRow('Active', active, Icons.play_circle_outline,
                      Colors.blue.shade700),
                  _StatusRow('Overdue', overdue, Icons.warning_amber_rounded,
                      Colors.red.shade700),
                  _StatusRow('Completed', completed,
                      Icons.check_circle_outline, Colors.teal.shade700),
                  _StatusRow('Rejected', rejected, Icons.cancel_outlined,
                      Colors.pink.shade700),
                ],
              ),
              const SizedBox(height: 28),
              _sectionTitle('Inventory status'),
              _inventoryPieChart(
                available: availableAssets,
                reserved: reservedAssets,
                borrowed: borrowedAssets,
                damaged: damagedAssets,
                lost: lostAssets,
              ),
              const SizedBox(height: 28),
              _sectionTitle('Reservations per month',
                  subtitle: 'Last 6 months'),
              _monthlyBarChart(monthlyCounts),
              const SizedBox(height: 28),
              _sectionTitle('Most-borrowed equipment', subtitle: _rangeLabel),
              if (top5.isEmpty)
                _emptyCard(Icons.bar_chart_rounded, 'No borrowing data yet.')
              else
                _topTypesChart(top5),
              const SizedBox(height: 28),
              _sectionTitle('Damage rate'),
              _damageRateCard(all, damagedAssets + lostAssets),
            ],
          ),
        ),
      ),
    );
  }

  List<Reservation> _reservationsForRange(
    List<Reservation> reservations,
    DateTime now,
  ) {
    if (_range == 'all') return reservations;
    final start = _range == 'week'
        ? now.subtract(Duration(days: now.weekday - 1))
        : DateTime(now.year, now.month, 1);
    return reservations.where((reservation) {
      final created = reservation.createdAt;
      return created != null && !created.isBefore(start);
    }).toList();
  }

  String _monthKey(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.year.toString().substring(2)}';
  }

  // ---------------------------------------------------------
  // SHARED UI PIECES
  // ---------------------------------------------------------

  Widget _card({required Widget child, EdgeInsets? padding}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _emptyCard(IconData icon, String message) {
    final scheme = Theme.of(context).colorScheme;
    return _card(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 36, color: scheme.outline),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, {String? subtitle}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppTheme.maroon,
              letterSpacing: 1.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(
              '· $subtitle',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Replaces the tall 2-column grid with one compact, scannable card.
  Widget _statusBreakdown({
    required int total,
    required List<_StatusRow> rows,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return _card(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _statusRowTile(rows[i], total, scheme),
            if (i != rows.length - 1)
              Divider(height: 1, color: scheme.outlineVariant),
          ],
        ],
      ),
    );
  }

  Widget _statusRowTile(_StatusRow row, int total, ColorScheme scheme) {
    final ratio = total == 0 ? 0.0 : row.value / total;
    final highlight = row.label == 'Overdue' && row.value > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Semantics(
        label: '${row.label}: ${row.value}',
        child: Row(
          children: [
            _IconTile(icon: row.icon, color: row.color, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 5,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: row.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              constraints: const BoxConstraints(minWidth: 40),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: highlight
                    ? row.color
                    : row.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '${row.value}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: highlight ? Colors.white : row.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // CHARTS
  // ---------------------------------------------------------

  Widget _inventoryPieChart({
    required int available,
    required int reserved,
    required int borrowed,
    required int damaged,
    required int lost,
  }) {
    final total = available + reserved + borrowed + damaged + lost;

    if (total == 0) {
      return _emptyCard(Icons.inventory_2_outlined, 'No inventory data yet.');
    }

    final segments = <_PieSegment>[
      if (available > 0)
        _PieSegment('Available', available, AppTheme.statusApproved),
      if (reserved > 0)
        _PieSegment('Reserved', reserved, AppTheme.statusPending),
      if (borrowed > 0)
        _PieSegment('Borrowed', borrowed, AppTheme.statusBorrowed),
      if (damaged > 0)
        _PieSegment('Damaged/Maint.', damaged, AppTheme.statusOverdue),
      if (lost > 0) _PieSegment('Lost', lost, AppTheme.statusRejected),
    ];

    final scheme = Theme.of(context).colorScheme;
    final touched = (_touchedPie >= 0 && _touchedPie < segments.length)
        ? segments[_touchedPie]
        : null;

    return _card(
      child: Column(
        children: [
          SizedBox(
            height: 210,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 58,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        final idx =
                            response?.touchedSection?.touchedSectionIndex ??
                                -1;
                        final next =
                            event.isInterestedForInteractions ? idx : -1;
                        if (next != _touchedPie) {
                          setState(() => _touchedPie = next);
                        }
                      },
                    ),
                    sections: [
                      for (var i = 0; i < segments.length; i++)
                        PieChartSectionData(
                          value: segments[i].value.toDouble(),
                          color: segments[i].color,
                          title: (segments[i].value / total) * 100 >= 8 &&
                                  i != _touchedPie
                              ? '${((segments[i].value / total) * 100).toStringAsFixed(0)}%'
                              : '',
                          radius: i == _touchedPie ? 36 : 30,
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${touched?.value ?? total}',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      touched?.label ?? 'assets',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final s in segments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: s.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.label,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${s.value}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${(s.value / total * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
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

  Widget _monthlyBarChart(Map<String, int> monthlyCounts) {
    final scheme = Theme.of(context).colorScheme;
    final entries = monthlyCounts.entries.toList();
    final maxY = entries.isEmpty
        ? 1.0
        : (entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) + 1)
            .toDouble();
    final hasData = entries.any((e) => e.value > 0);

    if (!hasData) {
      return _emptyCard(
        Icons.bar_chart_rounded,
        'No reservations in this period.',
      );
    }

    return _card(
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, _) {
                  return BarTooltipItem(
                    '${entries[group.x].key}\n${rod.toY.toInt()} reservations',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    if (value == value.roundToDouble()) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= entries.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        entries[i].key,
                        style: TextStyle(
                          fontSize: 10,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (v) =>
                  FlLine(color: scheme.outlineVariant, strokeWidth: 0.6),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(entries.length, (i) {
              final isLatest = i == entries.length - 1;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: entries[i].value.toDouble(),
                    color: isLatest
                        ? AppTheme.maroon
                        : AppTheme.maroon.withValues(alpha: 0.55),
                    width: 22,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _topTypesChart(List<MapEntry<String, int>> top) {
    final scheme = Theme.of(context).colorScheme;
    final maxVal = top.first.value.toDouble();
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          for (var i = 0; i < top.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == 0
                          ? AppTheme.maroon
                          : AppTheme.maroon.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: i == 0 ? Colors.white : AppTheme.maroon,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          top[i].key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: maxVal == 0 ? 0.0 : top[i].value / maxVal,
                            minHeight: 6,
                            backgroundColor: scheme.surfaceContainerHighest,
                            valueColor: const AlwaysStoppedAnimation(
                              AppTheme.maroon,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${top[i].value}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _damageRateCard(List<Reservation> all, int damagedCount) {
    final scheme = Theme.of(context).colorScheme;
    final completed = all.where((r) => r.status == 'completed').toList();
    int completedUnits = 0;
    for (final r in completed) {
      completedUnits += r.quantityRequested;
    }

    final rate = completedUnits == 0
        ? 0.0
        : damagedCount / (completedUnits + damagedCount);

    final Color tone = rate >= 0.15
        ? Colors.red.shade700
        : (rate >= 0.05 ? Colors.orange.shade800 : Colors.green.shade700);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(rate * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: tone,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  rate >= 0.15
                      ? 'High'
                      : (rate >= 0.05 ? 'Moderate' : 'Low'),
                  style: TextStyle(
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: rate.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              color: tone,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$damagedCount damaged or lost out of '
            '$completedUnits completed units.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small UI helpers
// ---------------------------------------------------------------------------

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class _HeroTile extends StatelessWidget {
  const _HeroTile({
    required this.label,
    required this.caption,
    required this.value,
    required this.icon,
    this.filled = false,
  });

  final String label;
  final String caption;
  final String value;
  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = filled ? Colors.white : AppTheme.maroon;
    final sub = filled ? Colors.white70 : scheme.onSurfaceVariant;

    return Semantics(
      label: '$label, $caption: $value',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: filled ? AppTheme.maroon : scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: filled ? null : Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: sub),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sub,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 34,
                height: 1,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            const SizedBox(height: 6),
            Text(caption, style: TextStyle(fontSize: 12, color: sub)),
          ],
        ),
      ),
    );
  }
}

class _StatusRow {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  _StatusRow(this.label, this.value, this.icon, this.color);
}

class _PieSegment {
  final String label;
  final int value;
  final Color color;
  _PieSegment(this.label, this.value, this.color);
}

class _ReportData {
  final List<Reservation> reservations;
  final List<EquipmentType> types;
  final List<EquipmentAsset> assets;

  _ReportData({
    required this.reservations,
    required this.types,
    required this.assets,
  });
}