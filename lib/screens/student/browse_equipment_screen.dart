import 'package:flutter/material.dart';

import '../../models/equipment_type.dart';
import '../../models/equipment_asset.dart';
import '../../models/laboratory.dart';
import '../../services/inventory_service.dart';
import '../../services/laboratory_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_components.dart';
import '../../widgets/borrow_log_states.dart';
import 'new_reservation_screen.dart';

class BrowseEquipmentScreen extends StatefulWidget {
  const BrowseEquipmentScreen({super.key});

  @override
  State<BrowseEquipmentScreen> createState() => _BrowseEquipmentScreenState();
}

class _BrowseEquipmentScreenState extends State<BrowseEquipmentScreen> {
  final _inventoryService = InventoryService();
  final _labService = LaboratoryService();

  late Future<_BrowseData> _future;
  String _searchQuery = '';
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BrowseData> _load() async {
    final labs = await _labService.fetchMyAccessibleLaboratories();
    final types = await _inventoryService
        .fetchTypesForLabs(labs.map((l) => l.id).toList());
    final assets = await _inventoryService.fetchAssets();
    return _BrowseData(labs: labs, types: types, assets: assets);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _reserve(Laboratory lab, EquipmentType type) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewReservationScreen(
          preselectedLaboratoryId: lab.id,
          preselectedTypeId: type.id,
        ),
      ),
    );
    if (created == true && mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Equipment'),
      ),
      body: FutureBuilder<_BrowseData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const BorrowLogSkeletonList(itemCount: 6);
          }
          if (snap.hasError) {
            return BorrowLogErrorState(
              message: 'Failed to load equipment:\n${snap.error}',
              onRetry: _refresh,
            );
          }
          final data = snap.data!;

          if (data.labs.isEmpty) {
            return _noAccessState();
          }

          final query = _searchQuery.trim().toLowerCase();
          final visibleTypes = data.types.where((type) {
            final categoryMatches = _categoryFilter == null ||
                type.category == _categoryFilter;
            final textMatches = query.isEmpty ||
                type.name.toLowerCase().contains(query) ||
                (type.category?.toLowerCase().contains(query) ?? false) ||
                (type.description?.toLowerCase().contains(query) ?? false);
            return categoryMatches && textMatches;
          }).toList();
          final visibleData = _BrowseData(
            labs: data.labs
                .where((lab) => visibleTypes.any((type) =>
                    type.laboratoryId == lab.id ||
                    (query.isNotEmpty &&
                        lab.name.toLowerCase().contains(query))))
                .toList(),
            types: visibleTypes,
            assets: data.assets,
          );
          final categories = data.types
              .map((type) => type.category)
              .whereType<String>()
              .where((category) => category.trim().isNotEmpty)
              .toSet()
              .toList()
            ..sort();

          // Group labs by building.
          final byBuilding = <String, List<Laboratory>>{};
          for (final lab in visibleData.labs) {
            byBuilding.putIfAbsent(lab.building, () => []).add(lab);
          }
          final buildings = byBuilding.keys.toList()..sort();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                AppTextField(
                  label: 'Search equipment',
                  hint: 'Name, category, or description',
                  prefixIcon: Icons.search,
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All categories'),
                          selected: _categoryFilter == null,
                          onSelected: (_) =>
                              setState(() => _categoryFilter = null),
                        ),
                        ...categories.map((category) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: FilterChip(
                                label: Text(category),
                                selected: _categoryFilter == category,
                                onSelected: (_) => setState(
                                    () => _categoryFilter = category),
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
                if (visibleData.labs.isEmpty)
                  BorrowLogEmptyState(
                    icon: Icons.search_off_rounded,
                    title: _searchQuery.isNotEmpty || _categoryFilter != null
                        ? 'No equipment found'
                        : 'No equipment available yet',
                    message: _searchQuery.isNotEmpty || _categoryFilter != null
                        ? 'Try a different search term or clear the filter.'
                        : 'New equipment will appear here when it is added.',
                  ),
                for (final building in buildings) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 4),
                    child: Text(
                      building.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.maroon,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                    ...byBuilding[building]!
                      .map((lab) => _labCard(lab, visibleData)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _noAccessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 56, color: AppTheme.maroon),
            const SizedBox(height: 12),
            const Text(
              'No laboratory access',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your account has no college assigned yet, so no laboratories are '
              'visible. Please contact the laboratory staff.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _labCard(Laboratory lab, _BrowseData data) {
    final labTypes = data.types
        .where((t) => t.laboratoryId == lab.id)
        .toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        leading: const Icon(Icons.meeting_room_outlined,
            color: AppTheme.maroon),
        title: Text(
          lab.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${lab.department} · ${labTypes.length} equipment type(s)',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          if (labTypes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No equipment registered in this laboratory yet.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            ...labTypes.map((t) => _typeTile(lab, t, data)),
        ],
      ),
    );
  }

  Widget _typeTile(Laboratory lab, EquipmentType type, _BrowseData data) {
    final assets = data.assets
        .where((a) => a.equipmentTypeId == type.id)
        .toList();
    final total = assets.length;
    final available = assets.where((a) => a.status == 'available').length;
    final reserved = assets.where((a) => a.status == 'reserved').length;
    final borrowed = assets.where((a) => a.status == 'borrowed').length;
    final maintenance = assets
        .where((a) =>
            a.status == 'maintenance' ||
            a.status == 'damaged' ||
            a.status == 'lost')
        .length;

    final canReserve = available > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        elevation: 0,
        color: Colors.grey.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.memory,
                      color: AppTheme.maroon, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      type.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  _availabilityBadge(available, total),
                ],
              ),
              if (type.category != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 28),
                  child: Text(
                    type.category!,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black54),
                  ),
                ),
              if (type.description != null) ...[
                const SizedBox(height: 6),
                Text(type.description!,
                    style: const TextStyle(fontSize: 12)),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _statChip('Available', available, Colors.green),
                  if (reserved > 0)
                    _statChip('Reserved', reserved, Colors.orange),
                  if (borrowed > 0)
                    _statChip('Borrowed', borrowed, Colors.blue),
                  if (maintenance > 0)
                    _statChip('Maintenance', maintenance, Colors.purple),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed:
                      canReserve ? () => _reserve(lab, type) : null,
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: const Text('Reserve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.maroon,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _availabilityBadge(int available, int total) {
    final color = available == 0
        ? Colors.red
        : available < total
            ? Colors.orange
            : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$available / $total',
        style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _statChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }
}

class _BrowseData {
  final List<Laboratory> labs;
  final List<EquipmentType> types;
  final List<EquipmentAsset> assets;

  _BrowseData({
    required this.labs,
    required this.types,
    required this.assets,
  });
}