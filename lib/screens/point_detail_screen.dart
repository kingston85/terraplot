import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

import '../core/geo.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/map_layers.dart';

class PointDetailScreen extends StatelessWidget {
  final SurveyPoint point;
  const PointDetailScreen({super.key, required this.point});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tp;
    final project = app.projectOfPoint(point);
    final color = project?.color ?? c.accent;
    final u = point.utm;
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 260 + top,
            child: Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: point.latLng,
                      initialZoom: 18,
                      maxZoom: 21,
                      backgroundColor: c.bg,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                      ),
                    ),
                    children: [
                      baseTiles(context, app.baseMap),
                      if (point.accuracy > 0)
                        CircleLayer(circles: [
                          CircleMarker(
                            point: point.latLng,
                            radius: point.accuracy,
                            useRadiusInMeter: true,
                            color: color.withOpacity(0.15),
                            borderColor: color,
                            borderStrokeWidth: 1.5,
                          ),
                        ]),
                      MarkerLayer(markers: [pointMarker(context, point, color)]),
                    ],
                  ),
                ),
                Positioned(
                  top: top + 10,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      MapButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onTap: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      MapButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Delete point',
                        onTap: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete this point?'),
                              content: Text('"${point.name}" will be removed.'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                FilledButton(
                                    onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (ok == true && context.mounted) {
                            app.deletePoint(point);
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Tag(point.type.label, color: color, icon: point.type.icon),
                    const SizedBox(width: 8),
                    if (project != null) Tag(project.name, color: c.inkDim, icon: Icons.folder_rounded),
                  ],
                ),
                const SizedBox(height: 12),
                Text(point.name, style: TPText.title(c.ink, size: 26)),
                const SizedBox(height: 4),
                Text('Recorded ${shortDate(point.time)} at ${timeOfDay(point.time)}',
                    style: TPText.body(c.inkDim, size: 13)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => NavigateScreen(point: point))),
                    icon: const Icon(Icons.navigation_rounded),
                    label: const Text('Navigate to this point'),
                  ),
                ),
                const SectionHeader('Position'),
                TPCard(
                  child: Column(
                    children: [
                      _Row('Latitude', Geo.decimal(point.lat, isLat: true, places: 7)),
                      _Row('', Geo.dms(point.lat, isLat: true), dim: true),
                      const Divider(height: 24),
                      _Row('Longitude', Geo.decimal(point.lon, isLat: false, places: 7)),
                      _Row('', Geo.dms(point.lon, isLat: false), dim: true),
                      const Divider(height: 24),
                      _Row('Easting · ${u.zoneLabel}', '${Geo.group(u.easting, places: 2)} m'),
                      _Row('Northing', '${Geo.group(u.northing, places: 2)} m'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                          text: '${point.lat.toStringAsFixed(7)}, ${point.lon.toStringAsFixed(7)}'));
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Coordinates copied.')));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy coordinates'),
                  ),
                ),
                const SectionHeader('Quality'),
                Row(
                  children: [
                    Expanded(
                      child: _Mini(
                        label: 'Accuracy',
                        value: '±${point.accuracy.toStringAsFixed(2)} m',
                        color: c.accuracyColor(point.accuracy),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _Mini(label: 'Readings', value: '${point.readings}')),
                    const SizedBox(width: 10),
                    Expanded(child: _Mini(label: 'Altitude', value: '${point.altitude.toStringAsFixed(1)} m')),
                  ],
                ),
                if (point.note.isNotEmpty) ...[
                  const SectionHeader('Note'),
                  TPCard(child: Text(point.note, style: TPText.body(c.ink))),
                ],
                const SectionHeader('Photos'),
                TPCard(
                  onTap: () => showComingSoon(context, 'Point photos', 'phase 4'),
                  child: Row(
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: c.inkDim),
                      const SizedBox(width: 12),
                      Text('Add photos of this point', style: TPText.body(c.inkDim)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool dim;
  const _Row(this.label, this.value, {this.dim = false});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: label.isEmpty ? const SizedBox() : PanelLabel(label)),
          Text(value, style: TPText.reading(dim ? 12.5 : 14.5, dim ? c.inkDim : c.ink)),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Mini({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    return TPCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelLabel(label),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TPText.reading(15, color ?? c.ink, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Guides the user back to a saved point: distance and direction.
class NavigateScreen extends StatelessWidget {
  final SurveyPoint point;
  const NavigateScreen({super.key, required this.point});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tp;
    return Scaffold(
      appBar: AppBar(
        title: Text(point.name),
        actions: const [Padding(padding: EdgeInsets.only(right: 12), child: AccuracyPill(compact: true))],
      ),
      body: AnimatedBuilder(
        animation: app.location,
        builder: (context, _) {
          final here = app.location.latLng;
          if (here == null) {
            return Center(
              child: EmptyState(
                icon: Icons.gps_not_fixed_rounded,
                title: app.location.statusText,
                body: 'Waiting for your position. Stand in open sky for the best signal.',
              ),
            );
          }
          final dist = Geo.distance(here, point.latLng);
          final brg = Geo.bearing(here, point.latLng);
          final pos = app.location.position;
          final moving = pos != null && pos.speed > 0.6 && pos.heading >= 0;
          final heading = moving ? pos.heading : 0.0;
          final rel = (brg - heading) * math.pi / 180;
          final arrived = dist <= math.max(3, (app.location.accuracy ?? 3));

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                AnimatedRotation(
                  turns: rel / (2 * math.pi),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.surface,
                      border: Border.all(color: arrived ? c.good : c.line, width: 2),
                    ),
                    child: Icon(
                      arrived ? Icons.check_circle_rounded : Icons.navigation_rounded,
                      size: 120,
                      color: arrived ? c.good : c.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  arrived ? 'You are here' : Geo.metres(dist),
                  style: TPText.reading(48, c.ink, weight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  arrived ? 'Within GPS accuracy of the point' : 'Bearing ${Geo.bearingText(brg)}',
                  style: TPText.body(c.inkDim, size: 15),
                ),
                const Spacer(),
                Text(
                  moving
                      ? 'Arrow follows your walking direction.'
                      : 'Arrow points from north. Start walking and it will follow your direction. '
                          'A live compass arrives in phase 4.',
                  textAlign: TextAlign.center,
                  style: TPText.body(c.inkDim, size: 12.5),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
