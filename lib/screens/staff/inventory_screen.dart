import 'package:flutter/material.dart';

import '../../models/equipment_type.dart';
import '../../models/equipment_asset.dart';
import '../../models/laboratory.dart';
import '../../services/inventory_service.dart';
import '../../services/laboratory_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/app_components.dart';
import '../../widgets/borrow_log_app_bar.dart';
import '../../widgets/borrow_log_states.dart';
import 'add_equipment_type_screen.dart';
import 'add_equipment_asset_screen.dart';

Color _statusColor(String status) {
  switch (status) {
    case 'available':
      return const Color(0xFF2E7D32);
    case 'reserved':
      return const Color(0xFFB26A00);
    case 'borrowed':
      return const Color(0xFF1565C0);
    case 'maintenance':
      return const Color(0xFFEF6C00);
    case 'damaged':
      return const Color(0xFFC62828);
    case 'lost':
      return const Color(0xFF616161);
    default:
      return const Color(0xFF616161);
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _service = InventoryService();
  final _labService = LaboratoryService();

  late Future<_InventoryData> _future;
  final _searchController = TextEditingController();

  bool _selectMode = false;
  final Set<String> _selected = {};

  final Set<String> _showAllUnits = {};
  static const _unitPreviewCount = 5;

  String? _departmentFilter;
  String _searchQuery = '';
  String? _statusFilter;

  static const _statusFilters = <String?>[
    null,
    'available',
    'reserved',
    'borrowed',
    'maintenance',
    'damaged',
    'lost',
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_InventoryData> _load() async {
    final labs = await _labService.fetchAllLaboratories();
    final types = await _service.fetchTypes();
    final assets = await _service.fetchAssets();
    return _InventoryData(labs: labs, types: types, assets: assets);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selected.clear();
    });
  }

  void _toggleSelect(String assetId) {
    setState(() {
      if (_selected.contains(assetId)) {
        _selected.remove(assetId);
      } else {
        _selected.add(assetId);
      }
    });
  }

  Future<void> _addType() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddEquipmentTypeScreen()),
    );
    if (created == true && mounted) await _refresh();
  }

  Future<void> _addAsset({
    List<EquipmentType>? types,
    String? preselected,
  }) async {
    final allTypes = types ?? (await _service.fetchTypes());
    if (!mounted) return;

    if (allTypes.isEmpty) {
      AppFeedback.info(context, 'Add an equipment type first.');
      return;
    }

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEquipmentAssetScreen(
          types: allTypes,
          preselectedTypeId: preselected,
        ),
      ),
    );
    if (created == true && mounted) await _refresh();
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.delete_outline,
          size: 32,
          color: Color(0xFFC62828),
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _deleteType(EquipmentType type) async {
    final confirm = await _confirmDelete(
      title: 'Delete equipment type?',
      message: 'This will also delete all assets under "${type.name}". '
          'This cannot be undone.',
    );
    if (!confirm) return;
    if (!mounted) return;

    try {
      await _service.deleteType(type.id);
      if (!mounted) return;
      AppFeedback.success(context, 'Type "${type.name}" deleted');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('📋 [inventory] delete type failed: $e');
      AppFeedback.error(context, 'Could not delete type. Please try again.');
    }
  }

  Future<void> _bulkChangeStatus() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;

    final newStatus = await showModalBottomSheet<String>(
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
                    'Set status',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Applies to ${ids.length} selected asset(s)',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            ..._assetStatuses.map(
              (s) => ListTile(
                leading: _StatusDot(color: _statusColor(s), size: 14),
                title: Text(_cap(s)),
                onTap: () => Navigator.pop(ctx, s),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (newStatus == null) return;
    if (!mounted) return;

    try {
      await _service.bulkUpdateStatus(assetIds: ids, status: newStatus);
      if (!mounted) return;
      AppFeedback.success(
        context,
        '${ids.length} asset${ids.length == 1 ? '' : 's'} updated to ${_cap(newStatus)}',
      );
      _exitSelectMode();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('📋 [inventory] bulk status failed: $e');
      AppFeedback.error(context, 'Could not update status. Please try again.');
    }
  }

  Future<void> _bulkDelete() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;

    final confirm = await _confirmDelete(
      title: 'Delete selected assets?',
      message: 'You are about to delete ${ids.length} asset(s). '
          'This cannot be undone.',
    );

    if (!confirm) return;
    if (!mounted) return;

    try {
      await _service.bulkDeleteAssets(ids);
      if (!mounted) return;
      AppFeedback.success(
        context,
        '${ids.length} asset${ids.length == 1 ? '' : 's'} deleted',
      );
      _exitSelectMode();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('📋 [inventory] bulk delete failed: $e');
      AppFeedback.error(context, 'Could not delete assets. Please try again.');
    }
  }

  void _selectAll(List<EquipmentAsset> allAssets) {
    setState(() {
      _selected
        ..clear()
        ..addAll(allAssets.map((a) => a.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BorrowLogAppBar(
        title: _selectMode ? '${_selected.length} selected' : 'Inventory',
        leading: _selectMode
            ? IconButton(
                tooltip: 'Cancel selection',
                icon: const Icon(Icons.close),
                onPressed: _exitSelectMode,
              )
            : null,
        actions: _selectMode
            ? [
                IconButton(
                  tooltip: 'Select all',
                  icon: const Icon(Icons.select_all),
                  onPressed: () {
                    _future.then((data) {
                      if (!mounted) return;
                      _selectAll(data.assets);
                    });
                  },
                ),
                IconButton(
                  tooltip: 'Clear selection',
                  icon: const Icon(Icons.deselect),
                  onPressed: () => setState(_selected.clear),
                ),
              ]
            : [
                IconButton(
                  tooltip: 'Select assets',
                  icon: const Icon(Icons.checklist),
                  onPressed: () => setState(() => _selectMode = true),
                ),
              ],
      ),
      body: FutureBuilder<_InventoryData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const BorrowLogSkeletonList(itemCount: 6);
          }
          if (snapshot.hasError) {
            return BorrowLogErrorState(
              message: 'Failed to load inventory:\n${snapshot.error}',
              onRetry: _refresh,
            );
          }

          final data = snapshot.data!;
          if (data.types.isEmpty && data.labs.isEmpty) {
            return _emptyState();
          }
          return RefreshIndicator(onRefresh: _refresh, child: _body(data));
        },
      ),
      bottomNavigationBar:
          _selectMode && _selected.isNotEmpty ? _selectionBar() : null,
      floatingActionButton: _selectMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _addType,
              icon: const Icon(Icons.add),
              label: const Text('Add type'),
            ),
    );
  }

  Widget _body(_InventoryData data) {
    final Map<String, List<EquipmentType>> byLab = {};
    final Map<String, Laboratory> labById = {};

    for (final lab in data.labs) {
      labById[lab.id] = lab;
      byLab[lab.id] = [];
    }

    for (final type in data.types) {
      final lid = type.laboratoryId;
      if (lid == null) continue;
      byLab.putIfAbsent(lid, () => []).add(type);
    }

    final departments = data.labs.map((l) => l.department).toSet().toList()
      ..sort();

    final visibleLabs = _departmentFilter == null
        ? data.labs
        : data.labs.where((l) => l.department == _departmentFilter).toList();

    final query = _searchQuery.trim().toLowerCase();
    final filteredLabs = visibleLabs.where((lab) {
      final labTypes = byLab[lab.id] ?? [];
      return query.isEmpty ||
          lab.name.toLowerCase().contains(query) ||
          lab.building.toLowerCase().contains(query) ||
          labTypes.any((type) => _typeMatches(type, data, query));
    }).toList();

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            AppSearchBar(
              controller: _searchController,
              hintText: 'Search equipment...',
              onChanged: (value) => setState(() => _searchQuery = value),
              onClear: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
            const SizedBox(height: 10),
            _filterBar(departments),
            const SizedBox(height: 4),
            _summaryLine(filteredLabs.length, data),
            if (filteredLabs.isEmpty) _noResults(),
            ...filteredLabs.map((lab) {
              final labTypes = byLab[lab.id] ?? [];
              return _labSection(lab, labTypes, data);
            }),
          ],
        ),
      ),
    );
  }

  Widget _filterBar(List<String> departments) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _showFilterSheet(departments),
              icon: Badge(
                isLabelVisible: _activeFilterCount > 0,
                label: Text('$_activeFilterCount'),
                child: const Icon(Icons.tune, size: 18),
              ),
              label: const Text('Filters'),
            ),
            const SizedBox(width: 8),
            if (_activeFilterCount > 0)
              TextButton(
                onPressed: () => setState(() {
                  _statusFilter = null;
                  _departmentFilter = null;
                }),
                child: const Text('Clear all'),
              ),
          ],
        ),
        if (_activeFilterCount > 0) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (_statusFilter != null)
                InputChip(
                  avatar: _StatusDot(color: _statusColor(_statusFilter!)),
                  label: Text(_cap(_statusFilter!)),
                  onDeleted: () => setState(() => _statusFilter = null),
                  deleteButtonTooltipMessage: 'Remove status filter',
                  backgroundColor: scheme.surface,
                ),
              if (_departmentFilter != null)
                InputChip(
                  avatar: const Icon(Icons.account_balance_outlined, size: 16),
                  label: Text(_departmentFilter!),
                  onDeleted: () => setState(() => _departmentFilter = null),
                  deleteButtonTooltipMessage: 'Remove department filter',
                  backgroundColor: scheme.surface,
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _summaryLine(int labCount, _InventoryData data) {
    final scheme = Theme.of(context).colorScheme;
    final available = data.assets.where((a) => a.status == 'available').length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Text(
        '$labCount lab(s) · ${data.assets.length} units · $available available',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
      ),
    );
  }

  Widget _noResults() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.maroon.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 36,
              color: AppTheme.maroon,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No matching assets',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Try a different search or clear your filters.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  bool _typeMatches(EquipmentType type, _InventoryData data, String query) {
    if (type.name.toLowerCase().contains(query) ||
        (type.category?.toLowerCase().contains(query) ?? false)) {
      return true;
    }
    return data.assets.any(
      (asset) =>
          asset.equipmentTypeId == type.id &&
          asset.propertyNumber.toLowerCase().contains(query) &&
          _matchesStatus(asset),
    );
  }

  bool _matchesStatus(EquipmentAsset asset) =>
      _statusFilter == null || asset.status == _statusFilter;

  int get _activeFilterCount =>
      (_statusFilter == null ? 0 : 1) + (_departmentFilter == null ? 0 : 1);

  Future<void> _showFilterSheet(List<String> departments) async {
    final result = await showModalBottomSheet<_InventoryFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _InventoryFilterSheet(
        departments: departments,
        status: _statusFilter,
        department: _departmentFilter,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _statusFilter = result.status;
      _departmentFilter = result.department;
    });
  }

  Widget _labSection(
    Laboratory lab,
    List<EquipmentType> types,
    _InventoryData data,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final query = _searchQuery.trim().toLowerCase();
    final visibleTypes = types.where((type) {
      if (query.isEmpty) return true;
      return _typeMatches(type, data, query);
    }).toList();
    final totalUnits = types.fold<int>(
      0,
      (sum, t) =>
          sum + data.assets.where((a) => a.equipmentTypeId == t.id).length,
    );

    final hasEntries = totalUnits > 0;
    final accent = hasEntries ? AppTheme.maroon : const Color(0xFFB26A00);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ExpansionTile(
        key: PageStorageKey('lab-${lab.id}-${query.isNotEmpty}'),
        initiallyExpanded: query.isNotEmpty,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.meeting_room_outlined, color: accent),
        ),
        title: Text(
          lab.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                lab.building,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              _MiniTag(label: '${types.length} types'),
              _MiniTag(label: '$totalUnits units'),
              if (!hasEntries)
                const _MiniTag(
                  label: 'Empty lab',
                  background: Color(0xFFFFF3D6),
                  foreground: Color(0xFF8A5300),
                ),
            ],
          ),
        ),
        children: [
          if (visibleTypes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No equipment types in this laboratory yet. '
                'Use "Add type" to create one.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            )
          else
            ...visibleTypes.map((t) => _typeSubCard(t, data)),
        ],
      ),
    );
  }

  Widget _typeSubCard(EquipmentType type, _InventoryData data) {
    final scheme = Theme.of(context).colorScheme;
    final assets = data.assets
        .where(
          (a) =>
              a.equipmentTypeId == type.id &&
              _matchesStatus(a) &&
              (_searchQuery.trim().isEmpty ||
                  type.name.toLowerCase().contains(
                        _searchQuery.trim().toLowerCase(),
                      ) ||
                  a.propertyNumber.toLowerCase().contains(
                        _searchQuery.trim().toLowerCase(),
                      )),
        )
        .toList();
    final total =
        data.assets.where((asset) => asset.equipmentTypeId == type.id).length;
    final available = data.assets
        .where((a) => a.equipmentTypeId == type.id && a.status == 'available')
        .length;
    final borrowed = data.assets
        .where((a) => a.equipmentTypeId == type.id && a.status == 'borrowed')
        .length;

    final showAll = _showAllUnits.contains(type.id);
    final shown = showAll ? assets : assets.take(_unitPreviewCount).toList();
    final hidden = assets.length - shown.length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: PageStorageKey('type-${type.id}'),
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.only(left: 12, right: 4),
          childrenPadding: const EdgeInsets.only(bottom: 6),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.maroon.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.memory, color: AppTheme.maroon, size: 20),
          ),
          title: Text(
            type.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : available / total,
                    minHeight: 6,
                    backgroundColor: scheme.outlineVariant,
                    color: _statusColor('available'),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '$available/$total available',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _statusColor('available'),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (borrowed > 0)
                      Text(
                        '$borrowed borrowed',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _statusColor('borrowed'),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    if (type.category != null)
                      _MiniTag(label: type.category!),
                  ],
                ),
              ],
            ),
          ),
          trailing: PopupMenuButton<String>(
            tooltip: 'Type options',
            icon: const Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (value) {
              if (value == 'add') {
                _addAsset(types: data.types, preselected: type.id);
              } else if (value == 'delete') {
                _deleteType(type);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'add',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Add assets'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline,
                        size: 20, color: Color(0xFFC62828)),
                    SizedBox(width: 12),
                    Text(
                      'Delete type',
                      style: TextStyle(color: Color(0xFFC62828)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            if (assets.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No units to show. Use "Add assets" to create some.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              )
            else ...[
              ...shown.map((a) => _assetTile(a, type)),
              if (assets.length > _unitPreviewCount)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        if (showAll) {
                          _showAllUnits.remove(type.id);
                        } else {
                          _showAllUnits.add(type.id);
                        }
                      }),
                      icon: Icon(
                        showAll ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                      ),
                      label: Text(
                        showAll ? 'Show fewer' : 'Show $hidden more',
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _assetTile(EquipmentAsset asset, EquipmentType type) {
    final scheme = Theme.of(context).colorScheme;

    if (_selectMode) {
      final selected = _selected.contains(asset.id);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Material(
          color: selected
              ? AppTheme.maroon.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _toggleSelect(asset.id),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: selected,
                      onChanged: (_) => _toggleSelect(asset.id),
                    ),
                    Expanded(
                      child: Text(
                        asset.propertyNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    BorrowLogStatusChip.asset(asset.status),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showAssetActions(asset, type),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Semantics(
                  label: 'QR code for ${asset.propertyNumber}',
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Icon(
                      Icons.qr_code_2,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    asset.propertyNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                BorrowLogStatusChip.asset(asset.status),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: AppTheme.maroon.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 52,
                color: AppTheme.maroon,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No equipment yet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Start by adding an equipment type, then add individual assets.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _addType,
              icon: const Icon(Icons.add),
              label: const Text('Add equipment type'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.maroon,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectionBar() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: scheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_selected.length} selected',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _bulkDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC62828),
                  side: const BorderSide(color: Color(0xFFC62828)),
                  minimumSize: const Size(0, 44),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _bulkChangeStatus,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Set status'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.maroon,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAssetActions(
    EquipmentAsset asset,
    EquipmentType type,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.maroon.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.qr_code_2,
                        color: AppTheme.maroon,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asset.propertyNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            type.name,
                            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    BorrowLogStatusChip.asset(asset.status),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'CHANGE STATUS',
                  style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _assetStatuses.map((s) {
                    final isCurrent = s == asset.status;
                    return ChoiceChip(
                      avatar: _StatusDot(color: _statusColor(s)),
                      label: Text(_cap(s)),
                      selected: isCurrent,
                      onSelected: (_) => Navigator.pop(ctx, 'status:$s'),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFC62828),
                  ),
                  title: const Text(
                    'Delete asset',
                    style: TextStyle(color: Color(0xFFC62828)),
                  ),
                  onTap: () => Navigator.pop(ctx, 'delete'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == null) return;
    if (!mounted) return;

    if (action == 'delete') {
      final confirm = await _confirmDelete(
        title: 'Delete asset?',
        message: 'Delete ${asset.propertyNumber}? This cannot be undone.',
      );

      if (!confirm) return;
      if (!mounted) return;

      try {
        await _service.deleteAsset(asset.id);
        if (!mounted) return;
        AppFeedback.success(
          context,
          'Asset ${asset.propertyNumber} deleted',
        );
        await _refresh();
      } catch (e) {
        if (!mounted) return;
        // ignore: avoid_print
        print('📋 [inventory] delete asset failed: $e');
        AppFeedback.error(context, 'Could not delete asset. Please try again.');
      }
    } else if (action.startsWith('status:')) {
      final newStatus = action.substring('status:'.length);
      try {
        await _service.updateAsset(id: asset.id, status: newStatus);
        if (!mounted) return;
        AppFeedback.success(
          context,
          '${asset.propertyNumber} → ${_cap(newStatus)}',
        );
        await _refresh();
      } catch (e) {
        if (!mounted) return;
        // ignore: avoid_print
        print('📋 [inventory] update status failed: $e');
        AppFeedback.error(context, 'Could not update status. Please try again.');
      }
    }
  }

  static const _assetStatuses = [
    'available',
    'reserved',
    'borrowed',
    'damaged',
    'lost',
    'maintenance',
  ];
}

// ---------------------------------------------------------------------------
// Small UI helpers (unchanged)
// ---------------------------------------------------------------------------

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, this.background, this.foreground});

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground ?? scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _InventoryFilters {
  const _InventoryFilters({this.status, this.department});

  final String? status;
  final String? department;
}

class _InventoryFilterSheet extends StatefulWidget {
  const _InventoryFilterSheet({
    required this.departments,
    required this.status,
    required this.department,
  });

  final List<String> departments;
  final String? status;
  final String? department;

  @override
  State<_InventoryFilterSheet> createState() => _InventoryFilterSheetState();
}

class _InventoryFilterSheetState extends State<_InventoryFilterSheet> {
  static const _all = '__all__';
  late String _status;
  late String _department;

  @override
  void initState() {
    super.initState();
    _status = widget.status ?? _all;
    _department = widget.department ?? _all;
  }

  Widget _sectionLabel(String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statuses = [
      _all,
      ..._InventoryScreenState._statusFilters.whereType<String>(),
    ];
    final departments = [_all, ...widget.departments];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filter inventory',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            _sectionLabel('Status'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: statuses.map((value) {
                return ChoiceChip(
                  avatar: value == _all
                      ? null
                      : _StatusDot(color: _statusColor(value)),
                  label: Text(value == _all ? 'All statuses' : _cap(value)),
                  selected: _status == value,
                  onSelected: (_) => setState(() => _status = value),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
            _sectionLabel('Department'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: departments.map((value) {
                return ChoiceChip(
                  label: Text(value == _all ? 'All departments' : value),
                  selected: _department == value,
                  onSelected: (_) => setState(() => _department = value),
                );
              }).toList(),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _status = _all;
                      _department = _all;
                    }),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      _InventoryFilters(
                        status: _status == _all ? null : _status,
                        department: _department == _all ? null : _department,
                      ),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Apply filters'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.maroon,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryData {
  final List<Laboratory> labs;
  final List<EquipmentType> types;
  final List<EquipmentAsset> assets;

  _InventoryData({
    required this.labs,
    required this.types,
    required this.assets,
  });
}