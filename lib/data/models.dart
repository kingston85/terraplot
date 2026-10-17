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
