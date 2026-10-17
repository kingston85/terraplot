import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/models.dart';
import 'exporters.dart';
import 'geo.dart';

/// Builds an A4 site report: one page per plot (sketch, figures, corner
/// table), then a table of points.
class PdfReport {
  PdfReport._();

  static const _amber = PdfColor.fromInt(0xFFFFB020);
  static const _amberDeep = PdfColor.fromInt(0xFFB26A00);
  static const _ink = PdfColor.fromInt(0xFF0E1116);
  static const _dim = PdfColor.fromInt(0xFF5A6478);
  static const _line = PdfColor.fromInt(0xFFD5DAE2);
  static const _panel = PdfColor.fromInt(0xFFF4F6F9);

  static Future<Uint8List> build(
    ExportBundle b, {
    required String surveyor,
    required double lotSqm,
  }) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    final mono = pw.Font.ttf(await rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf'));
    final monoBold = pw.Font.ttf(await rootBundle.load('assets/fonts/JetBrainsMono-Bold.ttf'));

    final doc = pw.Document(
      title: b.title,
      author: surveyor.isEmpty ? 'TerraPlot LR' : surveyor,
      creator: 'TerraPlot LR',
    );
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    final now = DateTime.now();

    pw.Widget header() => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _amber, width: 2)),
          ),
          child: pw.Row(
            children: [
              pw.Text('TERRAPLOT', style: pw.TextStyle(font: bold, fontSize: 11, letterSpacing: 1.5, color: _ink)),
              pw.Text(' LR', style: pw.TextStyle(font: bold, fontSize: 11, letterSpacing: 1.5, color: _amberDeep)),
              pw.SizedBox(width: 10),
              pw.Text('Land measurement report', style: pw.TextStyle(fontSize: 9, color: _dim)),
              pw.Spacer(),
              pw.Text('Generated ${shortDate(now)} ${timeOfDay(now)}', style: pw.TextStyle(fontSize: 9, color: _dim)),
            ],
          ),
        );

    pw.Widget footer(pw.Context ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _line))),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Coordinates: WGS84, UTM Zone 29N (EPSG:32629). Bearings from grid north. Lengths and areas are '
                  'ground values. Phone GPS accuracy is typically 3-5 m; this report is for planning and records, '
                  'not a legal boundary survey.',
                  style: pw.TextStyle(fontSize: 7, color: _dim),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: pw.TextStyle(fontSize: 7, color: _dim)),
            ],
          ),
        );

    for (final plot in b.plots) {
      if (plot.corners.length < 3) continue;
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 28),
        theme: theme,
        header: (_) => header(),
        footer: footer,
        build: (ctx) => [
          pw.SizedBox(height: 14),
          pw.Text(plot.name, style: pw.TextStyle(font: bold, fontSize: 22, color: _ink)),
          pw.SizedBox(height: 2),
          pw.Text(
            '${b.plots.length > 1 || b.points.isNotEmpty ? '${b.title} · ' : ''}Measured ${shortDate(plot.created)} '
            '${timeOfDay(plot.created)} · ${plot.method.label} · ${plot.corners.length} corners',
            style: pw.TextStyle(fontSize: 9.5, color: _dim),
          ),
          pw.SizedBox(height: 14),
          _figures(plot, lotSqm, mono, monoBold),
          pw.SizedBox(height: 14),
          _sketch(plot, regular, bold, mono),
          pw.SizedBox(height: 14),
          _cornerTable(plot, mono, bold),
          if (plot.note.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('NOTES', style: pw.TextStyle(font: bold, fontSize: 8, letterSpacing: 1.2, color: _dim)),
            pw.SizedBox(height: 4),
            pw.Text(plot.note, style: const pw.TextStyle(fontSize: 10, color: _ink)),
          ],
          pw.SizedBox(height: 22),
          _signature(surveyor, bold),
        ],
      ));
    }

    if (b.points.isNotEmpty) {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 28),
        theme: theme,
        header: (_) => header(),
        footer: footer,
        build: (ctx) => [
          pw.SizedBox(height: 14),
          pw.Text('Points · ${b.title}', style: pw.TextStyle(font: bold, fontSize: 20, color: _ink)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Name', 'Type', 'Latitude', 'Longitude', 'Easting', 'Northing', '±m', 'Readings'],
            data: [
              for (final pt in b.points)
                [
                  pt.name,
                  pt.type.label,
                  pt.lat.toStringAsFixed(7),
                  pt.lon.toStringAsFixed(7),
                  pt.utm.easting.toStringAsFixed(2),
                  pt.utm.northing.toStringAsFixed(2),
                  pt.accuracy.toStringAsFixed(1),
                  '${pt.readings}',
                ],
            ],
            headerStyle: pw.TextStyle(font: bold, fontSize: 8, color: _ink),
            cellStyle: pw.TextStyle(font: mono, fontSize: 7.5, color: _ink),
            headerDecoration: const pw.BoxDecoration(color: _panel),
            border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
          pw.SizedBox(height: 22),
          _signature(surveyor, bold),
        ],
      ));
    }

    if (b.plots.every((p) => p.corners.length < 3) && b.points.isEmpty) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        build: (_) => pw.Center(child: pw.Text('Nothing to report yet.')),
      ));
    }
    return doc.save();
  }

  static pw.Widget _figures(Plot plot, double lotSqm, pw.Font mono, pw.Font monoBold) {
    final area = plot.area;
    final sigma = plot.areaSigma;
    pw.Widget box(String label, String value, {bool big = false}) => pw.Expanded(
          flex: big ? 2 : 1,
          child: pw.Container(
            margin: const pw.EdgeInsets.only(right: 6),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: big ? const PdfColor.fromInt(0x1FFFB020) : _panel,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: big ? pw.Border.all(color: _amber, width: 1) : null,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label.toUpperCase(), style: const pw.TextStyle(fontSize: 6.5, letterSpacing: 1, color: _dim)),
                pw.SizedBox(height: 3),
                pw.Text(value, style: pw.TextStyle(font: big ? monoBold : mono, fontSize: big ? 15 : 10, color: _ink)),
              ],
            ),
          ),
        );
    return pw.Column(children: [
      pw.Row(children: [
        box('Area', '${Geo.group(area, places: 1)} m²', big: true),
        box('Hectares', AreaUnit.hectare.convert(area).toStringAsFixed(4)),
        box('Acres', AreaUnit.acre.convert(area).toStringAsFixed(3)),
        box('Lots', AreaUnit.lot.convert(area, lotSqm: lotSqm).toStringAsFixed(2)),
      ]),
      pw.SizedBox(height: 6),
      pw.Row(children: [
        box('Perimeter', '${plot.perimeter.toStringAsFixed(2)} m  (${(plot.perimeter / 0.3048).toStringAsFixed(1)} ft)'),
        box('Square feet', Geo.group(AreaUnit.sqft.convert(area))),
        box(
          'Likely range (95%)',
          sigma > 0
              ? '${Geo.group(math.max(0, area - 2 * sigma))} – ${Geo.group(area + 2 * sigma)} m²'
              : 'from map / typed',
        ),
      ]),
      pw.SizedBox(height: 4),
      pw.Align(
        alignment: pw.Alignment.centerLeft,
        child: pw.Text('1 lot = ${lotSqm.toStringAsFixed(1)} m²',
            style: const pw.TextStyle(fontSize: 7, color: _dim)),
      ),
    ]);
  }

  static pw.Widget _sketch(Plot plot, pw.Font regular, pw.Font bold, pw.Font mono) {
    const w = 523.0;
    const h = 290.0;
    const pad = 46.0;
    final u = plot.corners.map(Geo.toUtmLL).toList();
    final minE = u.map((p) => p.easting).reduce(math.min);
    final maxE = u.map((p) => p.easting).reduce(math.max);
    final minN = u.map((p) => p.northing).reduce(math.min);
    final maxN = u.map((p) => p.northing).reduce(math.max);
    final spanE = math.max(maxE - minE, 0.01);
    final spanN = math.max(maxN - minN, 0.01);
    final s = math.min((w - 2 * pad) / spanE, (h - 2 * pad) / spanN);
    final offX = (w - spanE * s) / 2;
    final offY = (h - spanN * s) / 2;
    // Points measured from the bottom-left (PDF canvas space).
    final pts = [for (final p in u) PdfPoint(offX + (p.easting - minE) * s, offY + (p.northing - minN) * s)];

    // Scale bar: a round length near a quarter of the width.
    final target = (w / 4) / s;
    final mag = math.pow(10, (math.log(target) / math.ln10).floor()).toDouble();
    final step = [1.0, 2.0, 5.0, 10.0].map((m) => m * mag).lastWhere((v) => v <= target, orElse: () => mag);
    final barLen = step * s;

    final labels = <pw.Widget>[];
    final n = pts.length;
    final cx = pts.map((p) => p.x).reduce((a, b) => a + b) / n;
    final cy = pts.map((p) => p.y).reduce((a, b) => a + b) / n;
    for (var i = 0; i < n; i++) {
      final p = pts[i];
      final q = pts[(i + 1) % n];
      // Corner label pushed outward from the centre.
      final dx = p.x - cx, dy = p.y - cy;
      final d = math.max(math.sqrt(dx * dx + dy * dy), 1);
      final lx = p.x + dx / d * 14;
      final ly = p.y + dy / d * 14;
      labels.add(pw.Positioned(
        left: lx - 6,
        top: h - ly - 7,
        child: pw.Text(cornerLabel(i), style: pw.TextStyle(font: bold, fontSize: 10, color: _ink)),
      ));
      // Side length at the midpoint, nudged outward.
      final mx = (p.x + q.x) / 2, my = (p.y + q.y) / 2;
      final ox = mx - cx, oy = my - cy;
      final od = math.max(math.sqrt(ox * ox + oy * oy), 1);
      labels.add(pw.Positioned(
        left: mx + ox / od * 10 - 22,
        top: h - (my + oy / od * 10) - 5,
        child: pw.Container(
          width: 44,
          alignment: pw.Alignment.center,
          child: pw.Text(
            '${Geo.distance(plot.corners[i], plot.corners[(i + 1) % n]).toStringAsFixed(2)} m',
            style: pw.TextStyle(font: mono, fontSize: 7, color: _amberDeep),
          ),
        ),
      ));
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Stack(
        children: [
          pw.CustomPaint(
            size: const PdfPoint(w, h),
            painter: (canvas, size) {
              // Light grid every scale step.
              canvas
                ..setStrokeColor(const PdfColor.fromInt(0xFFEEF1F5))
                ..setLineWidth(0.5);
              for (var x = 0.0; x <= w; x += barLen / 2) {
                canvas
                  ..moveTo(x, 0)
                  ..lineTo(x, h);
              }
              for (var y = 0.0; y <= h; y += barLen / 2) {
                canvas
                  ..moveTo(0, y)
                  ..lineTo(w, y);
              }
              canvas.strokePath();

              // Plot fill and outline.
              canvas.moveTo(pts.first.x, pts.first.y);
              for (final p in pts.skip(1)) {
                canvas.lineTo(p.x, p.y);
              }
              canvas
                ..closePath()
                ..setFillColor(const PdfColor.fromInt(0x33FFB020))
                ..fillPath();
              canvas.moveTo(pts.first.x, pts.first.y);
              for (final p in pts.skip(1)) {
                canvas.lineTo(p.x, p.y);
              }
              canvas
                ..closePath()
                ..setStrokeColor(_amberDeep)
                ..setLineWidth(1.6)
                ..strokePath();

              // Corner dots.
              canvas.setFillColor(_ink);
              for (final p in pts) {
                canvas
                  ..drawEllipse(p.x, p.y, 3, 3)
                  ..fillPath();
              }

              // North arrow (top right).
              const ax = w - 24.0, ay = h - 40.0;
              canvas
                ..setFillColor(_ink)
                ..moveTo(ax, ay + 18)
                ..lineTo(ax - 6, ay)
                ..lineTo(ax, ay + 5)
                ..lineTo(ax + 6, ay)
                ..closePath()
                ..fillPath();

              // Scale bar (bottom left).
              canvas
                ..setStrokeColor(_ink)
                ..setLineWidth(1.2)
                ..moveTo(16, 16)
                ..lineTo(16 + barLen, 16)
                ..moveTo(16, 12)
                ..lineTo(16, 20)
                ..moveTo(16 + barLen, 12)
                ..lineTo(16 + barLen, 20)
                ..strokePath();
            },
          ),
          ...labels,
          pw.Positioned(
            right: 20,
            top: 8,
            child: pw.Text('N', style: pw.TextStyle(font: bold, fontSize: 9, color: _ink)),
          ),
          pw.Positioned(
            left: 16,
            top: h - 34,
            child: pw.Text('${step >= 1 ? step.toStringAsFixed(0) : step.toStringAsFixed(1)} m',
                style: pw.TextStyle(font: mono, fontSize: 7, color: _ink)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _cornerTable(Plot plot, pw.Font mono, pw.Font bold) {
    final n = plot.corners.length;
    return pw.TableHelper.fromTextArray(
      headers: ['Pt', 'Latitude', 'Longitude', 'Easting', 'Northing', 'Side', 'Length m', 'Bearing', '±m'],
      data: [
        for (var i = 0; i < n; i++)
          () {
            final c = plot.corners[i];
            final nx = plot.corners[(i + 1) % n];
            final u = Geo.toUtmLL(c);
            final acc = i < plot.cornerAccuracy.length ? plot.cornerAccuracy[i] : 0.0;
            return [
              cornerLabel(i),
              c.latitude.toStringAsFixed(7),
              c.longitude.toStringAsFixed(7),
              u.easting.toStringAsFixed(2),
              u.northing.toStringAsFixed(2),
              '${cornerLabel(i)}-${cornerLabel((i + 1) % n)}',
              Geo.distance(c, nx).toStringAsFixed(2),
              '${Geo.bearing(c, nx).toStringAsFixed(1)}°',
              acc > 0 ? acc.toStringAsFixed(1) : '-',
            ];
          }(),
      ],
      headerStyle: pw.TextStyle(font: bold, fontSize: 7.5, color: _ink),
      cellStyle: pw.TextStyle(font: mono, fontSize: 7.5, color: _ink),
      headerDecoration: const pw.BoxDecoration(color: _panel),
      border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      cellAlignment: pw.Alignment.centerRight,
      cellAlignments: {0: pw.Alignment.centerLeft, 5: pw.Alignment.centerLeft},
    );
  }

  static pw.Widget _signature(String surveyor, pw.Font bold) {
    pw.Widget line(String label, String value) => pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                height: 18,
                alignment: pw.Alignment.bottomLeft,
                child: pw.Text(value, style: const pw.TextStyle(fontSize: 10, color: _ink)),
              ),
              pw.Container(height: 0.8, color: _ink),
              pw.SizedBox(height: 3),
              pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: _dim)),
            ],
          ),
        );
    return pw.Row(children: [
      line('Measured by', surveyor),
      pw.SizedBox(width: 24),
      line('Signature', ''),
      pw.SizedBox(width: 24),
      line('Date', ''),
    ]);
  }
}
