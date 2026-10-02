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
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Export as CSV'),
              subtitle: Text('Choose what to export'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.event_note_outlined),
              title: const Text('Reservations'),
              subtitle: Text('${data.reservations.length} row(s)'),
              onTap: () => Navigator.pop(ctx, 'reservations'),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Inventory'),
              subtitle: Text('${data.assets.length} row(s)'),
              onTap: () => Navigator.pop(ctx, 'inventory'),
            ),
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

        final relevant = data.reservations.where((r) =>
            r.status == 'approved' ||
            r.status == 'borrowed' ||
            r.status == 'completed');

        for (final r in relevant) {
          final links =
              await _reservationService.fetchReservationAssets(r.id);
          final conditions =
              await _reservationService.fetchReturnConditions(r.id);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _deliverCsv(String filename, String csv) async {
    try {
      await downloadCsv(filename, csv);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloading $filename')),
      );
    } on UnsupportedError {
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV copied to clipboard.')),
      );
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
          FutureBuilder<_ReportData>(
            future: _future,
            builder: (context, snap) {
              final hasData = snap.hasData;
              return IconButton(
                tooltip: 'Export CSV',
                icon: const Icon(Icons.download),
                onPressed: hasData ? () => _exportCsv(snap.data!) : null,
              );
            },
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

  Widget _body(_ReportData data) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final all = data.reservations;
    final thisMonth = all
        .where((r) =>
            r.createdAt != null && r.createdAt!.isAfter(startOfMonth))
        .toList();

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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Overview'),
          _statGrid([
            _StatTile('Total reservations', '${all.length}',
                Icons.list_alt, Colors.blueGrey),
            _StatTile('This month', '${thisMonth.length}',
                Icons.calendar_month, AppTheme.maroon),
            _StatTile('Pending', '$pending',
                Icons.pending_actions, Colors.orange),
            _StatTile('Active', '$active',
                Icons.play_circle_outline, Colors.blue),
            _StatTile('Overdue', '$overdue',
                Icons.warning_amber_rounded, Colors.red),
            _StatTile('Completed', '$completed',
                Icons.check_circle_outline, Colors.teal),
            _StatTile('Rejected', '$rejected',
                Icons.cancel_outlined, Colors.pink),
          ]),

          const SizedBox(height: 24),
          _sectionTitle('Inventory Status'),
          _inventoryPieChart(
            available: availableAssets,
            reserved: reservedAssets,
            borrowed: borrowedAssets,
            damaged: damagedAssets,
            lost: lostAssets,
          ),

          const SizedBox(height: 24),
          _sectionTitle('Reservations per Month'),
          _monthlyBarChart(monthlyCounts),

          const SizedBox(height: 24),
          _sectionTitle('Most-Borrowed Equipment'),
          if (top5.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No borrowing data yet.',
                    style: TextStyle(color: Colors.black54)),
              ),
            )
          else
            _topTypesChart(top5),

          const SizedBox(height: 24),
          _sectionTitle('Damage Rate'),
          _damageRateCard(all, damagedAssets + lostAssets),
        ],
      ),
    );
  }

  String _monthKey(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.year.toString().substring(2)}';
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
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text('No inventory data yet.',
                style: TextStyle(color: Colors.black54)),
          ),
        ),
      );
    }

    final segments = <_PieSegment>[
      if (available > 0)
        _PieSegment('Available', available, Colors.green),
      if (reserved > 0)
        _PieSegment('Reserved', reserved, Colors.orange),
      if (borrowed > 0)
        _PieSegment('Borrowed', borrowed, Colors.blue),
      if (damaged > 0)
        _PieSegment('Damaged/Maint.', damaged, Colors.purple),
      if (lost > 0) _PieSegment('Lost', lost, Colors.red),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 220,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: segments.map((s) {
                      final pct = (s.value / total) * 100;
                      return PieChartSectionData(
                        value: s.value.toDouble(),
                        color: s.color,
                        title: pct >= 8
                            ? '${pct.toStringAsFixed(0)}%'
                            : '',
                        radius: 55,
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: segments.map((s) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: s.color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.label,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${s.value}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthlyBarChart(Map<String, int> monthlyCounts) {
    final entries = monthlyCounts.entries.toList();
    final maxY = entries.isEmpty
        ? 1.0
        : (entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) + 1)
            .toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
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
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      if (value == value.roundToDouble()) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black54),
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
                          style: const TextStyle(
                              fontSize: 10, color: Colors.black54),
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
                getDrawingHorizontalLine: (v) => FlLine(
                  color: Colors.black12,
                  strokeWidth: 0.5,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(entries.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: entries[i].value.toDouble(),
                      color: AppTheme.maroon,
                      width: 20,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topTypesChart(List<MapEntry<String, int>> top) {
    final maxVal = top.first.value.toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: top.map((e) {
            final ratio = maxVal == 0 ? 0.0 : e.value / maxVal;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      e.key,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: ratio.toDouble(),
                        minHeight: 12,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation(
                            AppTheme.maroon),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${e.value}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _damageRateCard(List<Reservation> all, int damagedCount) {
    final completed = all.where((r) => r.status == 'completed').toList();
    int completedUnits = 0;
    for (final r in completed) {
      completedUnits += r.quantityRequested;
    }

    final rate = completedUnits == 0
        ? 0.0
        : damagedCount / (completedUnits + damagedCount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${(rate * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.maroon,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$damagedCount damaged or lost out of '
              '$completedUnits completed units.',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.maroon,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _statGrid(List<Widget> tiles) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final width = constraints.maxWidth;
        final cols = width < 400 ? 2 : (width < 700 ? 3 : 4);
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.6,
          children: tiles,
        );
      },
    );
  }
}

class _PieSegment {
  final String label;
  final int value;
  final Color color;
  _PieSegment(this.label, this.value, this.color);
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
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