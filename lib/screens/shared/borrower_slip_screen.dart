import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../models/reservation.dart';
import '../../models/reservation_asset.dart';
import '../../services/reservation_service.dart';
import '../../services/slip_pdf_service.dart';
import '../../theme/app_theme.dart';

class BorrowerSlipScreen extends StatefulWidget {
  final String reservationId;

  const BorrowerSlipScreen({super.key, required this.reservationId});

  @override
  State<BorrowerSlipScreen> createState() => _BorrowerSlipScreenState();
}

class _BorrowerSlipScreenState extends State<BorrowerSlipScreen> {
  final _service = ReservationService();
  final _pdfService = SlipPdfService();
  late Future<_SlipData?> _future;
  bool _generatingPdf = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SlipData?> _load() async {
    final reservation =
        await _service.fetchReservationById(widget.reservationId);
    if (reservation == null) return null;

    final links = await _service.fetchReservationAssets(widget.reservationId);
    final returns = await _service.fetchReturnConditions(widget.reservationId);

    return _SlipData(
      reservation: reservation,
      links: links,
      returns: returns,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _copySummary(_SlipData data) async {
    final buffer = StringBuffer();
    final r = data.reservation;

    buffer.writeln('BORROW LOG — Borrower\'s Slip');
    buffer.writeln('Slip ID: ${_shortId(r.id)}');
    buffer.writeln('');
    buffer.writeln('Borrower: ${r.studentName ?? r.studentId}');
    buffer.writeln('Subject: ${r.subject}'
        '${r.subjectCode != null ? ' (${r.subjectCode})' : ''}');
    buffer.writeln('Instructor: ${r.instructor}');
    buffer.writeln('Date of Use: ${r.useDateFormatted}'
        '${r.useTime != null ? ' · ${r.useTime}' : ''}');
    if (r.dueDateFormatted != null) {
      buffer.writeln('Due Date: ${r.dueDateFormatted}');
    }
    buffer.writeln('Status: ${r.statusLabel}');
    buffer.writeln('');
    buffer.writeln('Equipment:');
    if (data.links.isEmpty) {
      buffer.writeln('  (No Property Numbers assigned yet)');
    } else {
      for (final link in data.links) {
        final pn = link.asset?.propertyNumber ?? '—';
        final ret = data.returns[link.id];
        buffer.writeln('  • $pn'
            '${ret != null ? '  [returned: $ret]' : ''}');
      }
    }
    if (r.notes != null && r.notes!.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Notes: ${r.notes}');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Slip copied to clipboard.')),
    );
  }

  Future<void> _printPdf(_SlipData data) async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);

    try {
      final bytes = await _pdfService.buildBorrowerSlip(
        reservation: data.reservation,
        assets: data.links,
        returnConditions: data.returns,
      );

      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name:
            'BorrowerSlip_${data.reservation.id.substring(0, 8).toUpperCase()}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  String _shortId(String id) {
    if (id.length <= 8) return id.toUpperCase();
    return id.substring(0, 8).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrower\'s Slip'),
        actions: [
          FutureBuilder<_SlipData?>(
            future: _future,
            builder: (context, snap) {
              final hasData = snap.hasData && snap.data != null;
              return IconButton(
                tooltip: 'Print / Save PDF',
                icon: _generatingPdf
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf),
                onPressed: hasData && !_generatingPdf
                    ? () => _printPdf(snap.data!)
                    : null,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<_SlipData?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load slip:\n${snap.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          final data = snap.data;
          if (data == null) {
            return const Center(child: Text('Reservation not found.'));
          }
          return _buildSlip(data);
        },
      ),
      floatingActionButton: FutureBuilder<_SlipData?>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData || snap.data == null) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () => _copySummary(snap.data!),
            icon: const Icon(Icons.copy),
            label: const Text('Copy slip'),
            backgroundColor: AppTheme.maroon,
            foregroundColor: Colors.white,
          );
        },
      ),
    );
  }

  Widget _buildSlip(_SlipData data) {
    final r = data.reservation;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 40, color: AppTheme.maroon),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'BORROW LOG',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.maroon,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              'Laboratory Borrower\'s Slip',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      _statusChip(r),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(thickness: 1.4),
                  const SizedBox(height: 8),

                  // Slip ID
                  _kv('Slip ID', _shortId(r.id), mono: true),
                  const SizedBox(height: 12),

                  // Borrower section
                  _sectionTitle('Borrower Information'),
                  _kv('Name', r.studentName ?? r.studentId),
                  _kv('Subject', r.subject +
                      (r.subjectCode != null ? ' (${r.subjectCode})' : '')),
                  _kv('Instructor', r.instructor),
                  const SizedBox(height: 12),

                  // Use window
                  _sectionTitle('Use Window'),
                  _kv('Date of Use', r.useDateFormatted),
                  if (r.useTime != null) _kv('Time', r.useTime!),
                  if (r.dueDateFormatted != null)
                    _kv('Due Date', r.dueDateFormatted!),
                  if (r.releasedAt != null)
                    _kv('Released', _fmtDateTime(r.releasedAt!)),
                  if (r.returnedAt != null)
                    _kv('Returned', _fmtDateTime(r.returnedAt!)),
                  const SizedBox(height: 12),

                  // Equipment
                  _sectionTitle('Equipment on this Slip'),
                  if (data.links.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'No Property Numbers have been assigned yet.',
                        style: TextStyle(
                            color: Colors.black54,
                            fontStyle: FontStyle.italic),
                      ),
                    )
                  else
                    ...data.links.map((link) => _assetRow(link, data.returns)),
                  const SizedBox(height: 12),

                  // Notes
                  if (r.notes != null && r.notes!.isNotEmpty) ...[
                    _sectionTitle('Purpose / Notes'),
                    Text(r.notes!),
                    const SizedBox(height: 12),
                  ],

                  // Rejection reason if any
                  if (r.rejectionReason != null) ...[
                    _sectionTitle('Rejection Reason'),
                    Text(r.rejectionReason!,
                        style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                  ],

                  // Signatures
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _signatureLine('Borrower')),
                      const SizedBox(width: 24),
                      Expanded(child: _signatureLine('Laboratory Staff')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Generated by BORROW LOG',
                      style: TextStyle(fontSize: 11, color: Colors.black45),
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

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppTheme.maroon,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _kv(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontFamily: mono ? 'monospace' : null,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _assetRow(ReservationAsset link, Map<String, String> returns) {
    final asset = link.asset;
    final pn = asset?.propertyNumber ?? link.equipmentAssetId;
    final condition = returns[link.id];

    Color? conditionColor;
    if (condition == 'good') conditionColor = Colors.green;
    if (condition == 'damaged') conditionColor = Colors.orange;
    if (condition == 'lost') conditionColor = Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.qr_code_2, size: 18, color: AppTheme.maroon),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pn,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          if (condition != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: conditionColor!.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: conditionColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                condition[0].toUpperCase() + condition.substring(1),
                style: TextStyle(
                  fontSize: 11,
                  color: conditionColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (asset != null)
            Text(
              asset.statusLabel,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
        ],
      ),
    );
  }

  Widget _signatureLine(String label) {
    return Column(
      children: [
        Container(
          height: 1.2,
          color: Colors.black87,
          margin: const EdgeInsets.only(bottom: 4),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _statusChip(Reservation r) {
    Color color;
    String label = r.statusLabel;
    if (r.isOverdue) {
      color = Colors.red;
      label = 'Overdue';
    } else {
      switch (r.status) {
        case 'pending':
          color = Colors.orange;
          break;
        case 'approved':
          color = Colors.green;
          break;
        case 'rejected':
          color = Colors.red;
          break;
        case 'borrowed':
          color = Colors.blue;
          break;
        case 'completed':
          color = Colors.teal;
          break;
        case 'cancelled':
          color = Colors.grey;
          break;
        default:
          color = Colors.grey;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  String _fmtDateTime(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

class _SlipData {
  final Reservation reservation;
  final List<ReservationAsset> links;
  final Map<String, String> returns;

  _SlipData({
    required this.reservation,
    required this.links,
    required this.returns,
  });
}