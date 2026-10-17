import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/geo.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';

/// Default view: Monrovia.
const monrovia = LatLng(6.3156, -10.8074);

const _ua = 'lr.terraplot.terraplot';

/// Base map tiles for the selected style.
Widget baseTiles(BuildContext context, BaseMap style) {
  switch (style) {
    case BaseMap.satellite:
      return TileLayer(
        urlTemplate:
            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        userAgentPackageName: _ua,
        maxNativeZoom: 19,
        maxZoom: 21,
      );
    case BaseMap.dark:
      return TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: _ua,
        maxNativeZoom: 19,
        maxZoom: 21,
        tileBuilder: darkModeTileBuilder,
      );
    case BaseMap.street:
      return TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: _ua,
        maxNativeZoom: 19,
        maxZoom: 21,
      );
  }
}

String attributionFor(BaseMap style) => style == BaseMap.satellite
    ? 'Imagery © Esri, Maxar, Earthstar Geographics'
    : '© OpenStreetMap contributors';

IconData iconFor(BaseMap style) {
  switch (style) {
    case BaseMap.street:
      return Icons.map_outlined;
    case BaseMap.satellite:
      return Icons.satellite_alt_outlined;
    case BaseMap.dark:
      return Icons.dark_mode_outlined;
  }
}

/// Accuracy circle + location dot for the live GPS position.
List<Widget> userLocationLayers(BuildContext context, AppState app) {
  final c = context.tp;
  final p = app.location.latLng;
  final acc = app.location.accuracy;
  if (p == null) return const [];
  final color = c.accuracyColor(acc, limit: app.accuracyLimit);
  return [
    CircleLayer(circles: [
      CircleMarker(
        point: p,
        radius: (acc ?? 5).clamp(1.0, 200.0).toDouble(),
        useRadiusInMeter: true,
        color: color.withOpacity(0.12),
        borderColor: color.withOpacity(0.6),
        borderStrokeWidth: 1.5,
      ),
    ]),
    MarkerLayer(markers: [
      Marker(
        point: p,
        width: 44,
        height: 44,
        child: LocationDot(color: color),
      ),
    ]),
  ];
}

class LocationDot extends StatefulWidget {
  final Color color;
  const LocationDot({super.key, required this.color});

  @override
  State<LocationDot> createState() => _LocationDotState();
}

class _LocationDotState extends State<LocationDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 16 + 28 * t,
              height: 16 + 28 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(0.35 * (1 - t)),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
              ),
              alignment: Alignment.center,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Polygon (or open line while measuring) for a plot.
List<Widget> plotLayers(
  BuildContext context,
  List<LatLng> pts, {
  required Color color,
  bool closed = true,
  bool showCorners = true,
  bool showLengths = true,
  int? selected,
  void Function(int index)? onCornerTap,
}) {
  final c = context.tp;
  final layers = <Widget>[];
  if (pts.length >= 3 && closed) {
    layers.add(PolygonLayer(polygons: [
      Polygon(
        points: pts,
        color: color.withOpacity(0.18),
        borderColor: color,
        borderStrokeWidth: 2.5,
      ),
    ]));
  } else if (pts.length >= 2) {
    layers.add(PolylineLayer(polylines: [
      Polyline(points: pts, color: color, strokeWidth: 2.5),
    ]));
  }
  if (showLengths && pts.length >= 2) {
    final n = closed && pts.length >= 3 ? pts.length : pts.length - 1;
    final markers = <Marker>[];
    for (var i = 0; i < n; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      final mid = LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);
      markers.add(Marker(
        point: mid,
        width: 74,
        height: 22,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.glass,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.6)),
          ),
          child: Text(
            Geo.metres(Geo.distance(a, b)),
            style: TPText.reading(10.5, c.ink, weight: FontWeight.w700),
          ),
        ),
      ));
    }
    layers.add(MarkerLayer(markers: markers));
  }
  if (showCorners) {
    layers.add(MarkerLayer(markers: [
      for (var i = 0; i < pts.length; i++)
        Marker(
          point: pts[i],
          width: 30,
          height: 30,
          child: GestureDetector(
            onTap: onCornerTap == null ? null : () => onCornerTap(i),
            child: CornerChip(
              label: cornerLabel(i),
              color: color,
              selected: selected == i,
            ),
          ),
        ),
    ]));
  }
  return layers;
}

class CornerChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  const CornerChip({super.key, required this.label, required this.color, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? Colors.white : color,
        border: Border.all(color: selected ? color : Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: TPText.sans,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: selected ? color : const Color(0xFF1A1206),
        ),
      ),
    );
  }
}

/// Marker for a saved survey point.
Marker pointMarker(BuildContext context, SurveyPoint pt, Color color, {VoidCallback? onTap}) {
  return Marker(
    point: pt.latLng,
    width: 34,
    height: 34,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
        ),
        child: Icon(pt.type.icon, size: 16, color: const Color(0xFF1A1206)),
      ),
    ),
  );
}
