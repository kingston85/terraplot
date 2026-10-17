import 'dart:convert';

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:terraplot/core/exporters.dart';
import 'package:terraplot/core/geo.dart';
import 'package:terraplot/data/models.dart';

Plot _plot() => Plot(
      id: 'p1',
      name: 'Lot <A> & B',
      corners: [
        const LatLng(6.2848639, -10.7121441),
        const LatLng(6.2848558, -10.7118459),
        const LatLng(6.2851542, -10.7118650),
        const LatLng(6.2851351, -10.7121541),
      ],
      cornerAccuracy: [3, 3, 3, 3],
      note: 'Fence, north side',
    );

SurveyPoint _pt() => SurveyPoint(id: 's1', name: 'Well', type: PointType.well, lat: 6.2868962, lon: -10.7128195, accuracy: 2.5);

void main() {
  final bundle = ExportBundle(title: 'Demo', plots: [_plot()], points: [_pt()]);

  test('CSV has one row per corner and point, quoted note', () {
    final lines = Exporters.csv(bundle).trim().split('\n');
    expect(lines.length, 1 + 4 + 1);
    expect(lines[1], startsWith('plot_corner,Lot <A> & B,A,6.2848639,-10.7121441'));
    expect(lines[1], contains('"Fence, north side"'));
    expect(lines.last, startsWith('point,Well,Well,6.2868962,-10.7128195'));
  });

  test('KML escapes names and closes the polygon ring', () {
    final k = Exporters.kml(bundle);
    expect(k, contains('Lot &lt;A&gt; &amp; B'));
    expect(k, contains('-10.7121441,6.2848639,0 -10.7118459,6.2848558,0'));
    final ring = RegExp(r'<coordinates>([^<]+)</coordinates>').firstMatch(k)!.group(1)!.split(' ');
    expect(ring.first, ring.last);
    expect(ring.length, 5);
  });

  test('GeoJSON is valid with a polygon and a point', () {
    final j = jsonDecode(Exporters.geojson(bundle)) as Map<String, dynamic>;
    final f = j['features'] as List;
    expect(f.length, 2);
    expect(f[0]['geometry']['type'], 'Polygon');
    expect((f[0]['properties']['area_m2'] as num).toDouble(), closeTo(1024.41, 0.05));
    expect(f[1]['geometry']['coordinates'], [-10.7128195, 6.2868962]);
  });

  test('GPX has waypoints and a closed track', () {
    final g = Exporters.gpx(bundle);
    expect('<wpt '.allMatches(g).length, 5);
    expect('<trkpt '.allMatches(g).length, 5);
  });

  test('safe file names', () {
    expect(Exporters.safeFileName('Lot <A> & B'), 'Lot_A_B');
    expect(Exporters.safeFileName('***'), 'terraplot');
  });

  group('Coordinate parser', () {
    test('UTM lines with labels and tabs', () {
      final pts = [
        for (final p in _plot().corners) Geo.toUtmLL(p),
      ];
      final text = [
        for (var i = 0; i < pts.length; i++) 'P${i + 1}\t${pts[i].easting.toStringAsFixed(3)}  ${pts[i].northing.toStringAsFixed(3)}',
      ].join('\n');
      final r = CoordinateParser.parse(text, utm: true);
      expect(r.errors, isEmpty);
      expect(r.points.length, 4);
      expect(Geo.area(r.points), closeTo(1024.41, 0.05));
    });

    test('lat/long with commas, blank lines and a bad line', () {
      const text = '6.2848639, -10.7121441\n\n6.2848558,-10.7118459\nhello\n6.2851542 -10.7118650\n';
      final r = CoordinateParser.parse(text, utm: false);
      expect(r.points.length, 3);
      expect(r.errors.length, 1);
      expect(r.points[1].longitude, closeTo(-10.7118459, 1e-9));
    });

    test('rejects out-of-range values', () {
      final r = CoordinateParser.parse('12 34', utm: true);
      expect(r.points, isEmpty);
      expect(r.errors.length, 1);
    });
  });

  test('project JSON round trip keeps everything', () {
    final pr = Project(id: 'x', name: 'Caldwell', color: const Color(0xFF2BD38A), plots: [_plot()], points: [_pt()]);
    final back = Project.fromJson(jsonDecode(jsonEncode(pr.toJson())) as Map<String, dynamic>);
    expect(back.name, 'Caldwell');
    expect(back.plots.single.corners.length, 4);
    expect(back.plots.single.area, closeTo(_plot().area, 1e-6));
    expect(back.plots.single.cornerAccuracy, [3, 3, 3, 3]);
    expect(back.points.single.type, PointType.well);
    expect(back.color.value, 0xFF2BD38A);
  });
}
