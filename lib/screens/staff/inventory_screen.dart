import 'package:flutter/material.dart';

import '../../models/equipment_type.dart';
import '../../models/equipment_asset.dart';
import '../../models/laboratory.dart';
import '../../services/inventory_service.dart';
import '../../services/laboratory_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/borrow_log_app_bar.dart';
import '../../widgets/borrow_log_states.dart';
import 'add_equipment_type_screen.dart';
import 'add_equipment_asset_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _service = InventoryService();
  final _labService = LaboratoryService();

  late Future<_InventoryData> _future;

  bool _selectMode = false;
  final Set<String> _selected = {};

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an equipment type first.')),
      );
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

  Future<void> _deleteType(EquipmentType type) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete equipment type?'),
        content: Text(
          'This will also delete all assets under "${type.name}". '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    try {
      await _service.deleteType(type.id);
      if (!mounted) return;
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _bulkChangeStatus() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;

    final newStatus = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Set status for ${ids.length} asset(s)'),
              subtitle: const Text('Pick a new status'),
            ),
            const Divider(height: 1),
            ..._assetStatuses.map(
              (s) => ListTile(
                leading: const Icon(Icons.label_outline),
                title: Text(s[0].toUpperCase() + s.substring(1)),
                onTap: () => Navigator.pop(ctx, s),
              ),
            ),
          ],
        ),
      ),
    );

    if (newStatus == null) return;
    if (!mounted) return;

    try {
      await _service.bulkUpdateStatus(assetIds: ids, status: newStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated ${ids.length} asset(s).')),
      );
      _exitSelectMode();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  Future<void> _bulkDelete() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected assets?'),
        content: Text(
          'You are about to delete ${ids.length} asset(s). '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      await _service.bulkDeleteAssets(ids);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${ids.length} asset(s).')),
      );
      _exitSelectMode();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
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
        title: _selectMode
            ? '${_selected.length} selected'
          : 'Inventory',
        leading: _selectMode
            ? IconButton(
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
                  tooltip: 'Clear',
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
                IconButton(
                  tooltip: 'Add equipment type',
                  icon: const Icon(Icons.add_box_outlined),
                  onPressed: _addType,
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
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _body(data),
          );
        },
      ),
      bottomNavigationBar: _selectMode && _selected.isNotEmpty
          ? _selectionBar()
          : null,
    );
  }

  Widget _body(_InventoryData data) {
    // Group types by laboratory
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

    // Department filter chips
    final departments = data.labs
        .map((l) => l.department)
        .toSet()
        .toList()
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

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search equipment, property number, lab, or building',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _searchQuery = ''),
                  ),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _showFilterSheet(departments),
              icon: const Icon(Icons.tune, size: 18),
              label: Text(_activeFilterCount == 0
                  ? 'Filters'
                  : 'Filters ($_activeFilterCount)'),
            ),
            if (_activeFilterCount > 0) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() {
                  _statusFilter = null;
                  _departmentFilter = null;
                }),
                child: const Text('Clear'),
              ),
            ],
            const Spacer(),
            if (_activeFilterCount > 0)
              Flexible(
                child: Text(
                  _filterSummary,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
        if (filteredLabs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'No assets match the current search and filters.',
              textAlign: TextAlign.center,
            ),
          ),
        ...filteredLabs.map((lab) {
          final labTypes = byLab[lab.id] ?? [];
          return _labSection(lab, labTypes, data);
        }),
      ],
    );
  }

  bool _typeMatches(
      EquipmentType type, _InventoryData data, String query) {
    if (type.name.toLowerCase().contains(query) ||
        (type.category?.toLowerCase().contains(query) ?? false)) {
      return true;
    }
    return data.assets.any((asset) =>
        asset.equipmentTypeId == type.id &&
        asset.propertyNumber.toLowerCase().contains(query) &&
        _matchesStatus(asset));
  }

  bool _matchesStatus(EquipmentAsset asset) =>
      _statusFilter == null || asset.status == _statusFilter;

  int get _activeFilterCount =>
      (_statusFilter == null ? 0 : 1) + (_departmentFilter == null ? 0 : 1);

  String get _filterSummary {
    final values = <String>[];
    if (_statusFilter != null) {
      values.add(_statusFilter![0].toUpperCase() + _statusFilter!.substring(1));
    }
    if (_departmentFilter != null) values.add(_departmentFilter!);
    return values.join(' · ');
  }

  Future<void> _showFilterSheet(List<String> departments) async {
    final result = await showModalBottomSheet<_InventoryFilters>(
      context: context,
      isScrollControlled: true,
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        leading: Icon(
          hasEntries ? Icons.meeting_room_outlined : Icons.meeting_room_outlined,
          color: hasEntries ? AppTheme.maroon : Colors.amber.shade800,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                lab.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (!hasEntries)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Empty lab',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${lab.building} · ${types.length} type(s) · $totalUnits unit(s)',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          if (visibleTypes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No equipment types in this laboratory yet. '
                'Use "Add type" to create one.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            ...visibleTypes.map((t) => _typeSubCard(t, data)),
        ],
      ),
    );
  }

  Widget _typeSubCard(EquipmentType type, _InventoryData data) {
    final assets = data.assets
      .where((a) =>
        a.equipmentTypeId == type.id &&
        _matchesStatus(a) &&
        (_searchQuery.trim().isEmpty ||
          type.name
            .toLowerCase()
            .contains(_searchQuery.trim().toLowerCase()) ||
          a.propertyNumber
            .toLowerCase()
            .contains(_searchQuery.trim().toLowerCase())))
        .toList();
    final available = assets.where((a) => a.status == 'available').length;
    final borrowed = assets.where((a) => a.status == 'borrowed').length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Card(
        elevation: 0,
        color: Colors.grey.shade50,
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ExpansionTile(
          leading: const Icon(Icons.memory, color: AppTheme.maroon, size: 20),
          title: Text(
            type.name,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            '${assets.length} unit(s) · $available available · $borrowed borrowed'
            '${type.category != null ? ' · ${type.category}' : ''}',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'add') {
                _addAsset(types: data.types, preselected: type.id);
              } else if (value == 'delete') {
                _deleteType(type);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'add', child: Text('Add assets')),
              PopupMenuItem(value: 'delete', child: Text('Delete type')),
            ],
          ),
          children: [
            if (assets.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No units yet. Use "Add assets" to create some.'),
              )
            else
              ...assets.map((a) => _assetTile(a, type)),
          ],
        ),
      ),
    );
  }

  Widget _assetTile(EquipmentAsset asset, EquipmentType type) {
    if (_selectMode) {
      final selected = _selected.contains(asset.id);
      return CheckboxListTile(
        dense: true,
        value: selected,
        onChanged: (_) => _toggleSelect(asset.id),
        title: Text(asset.propertyNumber),
        subtitle: Text(asset.statusLabel),
        secondary: BorrowLogStatusChip.asset(asset.status),
      );
    }

    return ListTile(
      dense: true,
      leading: const Icon(Icons.qr_code_2, size: 20),
      title: Text(asset.propertyNumber),
      subtitle: Text(asset.statusLabel),
      trailing: BorrowLogStatusChip.asset(asset.status),
      onTap: () => _showAssetActions(asset, type),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 64, color: AppTheme.maroon),
            const SizedBox(height: 16),
            const Text(
              'No equipment yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start by adding an equipment type, then add individual assets.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _addType,
              icon: const Icon(Icons.add),
              label: const Text('Add Equipment Type'),
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

  Widget _selectionBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.maroon,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${_selected.length} selected',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _bulkChangeStatus,
              icon: const Icon(Icons.edit, color: Colors.white, size: 18),
              label: const Text('Set status',
                  style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _bulkDelete,
              icon: const Icon(Icons.delete, color: Colors.white, size: 18),
              label:
                  const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAssetActions(
      EquipmentAsset asset, EquipmentType type) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(asset.propertyNumber),
              subtitle: Text('${type.name} · ${asset.statusLabel}'),
            ),
            const Divider(height: 1),
            ..._assetStatuses.map(
              (s) => ListTile(
                leading: Icon(
                  s == asset.status
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: s == asset.status ? AppTheme.maroon : null,
                ),
                title: Text(
                    'Set status: ${s[0].toUpperCase()}${s.substring(1)}'),
                onTap: () => Navigator.pop(ctx, 'status:$s'),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete asset',
                  style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (action == null) return;
    if (!mounted) return;

    if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete asset?'),
          content: Text('Delete ${asset.propertyNumber}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm != true) return;
      if (!mounted) return;

      try {
        await _service.deleteAsset(asset.id);
        if (!mounted) return;
        await _refresh();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    } else if (action.startsWith('status:')) {
      final newStatus = action.substring('status:'.length);
      try {
        await _service.updateAsset(id: asset.id, status: newStatus);
        if (!mounted) return;
        await _refresh();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
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

  @override
  Widget build(BuildContext context) {
    final statuses = [
      _all,
      ..._InventoryScreenState._statusFilters.whereType<String>(),
    ];
    final departments = [_all, ...widget.departments];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filter inventory',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.label_outline),
              ),
              items: statuses
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value == _all
                            ? 'All statuses'
                            : value[0].toUpperCase() + value.substring(1)),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _department,
              decoration: const InputDecoration(
                labelText: 'Department',
                prefixIcon: Icon(Icons.account_balance_outlined),
              ),
              items: departments
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value == _all ? 'All departments' : value),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _department = value);
              },
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                context,
                _InventoryFilters(
                  status: _status == _all ? null : _status,
                  department: _department == _all ? null : _department,
                ),
              ),
              icon: const Icon(Icons.check),
              label: const Text('Apply filters'),
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