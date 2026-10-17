import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/geo.dart';
import '../core/location_service.dart';
import 'models.dart';

enum CoordFormat { decimal, dms, utm }

enum BaseMap { street, satellite, dark }

/// App-wide state: settings, projects and the live GPS service.
/// Phase 1 keeps data in memory; phase 4 adds the on-device database.
class AppState extends ChangeNotifier {
  final LocationService location = LocationService();

  // ----- Settings -----
  bool sunlight = false;
  AreaUnit areaUnit = AreaUnit.sqm;
  double lotSqm = 4046.8564224 / 4; // ¼ acre, common local usage
  double accuracyLimit = 10;
  String surveyorName = '';
  CoordFormat coordFormat = CoordFormat.decimal;
  BaseMap baseMap = BaseMap.street;
  bool motion = true;

  // ----- Data -----
  final List<Project> projects = [];

  AppState() {
    _loadSamples();
  }

  void update(VoidCallback change) {
    change();
    notifyListeners();
  }

  void cycleAreaUnit() {
    final all = AreaUnit.values;
    areaUnit = all[(all.indexOf(areaUnit) + 1) % all.length];
    notifyListeners();
  }

  void cycleCoordFormat() {
    final all = CoordFormat.values;
    coordFormat = all[(all.indexOf(coordFormat) + 1) % all.length];
    notifyListeners();
  }

  String formatArea(double sqm, [AreaUnit? unit]) =>
      (unit ?? areaUnit).format(sqm, lotSqm: lotSqm);

  List<SurveyPoint> get allPoints => [for (final p in projects) ...p.points];
  List<Plot> get allPlots => [for (final p in projects) ...p.plots];

  Project? projectOfPlot(Plot plot) {
    for (final p in projects) {
      if (p.plots.contains(plot)) return p;
    }
    return null;
  }

  Project? projectOfPoint(SurveyPoint pt) {
    for (final p in projects) {
      if (p.points.contains(pt)) return p;
    }
    return null;
  }

  Project addProject(String name, {String description = ''}) {
    final p = Project(
      id: newId(),
      name: name,
      description: description,
      color: projectColors[projects.length % projectColors.length],
    );
    projects.insert(0, p);
    notifyListeners();
    return p;
  }

  void addPlot(Project project, Plot plot) {
    project.plots.insert(0, plot);
    notifyListeners();
  }

  void addPoint(Project project, SurveyPoint pt) {
    project.points.insert(0, pt);
    notifyListeners();
  }

  void deletePlot(Plot plot) {
    for (final p in projects) {
      p.plots.remove(plot);
    }
    notifyListeners();
  }

  void deletePoint(SurveyPoint pt) {
    for (final p in projects) {
      p.points.remove(pt);
    }
    notifyListeners();
  }

  void deleteProject(Project project) {
    projects.remove(project);
    notifyListeners();
  }

  Project ensureProject() {
    if (projects.isEmpty) return addProject('My survey');
    return projects.first;
  }

  void _loadSamples() {
    final now = DateTime.now();
    final lot = Project(
      id: newId(),
      name: 'Sample — Paynesville lot',
      description: 'Demo plot to explore the app. Delete it any time.',
      color: projectColors[0],
      created: now.subtract(const Duration(days: 3)),
      sample: true,
      plots: [
        Plot(
          id: newId(),
          name: 'Residential lot',
          method: MeasureMode.walk,
          created: now.subtract(const Duration(days: 3)),
          corners: [
            LatLng(6.2848639, -10.7121441),
            LatLng(6.2848558, -10.7118459),
            LatLng(6.2851542, -10.7118650),
            LatLng(6.2851351, -10.7121541),
          ],
          cornerAccuracy: [3.2, 2.8, 4.1, 3.6],
          note: 'Fence along the north side; road frontage on the south.',
        ),
      ],
      points: [
        SurveyPoint(
          id: newId(),
          name: 'Pillar P1',
          type: PointType.pillar,
          lat: 6.2848639,
          lon: -10.7121441,
          accuracy: 1.9,
          altitude: 14.2,
          readings: 60,
          time: now.subtract(const Duration(days: 3)),
          note: 'Concrete pillar, painted red.',
        ),
      ],
    );
    final field = Project(
      id: newId(),
      name: 'Sample — Field sampling',
      description: 'Demo sampling sites with averaged positions.',
      color: projectColors[2],
      created: now.subtract(const Duration(days: 1)),
      sample: true,
      points: [
        SurveyPoint(
          id: newId(),
          name: 'Stream S1 upstream',
          type: PointType.sampling,
          lat: 6.2857269,
          lon: -10.7109180,
          accuracy: 2.4,
          altitude: 11.8,
          readings: 120,
          time: now.subtract(const Duration(days: 1, hours: 2)),
          note: 'Clear water, pH to be tested.',
        ),
        SurveyPoint(
          id: newId(),
          name: 'Stream S2 downstream',
          type: PointType.sampling,
          lat: 6.2846460,
          lon: -10.7096493,
          accuracy: 3.1,
          altitude: 9.6,
          readings: 60,
          time: now.subtract(const Duration(days: 1, hours: 1)),
        ),
        SurveyPoint(
          id: newId(),
          name: 'Community well',
          type: PointType.well,
          lat: 6.2868962,
          lon: -10.7128195,
          accuracy: 4.8,
          altitude: 16.0,
          readings: 30,
          time: now.subtract(const Duration(days: 1)),
        ),
      ],
    );
    projects.addAll([field, lot]);
  }

  @override
  void dispose() {
    location.dispose();
    super.dispose();
  }
}

/// Makes [AppState] available to every widget.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing to rebuilds.
  static AppState read(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<AppScope>()!.widget as AppScope)
          .notifier!;
}
