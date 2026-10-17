import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/geo.dart';

enum PointType { corner, pillar, well, sampling, building, other }

extension PointTypeX on PointType {
  String get label {
    switch (this) {
      case PointType.corner:
        return 'Corner';
      case PointType.pillar:
        return 'Pillar';
      case PointType.well:
        return 'Well';
      case PointType.sampling:
        return 'Sampling site';
      case PointType.building:
        return 'Building';
      case PointType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case PointType.corner:
        return Icons.change_history_rounded;
      case PointType.pillar:
        return Icons.push_pin_rounded;
      case PointType.well:
        return Icons.water_drop_rounded;
      case PointType.sampling:
        return Icons.science_rounded;
      case PointType.building:
        return Icons.home_work_rounded;
      case PointType.other:
        return Icons.place_rounded;
    }
  }
}

enum MeasureMode { walk, auto, map }

extension MeasureModeX on MeasureMode {
  String get label {
    switch (this) {
      case MeasureMode.walk:
        return 'Walk & tap';
      case MeasureMode.auto:
        return 'Auto walk';
      case MeasureMode.map:
        return 'Tap map';
    }
  }

  IconData get icon {
    switch (this) {
      case MeasureMode.walk:
        return Icons.directions_walk_rounded;
      case MeasureMode.auto:
        return Icons.route_rounded;
      case MeasureMode.map:
        return Icons.touch_app_rounded;
    }
  }
}

class SurveyPoint {
  final String id;
  String name;
  PointType type;
  double lat;
  double lon;
  double accuracy;
  double altitude;
  int readings;
  DateTime time;
  String note;

  SurveyPoint({
    required this.id,
    required this.name,
    required this.type,
    required this.lat,
    required this.lon,
    this.accuracy = 0,
    this.altitude = 0,
    this.readings = 1,
    DateTime? time,
    this.note = '',
  }) : time = time ?? DateTime.now();

  LatLng get latLng => LatLng(lat, lon);
  Utm get utm => Geo.toUtm(lat, lon);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'lat': lat,
        'lon': lon,
        'accuracy': accuracy,
        'altitude': altitude,
        'readings': readings,
        'time': time.toIso8601String(),
        'note': note,
      };

  factory SurveyPoint.fromJson(Map<String, dynamic> j) => SurveyPoint(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Point',
        type: PointType.values.firstWhere((t) => t.name == j['type'], orElse: () => PointType.other),
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        accuracy: (j['accuracy'] as num?)?.toDouble() ?? 0,
        altitude: (j['altitude'] as num?)?.toDouble() ?? 0,
        readings: (j['readings'] as num?)?.toInt() ?? 1,
        time: DateTime.tryParse(j['time'] as String? ?? ''),
        note: j['note'] as String? ?? '',
      );
}

class Plot {
  final String id;
  String name;
  List<LatLng> corners;
  List<double> cornerAccuracy;
  MeasureMode method;
  DateTime created;
  String note;

  Plot({
    required this.id,
    required this.name,
    required this.corners,
    List<double>? cornerAccuracy,
    this.method = MeasureMode.walk,
    DateTime? created,
    this.note = '',
  })  : cornerAccuracy = cornerAccuracy ?? List<double>.filled(corners.length, 0),
        created = created ?? DateTime.now();

  double get area => Geo.area(corners);
  double get perimeter => Geo.perimeter(corners);
  double get areaSigma => Geo.areaUncertainty(corners, cornerAccuracy);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'corners': [for (final c in corners) [c.latitude, c.longitude]],
        'accuracy': cornerAccuracy,
        'method': method.name,
        'created': created.toIso8601String(),
        'note': note,
      };

  factory Plot.fromJson(Map<String, dynamic> j) {
    final corners = [for (final c in (j['corners'] as List)) _latLngFrom(c as List)];
    final acc = [for (final a in (j['accuracy'] as List? ?? const [])) (a as num).toDouble()];
    return Plot(
      id: j['id'] as String,
      name: j['name'] as String? ?? 'Plot',
      corners: corners,
      cornerAccuracy: acc.length == corners.length ? acc : null,
      method: MeasureMode.values.firstWhere((m) => m.name == j['method'], orElse: () => MeasureMode.walk),
      created: DateTime.tryParse(j['created'] as String? ?? ''),
      note: j['note'] as String? ?? '',
    );
  }
}

class Project {
  final String id;
  String name;
  String description;
  Color color;
  final List<Plot> plots;
  final List<SurveyPoint> points;
  DateTime created;
  bool sample;

  Project({
    required this.id,
    required this.name,
    this.description = '',
    required this.color,
    List<Plot>? plots,
    List<SurveyPoint>? points,
    DateTime? created,
    this.sample = false,
  })  : plots = plots ?? [],
        points = points ?? [],
        created = created ?? DateTime.now();

  double get totalArea => plots.fold(0.0, (s, p) => s + p.area);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'color': color.value,
        'created': created.toIso8601String(),
        'sample': sample,
        'plots': [for (final p in plots) p.toJson()],
        'points': [for (final p in points) p.toJson()],
      };

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Project',
        description: j['description'] as String? ?? '',
        color: Color((j['color'] as num?)?.toInt() ?? 0xFFFFB020),
        created: DateTime.tryParse(j['created'] as String? ?? ''),
        sample: j['sample'] as bool? ?? false,
        plots: [for (final p in (j['plots'] as List? ?? const [])) Plot.fromJson(p as Map<String, dynamic>)],
        points: [for (final p in (j['points'] as List? ?? const [])) SurveyPoint.fromJson(p as Map<String, dynamic>)],
      );
}

/// Project colours, chosen to read on both the dark and sunlight palettes.
const projectColors = <Color>[
  Color(0xFFFFB020),
  Color(0xFF2BD38A),
  Color(0xFF4DA3FF),
  Color(0xFFB57BFF),
  Color(0xFFFF7A59),
  Color(0xFF22C3D6),
];

LatLng _latLngFrom(List l) => LatLng((l[0] as num).toDouble(), (l[1] as num).toDouble());

int _idSeq = 0;
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_idSeq++).toRadixString(36)}';

String cornerLabel(int i) {
  const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  if (i < 26) return letters[i];
  return '${letters[i % 26]}${i ~/ 26}';
}

String shortDate(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

String timeOfDay(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
