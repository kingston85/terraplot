// TerraPlot LR — geodesy core.
//
// All measurements are computed on UTM (WGS84) grid coordinates and then
// corrected by the point scale factor so results match true ground
// distances and areas. Liberia lies entirely inside UTM Zone 29N.

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class Utm {
  final double easting;
  final double northing;
  final int zone;
  final bool north;
  const Utm(this.easting, this.northing, {this.zone = 29, this.north = true});

  String get zoneLabel => '$zone${north ? 'N' : 'S'}';
}

class Geo {
  Geo._();

  // WGS84 ellipsoid
  static const double _a = 6378137.0;
  static const double _f = 1 / 298.257223563;
  static const double _k0 = 0.9996;
  static final double _e2 = _f * (2 - _f);
  static final double _ep2 = _e2 / (1 - _e2);
  static final double _e4 = _e2 * _e2;
  static final double _e6 = _e4 * _e2;

  static const int liberiaZone = 29;

  static double _rad(double d) => d * math.pi / 180.0;
  static double _deg(double r) => r * 180.0 / math.pi;

  /// UTM zone for a longitude (Liberia → 29).
  static int zoneFor(double lon) => ((lon + 180) / 6).floor() + 1;

  /// Latitude/longitude (degrees, WGS84) → UTM.
  static Utm toUtm(double lat, double lon, {int zone = liberiaZone}) {
    final phi = _rad(lat);
    final lam = _rad(lon);
    final lam0 = _rad(zone * 6.0 - 183.0);
    final s = math.sin(phi), c = math.cos(phi), t = math.tan(phi);
    final n = _a / math.sqrt(1 - _e2 * s * s);
    final tt = t * t;
    final cc = _ep2 * c * c;
    final aa = c * (lam - lam0);
    final m = _a *
        ((1 - _e2 / 4 - 3 * _e4 / 64 - 5 * _e6 / 256) * phi -
            (3 * _e2 / 8 + 3 * _e4 / 32 + 45 * _e6 / 1024) * math.sin(2 * phi) +
            (15 * _e4 / 256 + 45 * _e6 / 1024) * math.sin(4 * phi) -
            (35 * _e6 / 3072) * math.sin(6 * phi));
    final a3 = aa * aa * aa;
    final a5 = a3 * aa * aa;
    final x = _k0 *
            n *
            (aa +
                (1 - tt + cc) * a3 / 6 +
                (5 - 18 * tt + tt * tt + 72 * cc - 58 * _ep2) * a5 / 120) +
        500000.0;
    final a2 = aa * aa;
    final a4 = a2 * a2;
    final a6 = a4 * a2;
    var y = _k0 *
        (m +
            n *
                t *
                (a2 / 2 +
                    (5 - tt + 9 * cc + 4 * cc * cc) * a4 / 24 +
                    (61 - 58 * tt + tt * tt + 600 * cc - 330 * _ep2) * a6 / 720));
    final north = lat >= 0;
    if (!north) y += 10000000.0;
    return Utm(x, y, zone: zone, north: north);
  }

  static Utm toUtmLL(LatLng p, {int zone = liberiaZone}) =>
      toUtm(p.latitude, p.longitude, zone: zone);

  /// UTM → latitude/longitude (degrees, WGS84).
  static LatLng fromUtm(double easting, double northing,
      {int zone = liberiaZone, bool north = true}) {
    var y = northing;
    if (!north) y -= 10000000.0;
    final lam0 = _rad(zone * 6.0 - 183.0);
    final m = y / _k0;
    final mu = m / (_a * (1 - _e2 / 4 - 3 * _e4 / 64 - 5 * _e6 / 256));
    final sq = math.sqrt(1 - _e2);
    final e1 = (1 - sq) / (1 + sq);
    final e1p2 = e1 * e1, e1p3 = e1p2 * e1, e1p4 = e1p3 * e1;
    final p1 = mu +
        (3 * e1 / 2 - 27 * e1p3 / 32) * math.sin(2 * mu) +
        (21 * e1p2 / 16 - 55 * e1p4 / 32) * math.sin(4 * mu) +
        (151 * e1p3 / 96) * math.sin(6 * mu) +
        (1097 * e1p4 / 512) * math.sin(8 * mu);
    final s = math.sin(p1), c = math.cos(p1), t = math.tan(p1);
    final n1 = _a / math.sqrt(1 - _e2 * s * s);
    final t1 = t * t;
    final c1 = _ep2 * c * c;
    final r1 = _a * (1 - _e2) / math.pow(1 - _e2 * s * s, 1.5);
    final d = (easting - 500000.0) / (n1 * _k0);
    final d2 = d * d, d3 = d2 * d, d4 = d2 * d2, d5 = d4 * d, d6 = d4 * d2;
    final phi = p1 -
        (n1 * t / r1) *
            (d2 / 2 -
                (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * _ep2) * d4 / 24 +
                (61 + 90 * t1 + 298 * c1 + 45 * t1 * t1 - 252 * _ep2 - 3 * c1 * c1) *
                    d6 /
                    720);
    final lam = lam0 +
        (d -
                (1 + 2 * t1 + c1) * d3 / 6 +
                (5 - 2 * c1 + 28 * t1 - 3 * c1 * c1 + 8 * _ep2 + 24 * t1 * t1) *
                    d5 /
                    120) /
            c;
    return LatLng(_deg(phi), _deg(lam));
  }

  /// Point scale factor of the UTM grid at a position (≈ 0.9996–1.0010).
  static double scaleFactor(double easting, double lat) {
    final phi = _rad(lat);
    final s = math.sin(phi);
    final w = 1 - _e2 * s * s;
    final n = _a / math.sqrt(w);
    final m = _a * (1 - _e2) / math.pow(w, 1.5);
    final r2 = m * n;
    final x = easting - 500000.0;
    return _k0 * (1 + x * x / (2 * r2));
  }

  /// Ground distance in metres between two points.
  static double distance(LatLng a, LatLng b) {
    final ua = toUtmLL(a), ub = toUtmLL(b);
    final grid = _hyp(ub.easting - ua.easting, ub.northing - ua.northing);
    final k = scaleFactor((ua.easting + ub.easting) / 2,
        (a.latitude + b.latitude) / 2);
    return grid / k;
  }

  /// Grid bearing (degrees from grid north, 0–360) from a to b.
  static double bearing(LatLng a, LatLng b) {
    final ua = toUtmLL(a), ub = toUtmLL(b);
    final th = _deg(math.atan2(ub.easting - ua.easting, ub.northing - ua.northing));
    return (th + 360) % 360;
  }

  static double _hyp(double x, double y) => math.sqrt(x * x + y * y);

  /// Ground area in m² of a closed polygon (corners in order).
  static double area(List<LatLng> pts) {
    if (pts.length < 3) return 0;
    final u = pts.map(toUtmLL).toList();
    var sum = 0.0;
    var ce = 0.0;
    var clat = 0.0;
    for (var i = 0; i < u.length; i++) {
      final p = u[i];
      final q = u[(i + 1) % u.length];
      sum += p.easting * q.northing - q.easting * p.northing;
      ce += p.easting;
      clat += pts[i].latitude;
    }
    final k = scaleFactor(ce / u.length, clat / u.length);
    return (sum.abs() / 2) / (k * k);
  }

  /// Ground perimeter in metres of a closed polygon.
  static double perimeter(List<LatLng> pts, {bool closed = true}) {
    if (pts.length < 2) return 0;
    var p = 0.0;
    final n = closed ? pts.length : pts.length - 1;
    for (var i = 0; i < n; i++) {
      p += distance(pts[i], pts[(i + 1) % pts.length]);
    }
    return p;
  }

  /// One standard deviation of the area (m²) given each corner's accuracy (m).
  static double areaUncertainty(List<LatLng> pts, List<double> sigmas) {
    if (pts.length < 3 || sigmas.length != pts.length) return 0;
    final u = pts.map(toUtmLL).toList();
    final n = u.length;
    var v = 0.0;
    for (var i = 0; i < n; i++) {
      final prev = u[(i - 1 + n) % n];
      final next = u[(i + 1) % n];
      final dx = next.easting - prev.easting;
      final dy = next.northing - prev.northing;
      v += sigmas[i] * sigmas[i] * (dx * dx + dy * dy);
    }
    return 0.5 * math.sqrt(v);
  }

  /// Accuracy-weighted average of GPS readings.
  static LatLng weightedMean(List<LatLng> pts, List<double> sigmas) {
    if (pts.isEmpty) return const LatLng(0, 0);
    var wl = 0.0, wo = 0.0, ws = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final s = (i < sigmas.length && sigmas[i] > 0) ? sigmas[i] : 10.0;
      final w = 1 / (s * s);
      wl += pts[i].latitude * w;
      wo += pts[i].longitude * w;
      ws += w;
    }
    return LatLng(wl / ws, wo / ws);
  }

  /// Combined accuracy of an averaged position (m).
  static double averagedAccuracy(List<double> sigmas) {
    if (sigmas.isEmpty) return 0;
    var ws = 0.0;
    for (final s in sigmas) {
      final v = s > 0 ? s : 10.0;
      ws += 1 / (v * v);
    }
    return math.sqrt(1 / ws);
  }

  // ---------- Formatting ----------

  static String dms(double deg, {required bool isLat}) {
    final hemi = isLat ? (deg >= 0 ? 'N' : 'S') : (deg >= 0 ? 'E' : 'W');
    var v = deg.abs();
    var d = v.floor();
    var mFull = (v - d) * 60;
    var m = mFull.floor();
    var s = (mFull - m) * 60;
    if (s >= 59.995) {
      s = 0;
      m += 1;
    }
    if (m >= 60) {
      m = 0;
      d += 1;
    }
    return '$d° ${m.toString().padLeft(2, '0')}′ ${s.toStringAsFixed(2).padLeft(5, '0')}″ $hemi';
  }

  static String decimal(double deg, {required bool isLat, int places = 6}) {
    final hemi = isLat ? (deg >= 0 ? 'N' : 'S') : (deg >= 0 ? 'E' : 'W');
    return '${deg.abs().toStringAsFixed(places)}° $hemi';
  }

  /// Parses decimal ("6.3156", "-10.8") or DMS ("6 18 56.2 N", "10°48'26.6\"W").
  static double? parseAngle(String input) {
    final txt = input.trim().toUpperCase();
    if (txt.isEmpty) return null;
    final neg = txt.contains('S') || txt.contains('W') || txt.startsWith('-');
    final nums = RegExp(r'\d+(?:\.\d+)?')
        .allMatches(txt)
        .map((m) => double.parse(m.group(0)!))
        .toList();
    if (nums.isEmpty) return null;
    var v = nums[0];
    if (nums.length > 1) v += nums[1] / 60;
    if (nums.length > 2) v += nums[2] / 3600;
    return neg ? -v : v;
  }

  static String metres(double m) {
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(2)} km';
    if (m >= 100) return '${m.toStringAsFixed(1)} m';
    return '${m.toStringAsFixed(2)} m';
  }

  static String feet(double m) => '${(m / 0.3048).toStringAsFixed(1)} ft';

  static String bearingText(double deg) {
    const names = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final i = ((deg + 22.5) % 360 / 45).floor();
    return '${deg.toStringAsFixed(1)}° ${names[i]}';
  }

  static String group(double v, {int places = 0}) {
    final s = v.toStringAsFixed(places);
    final parts = s.split('.');
    final intPart = parts[0];
    final neg = intPart.startsWith('-');
    final digits = neg ? intPart.substring(1) : intPart;
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    final out = '${neg ? '-' : ''}$buf';
    return parts.length > 1 ? '$out.${parts[1]}' : out;
  }
}

/// Area units, including the local Liberian "lot".
enum AreaUnit { sqm, hectare, acre, sqft, lot }

extension AreaUnitX on AreaUnit {
  String get label {
    switch (this) {
      case AreaUnit.sqm:
        return 'm²';
      case AreaUnit.hectare:
        return 'ha';
      case AreaUnit.acre:
        return 'acres';
      case AreaUnit.sqft:
        return 'ft²';
      case AreaUnit.lot:
        return 'lots';
    }
  }

  String get longName {
    switch (this) {
      case AreaUnit.sqm:
        return 'Square metres';
      case AreaUnit.hectare:
        return 'Hectares';
      case AreaUnit.acre:
        return 'Acres';
      case AreaUnit.sqft:
        return 'Square feet';
      case AreaUnit.lot:
        return 'Liberian lots';
    }
  }

  double convert(double sqm, {double lotSqm = 1011.71}) {
    switch (this) {
      case AreaUnit.sqm:
        return sqm;
      case AreaUnit.hectare:
        return sqm / 10000.0;
      case AreaUnit.acre:
        return sqm / 4046.8564224;
      case AreaUnit.sqft:
        return sqm / 0.09290304;
      case AreaUnit.lot:
        return sqm / lotSqm;
    }
  }

  int get places {
    switch (this) {
      case AreaUnit.sqm:
        return 1;
      case AreaUnit.hectare:
        return 4;
      case AreaUnit.acre:
        return 3;
      case AreaUnit.sqft:
        return 0;
      case AreaUnit.lot:
        return 2;
    }
  }

  String format(double sqm, {double lotSqm = 1011.71}) =>
      '${Geo.group(convert(sqm, lotSqm: lotSqm), places: places)} $label';
}
