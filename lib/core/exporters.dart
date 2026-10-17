// Text exporters for plots and points. Pure Dart so they are unit-tested.

import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../data/models.dart';
import 'geo.dart';

enum ExportFormat { kml, gpx, csv, geojson, pdf }

extension ExportFormatX on ExportFormat {
  String get label {
    switch (this) {
      case ExportFormat.kml:
        return 'KML';
      case ExportFormat.gpx:
        return 'GPX';
      case ExportFormat.csv:
        return 'CSV';
      case ExportFormat.geojson:
        return 'GeoJSON';
      case ExportFormat.pdf:
        return 'PDF report';
    }
  }

  String get fileExt {
    switch (this) {
      case ExportFormat.kml:
        return 'kml';
      case ExportFormat.gpx:
        return 'gpx';
      case ExportFormat.csv:
        return 'csv';
      case ExportFormat.geojson:
        return 'geojson';
      case ExportFormat.pdf:
        return 'pdf';
    }
  }

  String get mime {
    switch (this) {
      case ExportFormat.kml:
        return 'application/vnd.google-earth.kml+xml';
      case ExportFormat.gpx:
        return 'application/gpx+xml';
      case ExportFormat.csv:
        return 'text/csv';
      case ExportFormat.geojson:
        return 'application/geo+json';
      case ExportFormat.pdf:
        return 'application/pdf';
    }
  }

  String get description {
    switch (this) {
      case ExportFormat.kml:
        return 'Opens in Google Earth and Google My Maps';
      case ExportFormat.gpx:
        return 'For GPS devices and other GPS apps';
      case ExportFormat.csv:
        return 'Spreadsheet with coordinates, for Excel';
      case ExportFormat.geojson:
        return 'For QGIS and other GIS software';
      case ExportFormat.pdf:
        return 'Site report with sketch, table and area';
    }
  }
}

/// Content to export: any mix of plots and points.
class ExportBundle {
  final String title;
  final List<Plot> plots;
  final List<SurveyPoint> points;
  const ExportBundle({required this.title, this.plots = const [], this.points = const []});

  factory ExportBundle.plot(Plot p) => ExportBundle(title: p.name, plots: [p]);
  factory ExportBundle.project(Project p) =>
      ExportBundle(title: p.name, plots: p.plots, points: p.points);
}

class Exporters {
  Exporters._();

  static String safeFileName(String s) {
    final cleaned = s.trim().replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '').replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'terraplot' : cleaned;
  }

  static String _xml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static String _csvCell(String s) =>
      (s.contains(',') || s.contains('"') || s.contains('\n')) ? '"${s.replaceAll('"', '""')}"' : s;

  static String _f(double v, int places) => v.toStringAsFixed(places);

  // ---------------- CSV ----------------

  static String csv(ExportBundle b, {double lotSqm = 1011.71}) {
    final out = StringBuffer();
    out.writeln('feature,name,label,latitude,longitude,easting_29N,northing_29N,accuracy_m,'
        'side_to_next_m,bearing_deg,area_m2,area_acres,area_lots,perimeter_m,note');
    for (final p in b.plots) {
      final n = p.corners.length;
      for (var i = 0; i < n; i++) {
        final c = p.corners[i];
        final next = p.corners[(i + 1) % n];
        final u = Geo.toUtmLL(c);
        final acc = i < p.cornerAccuracy.length ? p.cornerAccuracy[i] : 0.0;
        final first = i == 0;
        out.writeln([
          'plot_corner',
          _csvCell(p.name),
          cornerLabel(i),
          _f(c.latitude, 7),
          _f(c.longitude, 7),
          _f(u.easting, 2),
          _f(u.northing, 2),
          acc > 0 ? _f(acc, 1) : '',
          n > 1 ? _f(Geo.distance(c, next), 2) : '',
          n > 1 ? _f(Geo.bearing(c, next), 1) : '',
          first ? _f(p.area, 2) : '',
          first ? _f(AreaUnit.acre.convert(p.area), 4) : '',
          first ? _f(AreaUnit.lot.convert(p.area, lotSqm: lotSqm), 3) : '',
          first ? _f(p.perimeter, 2) : '',
          first ? _csvCell(p.note) : '',
        ].join(','));
      }
    }
    for (final pt in b.points) {
      final u = pt.utm;
      out.writeln([
        'point',
        _csvCell(pt.name),
        pt.type.label,
        _f(pt.lat, 7),
        _f(pt.lon, 7),
        _f(u.easting, 2),
        _f(u.northing, 2),
        pt.accuracy > 0 ? _f(pt.accuracy, 2) : '',
        '',
        '',
        '',
        '',
        '',
        '',
        _csvCell(pt.note),
      ].join(','));
    }
    return out.toString();
  }

  // ---------------- KML ----------------

  static String kml(ExportBundle b, {double lotSqm = 1011.71}) {
    String coord(LatLng c) => '${_f(c.longitude, 7)},${_f(c.latitude, 7)},0';
    final out = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<kml xmlns="http://www.opengis.net/kml/2.2">')
      ..writeln('<Document>')
      ..writeln('<name>${_xml(b.title)}</name>')
      ..writeln('<Style id="plot"><LineStyle><color>ff20b0ff</color><width>3</width></LineStyle>'
          '<PolyStyle><color>4020b0ff</color></PolyStyle></Style>')
      ..writeln('<Style id="pt"><IconStyle><scale>1.1</scale></IconStyle></Style>');
    for (final p in b.plots) {
      if (p.corners.length < 3) continue;
      final ring = [...p.corners, p.corners.first].map(coord).join(' ');
      out
        ..writeln('<Placemark>')
        ..writeln('<name>${_xml(p.name)}</name>')
        ..writeln('<description>${_xml('Area ${_f(p.area, 1)} m² (${_f(AreaUnit.acre.convert(p.area), 3)} acres, '
            '${_f(AreaUnit.lot.convert(p.area, lotSqm: lotSqm), 2)} lots). Perimeter ${_f(p.perimeter, 1)} m.'
            '${p.note.isEmpty ? '' : ' ${p.note}'}')}</description>')
        ..writeln('<styleUrl>#plot</styleUrl>')
        ..writeln('<Polygon><outerBoundaryIs><LinearRing><coordinates>$ring</coordinates>'
            '</LinearRing></outerBoundaryIs></Polygon>')
        ..writeln('</Placemark>');
      for (var i = 0; i < p.corners.length; i++) {
        out.writeln('<Placemark><name>${_xml('${p.name} ${cornerLabel(i)}')}</name>'
            '<styleUrl>#pt</styleUrl><Point><coordinates>${coord(p.corners[i])}</coordinates></Point></Placemark>');
      }
    }
    for (final pt in b.points) {
      out.writeln('<Placemark><name>${_xml(pt.name)}</name>'
          '<description>${_xml('${pt.type.label}. Accuracy ±${_f(pt.accuracy, 1)} m. ${pt.note}'.trim())}</description>'
          '<styleUrl>#pt</styleUrl><Point><coordinates>${coord(pt.latLng)}</coordinates></Point></Placemark>');
    }
    out
      ..writeln('</Document>')
      ..writeln('</kml>');
    return out.toString();
  }

  // ---------------- GPX ----------------

  static String gpx(ExportBundle b) {
    String ll(LatLng c) => 'lat="${_f(c.latitude, 7)}" lon="${_f(c.longitude, 7)}"';
    final out = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<gpx version="1.1" creator="TerraPlot LR" xmlns="http://www.topografix.com/GPX/1/1">')
      ..writeln('<metadata><name>${_xml(b.title)}</name></metadata>');
    for (final pt in b.points) {
      out.writeln('<wpt ${ll(pt.latLng)}><ele>${_f(pt.altitude, 1)}</ele>'
          '<time>${pt.time.toUtc().toIso8601String()}</time><name>${_xml(pt.name)}</name>'
          '<desc>${_xml(pt.note)}</desc><type>${_xml(pt.type.label)}</type></wpt>');
    }
    for (final p in b.plots) {
      for (var i = 0; i < p.corners.length; i++) {
        out.writeln('<wpt ${ll(p.corners[i])}><name>${_xml('${p.name} ${cornerLabel(i)}')}</name>'
            '<type>Corner</type></wpt>');
      }
      if (p.corners.length >= 2) {
        out.writeln('<trk><name>${_xml(p.name)}</name><trkseg>');
        for (final c in [...p.corners, p.corners.first]) {
          out.writeln('<trkpt ${ll(c)}></trkpt>');
        }
        out.writeln('</trkseg></trk>');
      }
    }
    out.writeln('</gpx>');
    return out.toString();
  }

  // ---------------- GeoJSON ----------------

  static String geojson(ExportBundle b, {double lotSqm = 1011.71}) {
    List<double> pos(LatLng c) => [
          double.parse(_f(c.longitude, 7)),
          double.parse(_f(c.latitude, 7)),
        ];
    final features = <Map<String, dynamic>>[
      for (final p in b.plots)
        if (p.corners.length >= 3)
          {
            'type': 'Feature',
            'properties': {
              'name': p.name,
              'kind': 'plot',
              'area_m2': double.parse(_f(p.area, 2)),
              'area_acres': double.parse(_f(AreaUnit.acre.convert(p.area), 4)),
              'area_lots': double.parse(_f(AreaUnit.lot.convert(p.area, lotSqm: lotSqm), 3)),
              'perimeter_m': double.parse(_f(p.perimeter, 2)),
              'corners': p.corners.length,
              'created': p.created.toIso8601String(),
              'note': p.note,
            },
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [for (final c in [...p.corners, p.corners.first]) pos(c)],
              ],
            },
          },
      for (final pt in b.points)
        {
          'type': 'Feature',
          'properties': {
            'name': pt.name,
            'kind': 'point',
            'type': pt.type.label,
            'accuracy_m': double.parse(_f(pt.accuracy, 2)),
            'altitude_m': double.parse(_f(pt.altitude, 1)),
            'readings': pt.readings,
            'time': pt.time.toIso8601String(),
            'note': pt.note,
          },
          'geometry': {'type': 'Point', 'coordinates': pos(pt.latLng)},
        },
    ];
    return const JsonEncoder.withIndent('  ').convert({
      'type': 'FeatureCollection',
      'name': b.title,
      'features': features,
    });
  }

  static String text(ExportFormat f, ExportBundle b, {double lotSqm = 1011.71}) {
    switch (f) {
      case ExportFormat.kml:
        return kml(b, lotSqm: lotSqm);
      case ExportFormat.gpx:
        return gpx(b);
      case ExportFormat.csv:
        return csv(b, lotSqm: lotSqm);
      case ExportFormat.geojson:
        return geojson(b, lotSqm: lotSqm);
      case ExportFormat.pdf:
        throw ArgumentError('PDF is built by PdfReport');
    }
  }
}

/// Parses pasted corner coordinates, one corner per line.
///
/// Accepts labels and separators freely ("P1  312345.6  694321.2",
/// "6.2848, -10.7121", "A\t312345\t694321"). The last two numbers on each
/// line are used. Lines with fewer than two numbers are skipped.
class CoordinateParser {
  CoordinateParser._();

  static final _num = RegExp(r'-?\d+(?:\.\d+)?');

  static ParseResult parse(String text, {required bool utm}) {
    final pts = <LatLng>[];
    final errors = <String>[];
    final lines = text.split(RegExp(r'\r?\n'));
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final nums = _num.allMatches(line).map((m) => double.parse(m.group(0)!)).toList();
      if (nums.length < 2) {
        errors.add('Line ${i + 1}: needs two numbers');
        continue;
      }
      final a = nums[nums.length - 2];
      final b = nums[nums.length - 1];
      if (utm) {
        if (a < 100000 || a > 900000 || b < 0 || b > 10000000) {
          errors.add('Line ${i + 1}: easting/northing out of range');
          continue;
        }
        pts.add(Geo.fromUtm(a, b));
      } else {
        if (a.abs() > 90 || b.abs() > 180) {
          errors.add('Line ${i + 1}: latitude/longitude out of range');
          continue;
        }
        pts.add(LatLng(a, b));
      }
    }
    return ParseResult(pts, errors);
  }
}

class ParseResult {
  final List<LatLng> points;
  final List<String> errors;
  const ParseResult(this.points, this.errors);
}
