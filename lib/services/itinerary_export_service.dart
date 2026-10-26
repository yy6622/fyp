import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../repositories/trip_repository.dart';

/// Builds a real "Export Itinerary" PDF (Group Setting > ... > Export
/// Itinerary) from a trip's actual day-by-day plan, flights, hotels and
/// expenses — previously that page's "Export" button only ever showed a
/// fake "Itinerary exported as PDF" SnackBar with nothing behind it (see
/// ExportItineraryController's old doc comment). Deliberately plain
/// widgets only (Container/Row/Column/Text, same as most of
/// PdfReportService) — no PdfGraphics/CustomPaint charts — since this
/// project has no Dart compiler available to check against the installed
/// `pdf` package version, and this file is new, unlike PdfReportService's
/// already-shipped chart code.
class ItineraryExportService {
  ItineraryExportService._();

  static const _navy = PdfColor.fromInt(0xFF104259); // AppColors.navy/primary
  static const _gray = PdfColor.fromInt(0xFF747474); // AppColors.textGrey
  static const _lightBg = PdfColor.fromInt(0xFFF4F4F4); // AppColors.chipGrey
  static const _gridLine = PdfColor.fromInt(0xFFD2D8DC);

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static String _fmtDate(DateTime? d) => d == null ? '—' : '${d.day} ${_monthNames[d.month - 1]} ${d.year}';

  static String _money(double v) {
    final rounded = v.round();
    final negative = rounded < 0;
    final digits = rounded.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return 'RM${negative ? '-' : ''}$buf';
  }

  static Future<Uint8List> _logoBytes() async {
    final data = await rootBundle.load('assets/images/voya_logo.png');
    return data.buffer.asUint8List();
  }

  /// Builds the PDF and returns its raw bytes. [expenses] is optional —
  /// a trip with no recorded expenses just skips that section rather than
  /// showing an empty table.
  static Future<Uint8List> buildItineraryPdf({required Trip trip, List<TripExpense> expenses = const []}) async {
    final logo = await _logoBytes();
    final doc = pw.Document();
    final totalExpenses = expenses.fold(0.0, (s, e) => s + e.amount);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 36),
        header: (context) => context.pageNumber == 1 ? _header(logo, trip) : pw.SizedBox(),
        footer: (context) => _footer(context),
        build: (context) => [
          if (trip.flights.isNotEmpty || trip.hotelStays.isNotEmpty || trip.insurance != null) ...[
            _sectionTitle('Bookings'),
            pw.SizedBox(height: 8),
            ..._bookingsSection(trip),
            pw.SizedBox(height: 16),
          ],
          _sectionTitle('Day-by-Day Plan'),
          pw.SizedBox(height: 8),
          ..._daysSection(trip),
          if (expenses.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _sectionTitle('Expenses (Total: ${_money(totalExpenses)})'),
            pw.SizedBox(height: 8),
            ..._expensesSection(expenses),
          ],
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _header(Uint8List logo, Trip trip) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Image(pw.MemoryImage(logo), height: 32),
            pw.Expanded(
              child: pw.Text(
                'ITINERARY',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold, color: _navy, letterSpacing: 0.4),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Text(trip.name.isEmpty ? 'Trip' : trip.name,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
        pw.SizedBox(height: 4),
        pw.Text(
          [
            if (trip.destination.isNotEmpty) trip.destination,
            if (trip.startDate != null && trip.endDate != null) '${_fmtDate(trip.startDate)} - ${_fmtDate(trip.endDate)}',
            '${trip.memberIds.length} member${trip.memberIds.length == 1 ? '' : 's'}',
          ].join(' · '),
          style: pw.TextStyle(fontSize: 10, color: _gray),
        ),
        pw.SizedBox(height: 4),
        pw.Text('Generated: ${_fmtDate(DateTime.now())}', style: pw.TextStyle(fontSize: 9, color: _gray)),
        pw.SizedBox(height: 12),
        pw.Container(height: 1.4, decoration: const pw.BoxDecoration(color: _navy)),
        pw.SizedBox(height: 14),
      ],
    );
  }

  static pw.Widget _sectionTitle(String text) => pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy, letterSpacing: 0.4),
      );

  static List<pw.Widget> _bookingsSection(Trip trip) {
    final widgets = <pw.Widget>[];
    for (final f in trip.flights) {
      widgets.add(_bookingRow(
        icon: 'Flight',
        title: [f.airline, f.flightNumber].where((s) => s.isNotEmpty).join(' '),
        line1: f.routeCities.isNotEmpty ? f.routeCities : f.routeCode,
        line2: f.dateTime,
        status: f.status,
      ));
    }
    for (final h in trip.hotelStays) {
      widgets.add(_bookingRow(
        icon: 'Hotel',
        title: h.name,
        line1: h.location,
        line2: [if (h.checkIn.isNotEmpty) 'Check-in: ${h.checkIn}', if (h.checkOut.isNotEmpty) 'Check-out: ${h.checkOut}'].join('  '),
        status: h.status,
      ));
    }
    final insurance = trip.insurance;
    if (insurance != null) {
      widgets.add(_bookingRow(
        icon: 'Insurance',
        title: insurance.planName,
        line1: insurance.coverage,
        line2: insurance.price,
        status: '',
      ));
    }
    return widgets;
  }

  static pw.Widget _bookingRow({required String icon, required String title, required String line1, required String line2, required String status}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(color: _lightBg, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 56,
            child: pw.Text(icon.toUpperCase(), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _navy)),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title.isEmpty ? '—' : title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                if (line1.isNotEmpty) pw.Text(line1, style: pw.TextStyle(fontSize: 8.5, color: _gray)),
                if (line2.isNotEmpty) pw.Text(line2, style: pw.TextStyle(fontSize: 8.5, color: _gray)),
              ],
            ),
          ),
          if (status.isNotEmpty)
            pw.Text(status, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _navy)),
        ],
      ),
    );
  }

  static List<pw.Widget> _daysSection(Trip trip) {
    if (trip.days.isEmpty) {
      return [pw.Text('No days planned yet.', style: pw.TextStyle(fontSize: 9.5, color: _gray))];
    }
    final widgets = <pw.Widget>[];
    for (final day in trip.days) {
      widgets.add(pw.Container(
        margin: const pw.EdgeInsets.only(top: 10, bottom: 6),
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _navy, width: 0.8))),
        child: pw.Text('Day ${day.day} · ${day.weekday} ${day.date}',
            style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _navy)),
      ));
      if (day.items.isEmpty) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 4, bottom: 4),
          child: pw.Text('Nothing planned for this day yet.', style: pw.TextStyle(fontSize: 8.5, color: _gray)),
        ));
        continue;
      }
      for (final item in day.items) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(width: 44, child: pw.Text(item.time, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _navy))),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item.label, style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.black)),
                    if (item.location.isNotEmpty) pw.Text(item.location, style: pw.TextStyle(fontSize: 8, color: _gray)),
                  ],
                ),
              ),
            ],
          ),
        ));
      }
    }
    return widgets;
  }

  static List<pw.Widget> _expensesSection(List<TripExpense> expenses) {
    final sorted = [...expenses]..sort((a, b) {
        final ad = a.date, bd = b.date;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    pw.Widget cell(String text, int flex, {bool header = false, pw.TextAlign align = pw.TextAlign.left}) => pw.Expanded(
          flex: flex,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: pw.Text(text,
                textAlign: align,
                style: pw.TextStyle(fontSize: 8.5, fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: header ? PdfColors.white : PdfColors.black)),
          ),
        );
    pw.Widget row(List<String> cells, {bool header = false, bool zebra = false}) => pw.Container(
          decoration: pw.BoxDecoration(
            color: header ? _navy : (zebra ? _lightBg : null),
            border: const pw.Border(bottom: pw.BorderSide(color: _gridLine, width: 0.6)),
          ),
          child: pw.Row(children: [
            cell(cells[0], 2, header: header),
            cell(cells[1], 4, header: header),
            cell(cells[2], 3, header: header),
            cell(cells[3], 3, header: header),
            cell(cells[4], 2, align: pw.TextAlign.right, header: header),
          ]),
        );
    final widgets = <pw.Widget>[row(const ['Date', 'Description', 'Category', 'Paid By', 'Amount'], header: true)];
    for (var i = 0; i < sorted.length; i++) {
      final e = sorted[i];
      final label = e.title.trim().isNotEmpty ? e.title.trim() : (e.note.trim().isNotEmpty ? e.note.trim() : e.category);
      widgets.add(row([
        _fmtDate(e.date),
        label,
        e.category,
        e.paidByName.isNotEmpty ? e.paidByName : '—',
        _money(e.amount),
      ], zebra: i.isOdd));
    }
    return widgets;
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Column(
      children: [
        pw.Container(height: 0.8, margin: const pw.EdgeInsets.only(bottom: 6), decoration: const pw.BoxDecoration(color: _navy)),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Voya - AI-Driven Contextual Travel Management', style: pw.TextStyle(fontSize: 7.5, color: _gray)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(fontSize: 7.5, color: _gray)),
          ],
        ),
      ],
    );
  }
}
