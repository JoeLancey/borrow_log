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

  bool get _isFiltering =>
      _searchQuery.trim().isNotEmpty || _categoryFilter != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F4),
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
            final categoryMatches =
                _categoryFilter == null || type.category == _categoryFilter;
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

          return Column(
            children: [
              _header(categories),
              Expanded(
                child: RefreshIndicator(
                  color: AppTheme.maroon,
                  onRefresh: _refresh,
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (visibleData.labs.isEmpty)
                        BorrowLogEmptyState(
                          icon: Icons.search_off_rounded,
                          title: _isFiltering
                              ? 'No equipment found'
                              : 'No equipment available yet',
                          message: _isFiltering
                              ? 'Try a different search term or clear the filter.'
                              : 'New equipment will appear here when it is added.',
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
                          child: Text(
                            '${visibleTypes.length} equipment '
                            '${visibleTypes.length == 1 ? 'type' : 'types'} '
                            'in ${visibleData.labs.length} '
                            '${visibleData.labs.length == 1 ? 'laboratory' : 'laboratories'}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      for (final building in buildings) ...[
                        _buildingHeader(
                            building, byBuilding[building]!.length),
                        ...byBuilding[building]!
                            .map((lab) => _labCard(lab, visibleData)),
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

  // ───────────────────────── Header ─────────────────────────

  Widget _header(List<String> categories) {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Search equipment',
              hint: 'Name, category, or description',
              prefixIcon: Icons.search,
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final category = i == 0 ? null : categories[i - 1];
                    return _categoryChip(category);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String? category) {
    final selected = _categoryFilter == category;
    return ChoiceChip(
      label: Text(category ?? 'All categories'),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppTheme.maroon,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? AppTheme.maroon : Colors.black12),
      labelStyle: TextStyle(
        fontSize: 13,
        color: selected ? Colors.white : Colors.black87,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _categoryFilter = category),
    );
  }

  Widget _buildingHeader(String building, int labCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 6),
      child: Row(
        children: [
          const Icon(Icons.apartment, size: 18, color: AppTheme.maroon),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              building,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.maroon,
              ),
            ),
          ),
          Text(
            '$labCount ${labCount == 1 ? 'lab' : 'labs'}',
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _noAccessState() {
    return Center(
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
              'Your account has no college assigned yet, so no laboratories are '
              'visible. Please contact the laboratory staff.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Lab card ─────────────────────────

  Widget _labCard(Laboratory lab, _BrowseData data) {
    final labTypes =
        data.types.where((t) => t.laboratoryId == lab.id).toList();

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0x14000000)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          // Re-create when filtering starts/stops so matches open automatically.
          key: ValueKey('${lab.id}-$_isFiltering'),
          initiallyExpanded: _isFiltering,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.maroon.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.meeting_room_outlined,
                color: AppTheme.maroon, size: 22),
          ),
          title: Text(
            lab.name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${lab.department}  •  ${labTypes.length} equipment '
              '${labTypes.length == 1 ? 'type' : 'types'}',
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
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
      ),
    );
  }

  // ───────────────────────── Equipment type tile ─────────────────────────

  Widget _typeTile(Laboratory lab, EquipmentType type, _BrowseData data) {
    final assets =
        data.assets.where((a) => a.equipmentTypeId == type.id).toList();
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
    final color = _availabilityColor(available, total);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.memory, color: AppTheme.maroon, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14.5),
                    ),
                    if (type.category != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          type.category!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _availabilityBadge(available, total, color),
            ],
          ),
          if (type.description != null) ...[
            const SizedBox(height: 8),
            Text(
              type.description!,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.35, color: Colors.black87),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : available / total,
              minHeight: 5,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
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
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: canReserve ? () => _reserve(lab, type) : null,
                icon: Icon(
                  canReserve ? Icons.add_shopping_cart : Icons.block,
                  size: 16,
                ),
                label: Text(canReserve ? 'Reserve' : 'Unavailable'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.maroon,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _availabilityColor(int available, int total) => available == 0
      ? Colors.red
      : available < total
          ? Colors.orange
          : Colors.green;

  Widget _availabilityBadge(int available, int total, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$available / $total free',
        style: TextStyle(
            color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _statChip(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label $count',
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
        const SizedBox(width: 4),
      ],
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