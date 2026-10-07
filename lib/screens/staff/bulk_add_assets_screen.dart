import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/equipment_type.dart';
import '../../services/inventory_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/borrow_log_app_bar.dart';

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

  // UI-only: progress shown while the batch is being created.
  int _done = 0;
  int _total = 0;

  static const _previewChipLimit = 12;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Splits input on newlines and commas, trims, uppercases, de-duplicates
  /// within the batch, and drops empty entries.
  List<String> _parsePropertyNumbers() {
    final raw = _rawEntries();

    // De-duplicate within the batch while preserving order
    final seen = <String>{};
    final unique = <String>[];
    for (final pn in raw) {
      if (seen.add(pn)) unique.add(pn);
    }
    return unique;
  }

  List<String> _rawEntries() {
    return _controller.text
        .split(RegExp(r'[\n,]'))
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty || !mounted) return;
    setState(() {
      final current = _controller.text;
      _controller.text = current.trim().isEmpty ? text : '$current\n$text';
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      _error = null;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final pns = _parsePropertyNumbers();
    if (pns.isEmpty) {
      setState(() => _error = 'Enter at least one Property Number.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _done = 0;
      _total = pns.length;
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
      if (mounted) setState(() => _done++);
    }

    if (!mounted) return;
    setState(() => _saving = false);

    // Log raw errors for debugging
    if (failed.isNotEmpty) {
      // ignore: avoid_print
      print('📋 [bulk-add] ${failed.length} failed: $failed');
    }

    await _showSummary(created, failed);
    if (!mounted) return;

    if (failed.isEmpty) {
      AppFeedback.success(
        context,
        '${created.length} asset${created.length == 1 ? '' : 's'} created',
      );
      Navigator.of(context).pop(true);
    } else {
      // Leave the screen open so they can fix the failures and re-submit.
      setState(() {
        _controller.text = failed.map((e) => e.key).join('\n');
      });
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

  // ---------------------------------------------------------
  // SUMMARY DIALOG
  // ---------------------------------------------------------

  Future<void> _showSummary(
    List<String> created,
    List<MapEntry<String, String>> failed,
  ) async {
    final allOk = failed.isEmpty;
    final green = Colors.green.shade700;
    final red = Colors.red.shade700;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;

        Widget group({
          required String title,
          required Color color,
          required IconData icon,
          required List<String> lines,
        }) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 140),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: lines
                        .map(
                          (l) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              l,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          );
        }

        return AlertDialog(
          icon: Icon(
            allOk ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            size: 36,
            color: allOk ? green : Colors.orange.shade800,
          ),
          title: Text(
            allOk
                ? 'All ${created.length} created'
                : '${created.length} created · ${failed.length} failed',
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (created.isNotEmpty)
                    group(
                      title: 'Created (${created.length})',
                      color: green,
                      icon: Icons.check_circle_outline,
                      lines: created,
                    ),
                  if (failed.isNotEmpty) ...[
                    if (created.isNotEmpty) const SizedBox(height: 14),
                    group(
                      title: 'Failed (${failed.length})',
                      color: red,
                      icon: Icons.error_outline,
                      lines: failed
                          .map((e) => '${e.key} — ${e.value}')
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'The failed entries were kept in the text field so you '
                      'can fix them and re-submit.',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.maroon,
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 44),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text(allOk ? 'Done' : 'Fix and retry'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = _parsePropertyNumbers();
    final previewCount = preview.length;
    final duplicates = _rawEntries().length - previewCount;
    final type = widget.equipmentType;

    return Scaffold(
      appBar: const BorrowLogAppBar(title: 'Bulk add assets'),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---- Equipment type header ----
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.maroon.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.maroon.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.memory,
                            color: AppTheme.maroon,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Adding units to',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                              Text(
                                type.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    'Property numbers',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Paste one per line, or separate them with commas. '
                    'Entries are uppercased and duplicates are removed '
                    'automatically.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _controller,
                    enabled: !_saving,
                    maxLines: 12,
                    minLines: 8,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      height: 1.5,
                    ),
                    onChanged: (_) => setState(() => _error = null),
                    decoration: InputDecoration(
                      hintText: 'ARD-001\nARD-002\nARD-003',
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: scheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _saving ? null : _paste,
                        icon: const Icon(Icons.content_paste, size: 18),
                        label: const Text('Paste'),
                      ),
                      if (_controller.text.isNotEmpty)
                        TextButton.icon(
                          onPressed: _saving
                              ? null
                              : () => setState(_controller.clear),
                          icon: const Icon(Icons.clear, size: 18),
                          label: const Text('Clear'),
                        ),
                    ],
                  ),

                  // ---- Live preview ----
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                previewCount == 0
                                    ? Icons.info_outline
                                    : Icons.check_circle_outline,
                                size: 18,
                                color: previewCount == 0
                                    ? scheme.onSurfaceVariant
                                    : Colors.green.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  previewCount == 0
                                      ? 'No valid entries yet.'
                                      : '$previewCount unique property number'
                                          '${previewCount == 1 ? '' : 's'} ready',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: previewCount == 0
                                        ? scheme.onSurfaceVariant
                                        : Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (duplicates > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              '$duplicates duplicate'
                              '${duplicates == 1 ? '' : 's'} in this list will '
                              'be skipped.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ],
                          if (previewCount > 0) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ...preview.take(_previewChipLimit).map(
                                      (pn) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: scheme.surfaceContainerHighest,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          pn,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                if (previewCount > _previewChipLimit)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      '+${previewCount - _previewChipLimit} more',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ---- Error ----
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.shade700.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 20,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ---- Progress while saving ----
                  if (_saving) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: _total == 0 ? null : _done / _total,
                        minHeight: 6,
                        color: AppTheme.maroon,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Creating $_done of $_total…',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
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
                            : previewCount > 0
                                ? 'Create $previewCount asset${previewCount == 1 ? '' : 's'}'
                                : 'Create assets',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.maroon,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}