import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../controllers/expenses_controller.dart';
import '../repositories/trip_repository.dart';

/// Builds Voya-branded PDF reports. Currently just the Expenses report
/// (Personal / Group, from Expenses > Generate Report) — laid out to
/// match the project's own "Traveller Detailed Expense Report" design
/// reference exactly (same sections, same fields, same admin-style
/// navy/teal palette — admin_web/js/report-export.js's own colors, not
/// this app's single-navy AppColors, since the ask here was to copy the
/// admin report's look, not the app's): logo + bold title, a two-line
/// metadata block (Travel Plan / Travel Period / Generated, then
/// Traveller-or-Members / Currency / Report ID), a 3-stat row (Trip
/// Budget / Total Expenses / Remaining Budget), a Daily Expense Trend
/// line chart next to an Expenses by Category bar chart, a zebra-striped
/// Expense Transaction Detail table, and a "Page X of Y" footer. Every
/// number on the page comes from live Firestore data via
/// [ExpensesTabController.snapshotFor] — nothing here is sample/
/// placeholder content, only the page layout matches the design
/// reference.
///
/// Honest limitation: [_lineChartBody] draws with [pw.CustomPaint] +
/// [PdfGraphics] (moveTo/lineTo/drawEllipse/strokePath/fillPath) — this
/// project has no Dart compiler available to verify that exact API
/// surface against the installed `pdf` package version. If a build error
/// points at this file, that function is the most likely spot; the
/// category bar chart and everything else here is built from plain
/// Container/Row/Expanded (the same widgets already used throughout this
/// app) and carries much less of that risk.
class PdfReportService {
  PdfReportService._();

  // admin_web/js/report-export.js's own palette (admin_web/css/tokens.css:
  // --navy-800:#0e3a52, --teal-600:#1c7d8c), deliberately NOT this app's
  // single-navy AppColors — see the class doc comment above.
  static const _navy = PdfColor.fromInt(0xFF0E3A52);
  static const _teal = PdfColor.fromInt(0xFF1C7D8C);
  static const _gray = PdfColor.fromInt(0xFF6E6E6E);
  static const _zebraBg = PdfColor.fromInt(0xFFF5F8F9);
  static const _gridLine = PdfColor.fromInt(0xFFD2D8DC);

  // Same hand-written month-name approach already used throughout this
  // project (see e.g. lib/views/expenses/transaction_detail_page.dart) —
  // no `intl` package dependency anywhere in this project, so this
  // doesn't introduce one just for the PDF.
  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static String _fmtDate(DateTime? d) => d == null ? '—' : '${d.day} ${_monthNames[d.month - 1]} ${d.year}';

  /// RM with thousands separators and no decimals — matches the design
  /// reference exactly ("RM6,500", "RM2,100"), unlike the rest of the
  /// app's own `RM ${v.toStringAsFixed(2)}` style used on-screen.
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

  /// A bare rounded number, no "RM", no comma — matches the design
  /// reference's chart value/axis labels exactly (e.g. "2100", "500").
  static String _num0(double v) => v.round().toString();

  /// A cosmetic, locally-generated report id in the same shape as the
  /// design reference's ("VYA-TER-2026-0005") — purely a readable
  /// reference number printed on the document, not looked up or stored
  /// anywhere.
  static String _reportId(String code) {
    final now = DateTime.now();
    final n = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return 'VYA-$code-${now.year}-$n';
  }

  static Future<Uint8List> _logoBytes() async {
    final data = await rootBundle.load('assets/images/voya_logo.png');
    return data.buffer.asUint8List();
  }

  /// A "nice" axis max + step (5 even segments) for a chart whose largest
  /// value is [maxValue] — e.g. a real max of 2,180 rounds up to a 2,500
  /// axis in 500 steps, the same shape as the design reference's
  /// 0/500/.../2,500 axis, just computed from real data instead of fixed.
  static List<double> _niceAxis(double maxValue) {
    if (maxValue <= 0) return [500, 100];
    final rawStep = maxValue / 5;
    final magnitude = math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
    final residual = rawStep / magnitude;
    double niceStep;
    if (residual <= 1) {
      niceStep = magnitude;
    } else if (residual <= 2) {
      niceStep = 2 * magnitude;
    } else if (residual <= 5) {
      niceStep = 5 * magnitude;
    } else {
      niceStep = 10 * magnitude;
    }
    return [niceStep * 5, niceStep];
  }

  /// Builds the Expenses report (Personal or Group, per [snapshot]) and
  /// returns the raw PDF bytes. The caller (expenses_tab.dart) hands
  /// these to `Printing.layoutPdf`, which puts up the OS print/share/save
  /// sheet — this service never touches the filesystem itself.
  static Future<Uint8List> buildExpenseReport(ExpensesReportSnapshot snapshot) async {
    final logo = await _logoBytes();
    final doc = pw.Document();
    final trip = snapshot.trip;
    final title = snapshot.personal ? 'Traveller Detailed Expense Report' : 'Group Detailed Expense Report';
    final reportId = _reportId(snapshot.personal ? 'TER' : 'GER');
    final period = (trip?.startDate != null && trip?.endDate != null)
        ? '${_fmtDate(trip!.startDate)} - ${_fmtDate(trip.endDate)}'
        : 'Not set';

    final maxDaily = snapshot.dailyTotals.isEmpty ? 0.0 : snapshot.dailyTotals.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final maxCategory = snapshot.byCategory.isEmpty ? 0.0 : snapshot.byCategory.values.reduce((a, b) => a > b ? a : b);
    final dailyAxis = _niceAxis(maxDaily);
    final categoryAxis = _niceAxis(maxCategory);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 36),
        header: (context) => context.pageNumber == 1 ? _header(logo, title) : pw.SizedBox(),
        footer: (context) => _footer(context),
        build: (context) => [
          _metaRow(snapshot: snapshot, period: period, reportId: reportId, trip: trip),
          pw.SizedBox(height: 10),
          _divider(),
          pw.SizedBox(height: 10),
          _statRow(snapshot),
          pw.SizedBox(height: 10),
          _divider(),
          pw.SizedBox(height: 16),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Daily Expense Trend'),
                    pw.SizedBox(height: 8),
                    _lineChartBody(snapshot.dailyTotals, dailyAxis[0]),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Expenses by Category'),
                    pw.SizedBox(height: 8),
                    _categoryBarChart(snapshot.byCategory, categoryAxis[0]),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          _sectionTitle('Expense Transaction Detail'),
          pw.SizedBox(height: 8),
          ..._transactionTableWidgets(snapshot),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _header(Uint8List logo, String title) {
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
                title.toUpperCase(),
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold, color: _navy, letterSpacing: 0.4),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
      ],
    );
  }

  /// Two-line, three-column metadata block, matching the design
  /// reference exactly: Travel Plan / Travel Period / Generated on the
  /// first line, then Traveller (Personal) or Members (Group) / Currency
  /// / Report ID on the second.
  static pw.Widget _metaRow({required ExpensesReportSnapshot snapshot, required String period, required String reportId, Trip? trip}) {
    final generated = _fmtDate(DateTime.now());
    final tripName = (trip != null && trip.name.isNotEmpty) ? trip.name : 'Trip';
    final whoLabel = snapshot.personal ? 'Traveller: ${snapshot.generatedForName}' : 'Members: ${snapshot.memberCount} travellers';
    pw.Widget col(String text) => pw.Expanded(child: pw.Text(text, style: pw.TextStyle(fontSize: 9, color: _gray)));
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(children: [col('Travel Plan: $tripName'), col('Travel Period: $period'), col('Generated: $generated')]),
        pw.SizedBox(height: 4),
        pw.Row(children: [col(whoLabel), col('Currency: RM'), col('Report ID: $reportId')]),
      ],
    );
  }

  static pw.Widget _divider() => pw.Container(height: 1.4, decoration: const pw.BoxDecoration(color: _teal));

  static pw.Widget _statRow(ExpensesReportSnapshot snapshot) {
    final stats = [
      MapEntry('Trip Budget', _money(snapshot.tripBudget)),
      MapEntry('Total Expenses', _money(snapshot.totalExpenses)),
      MapEntry('Remaining Budget', _money(snapshot.remainingBudget)),
    ];
    final children = <pw.Widget>[];
    for (var i = 0; i < stats.length; i++) {
      if (i > 0) {
        children.add(pw.Container(
          width: 1,
          height: 38,
          margin: const pw.EdgeInsets.symmetric(horizontal: 16),
          decoration: const pw.BoxDecoration(color: _gridLine),
        ));
      }
      children.add(
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                stats[i].key.toUpperCase(),
                style: pw.TextStyle(fontSize: 8.5, color: _teal, fontWeight: pw.FontWeight.bold, letterSpacing: 0.4),
              ),
              pw.SizedBox(height: 5),
              pw.Text(stats[i].value, style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold, color: _navy)),
            ],
          ),
        ),
      );
    }
    return pw.Row(children: children);
  }

  static pw.Widget _sectionTitle(String text) => pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _navy, letterSpacing: 0.4),
      );

  /// Line chart (teal polyline + points over light gridlines), drawn with
  /// [pw.CustomPaint]/[PdfGraphics] — see the class doc comment's
  /// "Honest limitation" note on why this is the one part of this file
  /// that could not be checked against a real compiler.
  static pw.Widget _lineChartBody(List<MapEntry<DateTime, double>> daily, double niceMax) {
    const width = 230.0;
    const height = 110.0;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.CustomPaint(
          size: const PdfPoint(width, height),
          painter: (PdfGraphics canvas, PdfPoint size) {
            final w = size.x;
            final h = size.y;
            final n = daily.length;

            // Light horizontal gridlines (0/25/50/75/100% of the axis).
            canvas.setColor(_gridLine);
            canvas.setLineWidth(0.5);
            for (var g = 0; g <= 4; g++) {
              final gy = h * g / 4;
              canvas.moveTo(0, gy);
              canvas.lineTo(w, gy);
              canvas.strokePath();
            }

            if (n == 0) return;
            final stepX = n > 1 ? w / (n - 1) : 0.0;
            double xOf(int i) => n > 1 ? i * stepX : w / 2;
            double yOf(double v) => niceMax <= 0 ? 0 : (v / niceMax).clamp(0.0, 1.0) * h;

            // Trend polyline.
            canvas.setColor(_teal);
            canvas.setLineWidth(1.4);
            for (var i = 0; i < n; i++) {
              final x = xOf(i);
              final y = yOf(daily[i].value);
              if (i == 0) {
                canvas.moveTo(x, y);
              } else {
                canvas.lineTo(x, y);
              }
            }
            canvas.strokePath();

            // Data points.
            canvas.setColor(_teal);
            for (var i = 0; i < n; i++) {
              canvas.drawEllipse(xOf(i), yOf(daily[i].value), 1.6, 1.6);
              canvas.fillPath();
            }
          },
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: daily.map((e) => pw.Text('${e.key.day} ${_monthNames[e.key.month - 1]}', style: pw.TextStyle(fontSize: 6, color: _gray))).toList(),
        ),
      ],
    );
  }

  static pw.Widget _categoryBarChart(Map<String, double> byCategory, double niceMax) {
    final entries = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    const labelWidth = 60.0;
    const valueWidth = 36.0;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        ...entries.map((e) {
          final frac = niceMax <= 0 ? 0.0 : (e.value / niceMax).clamp(0.0, 1.0);
          final filled = (frac * 1000).round().clamp(0, 1000);
          final empty = 1000 - filled;
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 7),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(width: labelWidth, child: pw.Text(e.key, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black))),
                pw.Expanded(
                  child: pw.Container(
                    height: 9,
                    child: pw.Row(
                      children: [
                        if (filled > 0) pw.Expanded(flex: filled, child: pw.Container(decoration: const pw.BoxDecoration(color: _teal))),
                        if (empty > 0) pw.Expanded(flex: empty, child: pw.Container(decoration: const pw.BoxDecoration(color: _gridLine))),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 4),
                pw.SizedBox(
                  width: valueWidth,
                  child: pw.Text(_num0(e.value), style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black)),
                ),
              ],
            ),
          );
        }),
        pw.SizedBox(height: 2),
        pw.Row(
          children: [
            pw.SizedBox(width: labelWidth),
            pw.Expanded(
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: List.generate(5, (i) => pw.Text(_num0(niceMax / 4 * i), style: pw.TextStyle(fontSize: 6.5, color: _gray))),
              ),
            ),
            pw.SizedBox(width: valueWidth + 4),
          ],
        ),
      ],
    );
  }

  // Date / Description / Category / Paid By / Amount / Receipt / Status —
  // same order as the design reference (Amount before Receipt/Status).
  static const List<int> _colFlex = [2, 4, 3, 3, 3, 2, 2];

  static pw.Widget _tableCell(String text, int flex, {bool header = false, PdfColor? color, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? (header ? PdfColors.white : PdfColors.black),
          ),
        ),
      ),
    );
  }

  static pw.Widget _tableRow(List<String> cells, {bool header = false, bool zebra = false}) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: header ? _navy : (zebra ? _zebraBg : null),
        border: const pw.Border(bottom: pw.BorderSide(color: _gridLine, width: 0.6)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < cells.length; i++)
            _tableCell(
              cells[i],
              _colFlex[i],
              header: header,
              align: i == 4 ? pw.TextAlign.left : (i >= 5 ? pw.TextAlign.center : pw.TextAlign.left),
            ),
        ],
      ),
    );
  }

  /// Returns the table as a flat list of top-level widgets (header row,
  /// one widget per transaction row) rather than one combined Column, so
  /// [pw.MultiPage] can break between rows at a page boundary instead of
  /// needing the whole table to fit on one page. No totals row — Total
  /// Expenses is already shown in the stat row above, matching the design
  /// reference, which doesn't repeat it in the table either.
  static List<pw.Widget> _transactionTableWidgets(ExpensesReportSnapshot snapshot) {
    final rows = [...snapshot.rows]..sort((a, b) {
        final ad = a.expense.date, bd = b.expense.date;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad); // newest first
      });

    const headers = ['Date', 'Description', 'Category', 'Paid By', 'Amount', 'Receipt', 'Status'];
    final widgets = <pw.Widget>[_tableRow(headers, header: true)];

    if (rows.isEmpty) {
      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 14),
        child: pw.Text('No expenses recorded.', style: pw.TextStyle(fontSize: 9, color: _gray)),
      ));
    } else {
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        final e = r.expense;
        final label = e.title.trim().isNotEmpty ? e.title.trim() : (e.note.trim().isNotEmpty ? e.note.trim() : e.category);
        widgets.add(_tableRow(
          [
            _fmtDate(e.date),
            label,
            e.category,
            e.paidByName.isNotEmpty ? e.paidByName : '—',
            _money(r.amount),
            e.receiptImageUrl.isNotEmpty ? 'Attached' : 'Missing',
            r.settled ? 'Settled' : 'Unsettled',
          ],
          zebra: i.isOdd,
        ));
      }
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
            pw.Text('Data source: Voya - AI-Driven Contextual Travel Management', style: pw.TextStyle(fontSize: 7.5, color: _gray)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(fontSize: 7.5, color: _gray)),
          ],
        ),
      ],
    );
  }
}
