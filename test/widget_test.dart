// Geodesy tests. Expected values were computed independently with pyproj
// (EPSG:32629) and the WGS84 geodesic (Karney) for the same coordinates.

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:terraplot/core/geo.dart';

void main() {
  group('UTM Zone 29N', () {
    test('Monrovia forward matches pyproj', () {
      final u = Geo.toUtm(6.3156, -10.8074);
      expect(u.easting, closeTo(300061.536, 0.002));
      expect(u.northing, closeTo(698438.873, 0.002));
      expect(u.zoneLabel, '29N');
    });

    test('central meridian gives easting 500000', () {
      final u = Geo.toUtm(7.5, -9.0);
      expect(u.easting, closeTo(500000.000, 0.001));
      expect(u.northing, closeTo(829022.732, 0.002));
    });

    test('Harper and far west corners', () {
      final a = Geo.toUtm(4.35, -7.6);
      expect(a.easting, closeTo(655354.558, 0.002));
      expect(a.northing, closeTo(480958.951, 0.002));
      final b = Geo.toUtm(8.55, -11.5);
      expect(b.easting, closeTo(224799.836, 0.002));
      expect(b.northing, closeTo(945995.073, 0.002));
    });

    test('round trip returns the same point', () {
      for (final p in const [LatLng(6.3156, -10.8074), LatLng(4.35, -7.6), LatLng(8.55, -11.5)]) {
        final u = Geo.toUtmLL(p);
        final back = Geo.fromUtm(u.easting, u.northing);
        expect(back.latitude, closeTo(p.latitude, 1e-8));
        expect(back.longitude, closeTo(p.longitude, 1e-8));
      }
    });
  });

  group('Plot measurement', () {
    const plot = [
      LatLng(6.2848639, -10.7121441),
      LatLng(6.2848558, -10.7118459),
      LatLng(6.2851542, -10.7118650),
      LatLng(6.2851351, -10.7121541),
    ];

    test('area matches the WGS84 geodesic area', () {
      // Geodesic: 1024.410 m²
      expect(Geo.area(plot), closeTo(1024.41, 0.05));
    });

    test('perimeter matches the geodesic perimeter', () {
      // Geodesic: 128.149 m
      expect(Geo.perimeter(plot), closeTo(128.149, 0.01));
    });

    test('bearing of first side is about 91.7 degrees', () {
      expect(Geo.bearing(plot[0], plot[1]), closeTo(91.74, 0.05));
    });

    test('fewer than 3 corners has no area', () {
      expect(Geo.area(plot.sublist(0, 2)), 0);
    });

    test('area uncertainty grows with corner accuracy', () {
      final s3 = Geo.areaUncertainty(plot, [3, 3, 3, 3]);
      final s6 = Geo.areaUncertainty(plot, [6, 6, 6, 6]);
      expect(s3, greaterThan(0));
      expect(s6, closeTo(2 * s3, 1e-9));
    });
  });

  group('Units and formatting', () {
    test('acre and lot conversions', () {
      expect(AreaUnit.acre.convert(4046.8564224), closeTo(1.0, 1e-9));
      expect(AreaUnit.lot.convert(4046.8564224, lotSqm: 4046.8564224 / 4), closeTo(4.0, 1e-9));
      expect(AreaUnit.hectare.convert(25000), closeTo(2.5, 1e-12));
    });

    test('DMS formatting', () {
      expect(Geo.dms(6.3156, isLat: true), '6° 18′ 56.16″ N');
      expect(Geo.dms(-10.8074, isLat: false), '10° 48′ 26.64″ W');
    });

    test('angle parsing accepts decimal and DMS', () {
      expect(Geo.parseAngle('6.3156'), closeTo(6.3156, 1e-12));
      expect(Geo.parseAngle('-10.8074'), closeTo(-10.8074, 1e-12));
      expect(Geo.parseAngle('10 48 26.64 W'), closeTo(-10.8074, 1e-9));
      expect(Geo.parseAngle('6°18\'56.16"N'), closeTo(6.3156, 1e-9));
    });

    test('number grouping', () {
      expect(Geo.group(1234567.891, places: 2), '1,234,567.89');
      expect(Geo.group(999), '999');
    });
  });
}
