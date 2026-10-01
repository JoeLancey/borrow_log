import 'package:flutter/material.dart';

import '../../models/equipment_type.dart';
import '../../services/inventory_service.dart';
import '../../theme/app_theme.dart';

class BulkAddAssetsScreen extends StatefulWidget {
  final EquipmentType equipmentType;

  const BulkAddAssetsScreen({super.key, required this.equipmentType});

  @override
  State<BulkAddAssetsScreen> createState() => _BulkAddAssetsScreenState();
}

class _BulkAddAssetsScreenState extends State<BulkAddAssetsScreen> {
  final _controller = TextEditingController();
  final _service = InventoryService();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Splits input on newlines and commas, trims, uppercases, de-duplicates
  /// within the batch, and drops empty entries.
  List<String> _parsePropertyNumbers() {
    final raw = _controller.text
        .split(RegExp(r'[\n,]'))
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toList();

    // De-duplicate within the batch while preserving order
    final seen = <String>{};
    final unique = <String>[];
    for (final pn in raw) {
      if (seen.add(pn)) unique.add(pn);
    }
    return unique;
  }

  Future<void> _submit() async {
    final pns = _parsePropertyNumbers();
    if (pns.isEmpty) {
      setState(() => _error = 'Enter at least one Property Number.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final created = <String>[];
    final failed = <MapEntry<String, String>>[];

    for (final pn in pns) {
      try {
        await _service.createAsset(
          equipmentTypeId: widget.equipmentType.id,
          propertyNumber: pn,
          status: 'available',
        );
        created.add(pn);
      } catch (e) {
        failed.add(MapEntry(pn, _shortError(e.toString())));
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);

    await _showSummary(created, failed);
    if (!mounted) return;

    if (failed.isEmpty) {
      Navigator.of(context).pop(true);
    } else {
      // Leave the screen open so they can fix the failures and re-submit.
      _controller.text = failed.map((e) => e.key).join('\n');
    }
  }

  String _shortError(String raw) {
    // Postgres unique-violation message
    if (raw.contains('duplicate key value') ||
        raw.contains('equipment_assets_property_number_key')) {
      return 'already exists';
    }
    if (raw.contains('violates row-level security')) {
      return 'permission denied';
    }
    // Fallback: first 80 chars
    if (raw.length > 80) return '${raw.substring(0, 80)}…';
    return raw;
  }

  Future<void> _showSummary(
    List<String> created,
    List<MapEntry<String, String>> failed,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          failed.isEmpty
              ? 'All ${created.length} created'
              : '${created.length} created · ${failed.length} failed',
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (created.isNotEmpty) ...[
                  const Text('Created:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...created.map((pn) => Text('• $pn',
                      style: const TextStyle(
                          color: Colors.green, fontSize: 13))),
                ],
                if (failed.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Failed:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...failed.map((e) => Text(
                        '• ${e.key} — ${e.value}',
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13),
                      )),
                  const SizedBox(height: 8),
                  const Text(
                    'The failed entries have been kept in the text field '
                    'so you can fix them and re-submit.',
                    style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _parsePropertyNumbers();
    final previewCount = preview.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bulk add · ${widget.equipmentType.name}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Paste one Property Number per line. Commas are also accepted.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: !_saving,
              maxLines: 12,
              minLines: 8,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ARD-001\nARD-002\nARD-003',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: _saving
                            ? null
                            : () => setState(_controller.clear),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    previewCount == 0
                        ? 'No valid entries yet.'
                        : '$previewCount unique Property Number(s) ready.',
                    style: TextStyle(
                      fontSize: 12,
                      color: previewCount == 0
                          ? Colors.black45
                          : Colors.green.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saving || previewCount == 0 ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.playlist_add),
                label: Text(
                  _saving
                      ? 'Creating…'
                      : 'CREATE ${previewCount > 0 ? previewCount : ''} ASSET(S)',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.maroon,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}