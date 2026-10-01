import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/reservation.dart';
import '../models/reservation_asset.dart';

/// Builds the PDF representation of a Borrower's Slip.
class SlipPdfService {
  /// Returns the PDF bytes for a given reservation + its assigned assets +
  /// the return conditions map (reservation_asset_id -> 'good'|'damaged'|'lost').
  Future<Uint8List> buildBorrowerSlip({
    required Reservation reservation,
    required List<ReservationAsset> assets,
    required Map<String, String> returnConditions,
  }) async {
    final doc = pw.Document(
      title: 'Borrower Slip ${_shortId(reservation.id)}',
      author: 'BORROW LOG',
      creator: 'BORROW LOG',
    );

    const maroon = PdfColor.fromInt(0xFF800000);
    const grey = PdfColor.fromInt(0xFF666666);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          _header(reservation, maroon),
          pw.SizedBox(height: 12),
          _infoBlock(reservation, maroon, grey),
          pw.SizedBox(height: 16),
          _equipmentBlock(assets, returnConditions, maroon, grey),
          pw.SizedBox(height: 16),
          if (reservation.notes != null && reservation.notes!.isNotEmpty)
            _notesBlock(reservation.notes!),
          if (reservation.rejectionReason != null)
            _rejectionBlock(reservation.rejectionReason!),
          pw.SizedBox(height: 32),
          _signatureBlock(grey),
          pw.SizedBox(height: 24),
          _footer(grey),
        ],
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------
  // SECTIONS
  // ---------------------------------------------------------

  pw.Widget _header(Reservation r, PdfColor maroon) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'BORROW LOG',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: maroon,
                letterSpacing: 1.5,
              ),
            ),
            pw.Text(
              "Laboratory Borrower's Slip",
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.Spacer(),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: maroon, width: 0.8),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
            _statusText(r),
            style: pw.TextStyle(
              color: maroon,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _infoBlock(
      Reservation r, PdfColor maroon, PdfColor grey) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(thickness: 1.2, color: maroon),
        pw.SizedBox(height: 8),
        _sectionTitle('Borrower Information', maroon),
        _kv('Slip ID', _shortId(r.id)),
        _kv('Name', r.studentName ?? r.studentId),
        _kv(
          'Subject',
          r.subject + (r.subjectCode != null ? ' (${r.subjectCode})' : ''),
        ),
        _kv('Instructor', r.instructor),
        pw.SizedBox(height: 10),
        _sectionTitle('Use Window', maroon),
        _kv('Date of Use', r.useDateFormatted),
        if (r.useTime != null) _kv('Time', r.useTime!),
        if (r.dueDateFormatted != null) _kv('Due Date', r.dueDateFormatted!),
        if (r.releasedAt != null)
          _kv('Released', _fmtDateTime(r.releasedAt!)),
        if (r.returnedAt != null)
          _kv('Returned', _fmtDateTime(r.returnedAt!)),
      ],
    );
  }

  pw.Widget _equipmentBlock(
    List<ReservationAsset> assets,
    Map<String, String> returnConditions,
    PdfColor maroon,
    PdfColor grey,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Equipment on this Slip', maroon),
        if (assets.isEmpty)
          pw.Text(
            'No Property Numbers have been assigned yet.',
            style: pw.TextStyle(
              fontSize: 11,
              color: grey,
              fontStyle: pw.FontStyle.italic,
            ),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Property Number', 'Status', 'Condition on Return'],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: maroon),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
            },
            data: assets.map((link) {
              final pn = link.asset?.propertyNumber ?? link.equipmentAssetId;
              final status = link.asset?.statusLabel ?? '—';
              final condition = returnConditions[link.id];
              return [
                pn,
                status,
                condition != null
                    ? condition[0].toUpperCase() + condition.substring(1)
                    : '—',
              ];
            }).toList(),
          ),
      ],
    );
  }

  pw.Widget _notesBlock(String notes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PURPOSE / NOTES',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF800000),
            letterSpacing: 1,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(notes, style: const pw.TextStyle(fontSize: 11)),
      ],
    );
  }

  pw.Widget _rejectionBlock(String reason) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'REJECTION REASON',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.red800,
            letterSpacing: 1,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          reason,
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.red800),
        ),
      ],
    );
  }

  pw.Widget _signatureBlock(PdfColor grey) {
    return pw.Row(
      children: [
        pw.Expanded(child: _signatureLine('Borrower', grey)),
        pw.SizedBox(width: 40),
        pw.Expanded(child: _signatureLine('Laboratory Staff', grey)),
      ],
    );
  }

  pw.Widget _signatureLine(String label, PdfColor grey) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(height: 0.9, color: PdfColors.black),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 10, color: grey),
        ),
      ],
    );
  }

  pw.Widget _footer(PdfColor grey) {
    return pw.Center(
      child: pw.Text(
        'Generated by BORROW LOG · ${_fmtDateTime(DateTime.now())}',
        style: pw.TextStyle(fontSize: 9, color: grey),
      ),
    );
  }

  // ---------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------

  pw.Widget _sectionTitle(String text, PdfColor maroon) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: maroon,
          letterSpacing: 1,
        ),
      ),
    );
  }

  pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  String _shortId(String id) {
    if (id.length <= 8) return id.toUpperCase();
    return id.substring(0, 8).toUpperCase();
  }

  String _statusText(Reservation r) {
    if (r.isOverdue) return 'Overdue';
    return r.statusLabel;
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