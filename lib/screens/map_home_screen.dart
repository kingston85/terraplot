import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../core/geo.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/map_layers.dart';
import 'point_detail_screen.dart';

class MapHomeScreen extends StatefulWidget {
  const MapHomeScreen({super.key});

  @override
  State<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends State<MapHomeScreen> {
  final MapController _map = MapController();
  bool _ready = false;
  bool _follow = true;
  bool _centeredOnce = false;
  AppState? _app;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.read(context);
    if (_app != app) {
      _app?.location.removeListener(_onLocation);
      _app = app;
      app.location.addListener(_onLocation);
    }
  }

  @override
  void dispose() {
    _app?.location.removeListener(_onLocation);
    super.dispose();
  }

  void _onLocation() {
    final p = _app?.location.latLng;
    if (p == null || !_ready) return;
    if (!_centeredOnce) {
      _centeredOnce = true;
      _map.move(p, 18);
    } else if (_follow) {
      _map.move(p, _map.camera.zoom);
    }
  }

  void _recenter() {
    final p = _app?.location.latLng;
    setState(() => _follow = true);
    if (p != null && _ready) _map.move(p, _map.camera.zoom < 16 ? 18 : _map.camera.zoom);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tp;
    final bottomInset = MediaQuery.of(context).padding.bottom + 76 + 14;
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: app.location,
            builder: (context, _) => FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: app.location.latLng ?? monrovia,
                initialZoom: app.location.latLng != null ? 18 : 13,
                maxZoom: 21,
                backgroundColor: c.bg,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapReady: () {
                  _ready = true;
                  _onLocation();
                },
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture && _follow) setState(() => _follow = false);
                },
              ),
              children: [
                baseTiles(context, app.baseMap),
                for (final pr in app.projects)
                  for (final plot in pr.plots)
                    ...plotLayers(context, plot.corners,
                        color: pr.color, showLengths: false, showCorners: false),
                MarkerLayer(markers: [
                  for (final pr in app.projects)
                    for (final pt in pr.points)
                      pointMarker(context, pt, pr.color,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => PointDetailScreen(point: pt)))),
                ]),
                ...userLocationLayers(context, app),
              ],
            ),
          ),

          // Top bar
          Positioned(
            top: top + 10,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Glass(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  radius: BorderRadius.circular(999),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandMark(size: 20),
                      const SizedBox(width: 8),
                      Text('TERRAPLOT', style: TPText.label(c.ink, size: 12)),
                      Text(' LR', style: TPText.label(c.accent, size: 12)),
                    ],
                  ),
                ),
                const Spacer(),
                const AccuracyPill(),
                const SizedBox(width: 8),
                MapButton(
                  icon: app.sunlight ? Icons.wb_sunny_rounded : Icons.wb_sunny_outlined,
                  tooltip: 'Sunlight mode',
                  active: app.sunlight,
                  onTap: () => app.update(() => app.sunlight = !app.sunlight),
                ),
              ],
            ),
          ),

          // Right-side controls
          Positioned(
            right: 12,
            bottom: bottomInset + 128,
            child: Column(
              children: [
                MapButton(
                  icon: iconFor(app.baseMap),
                  tooltip: 'Map style',
                  onTap: () => _pickBaseMap(context, app),
                ),
                const SizedBox(height: 10),
                MapButton(
                  icon: _follow ? Icons.my_location_rounded : Icons.location_searching_rounded,
                  tooltip: 'Centre on me',
                  active: _follow,
                  onTap: _recenter,
                ),
              ],
            ),
          ),

          // Live readout
          Positioned(
            left: 12,
            right: 12,
            bottom: bottomInset,
            child: const LiveReadout(),
          ),
        ],
      ),
    );
  }

  void _pickBaseMap(BuildContext context, AppState app) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final c = context.tp;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Map style', style: TPText.title(c.ink, size: 18)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (final s in BaseMap.values) ...[
                      Expanded(
                        child: _StyleTile(
                          style: s,
                          selected: app.baseMap == s,
                          onTap: () {
                            app.update(() => app.baseMap = s);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      if (s != BaseMap.values.last) const SizedBox(width: 10),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Text('Offline map downloads arrive in phase 2.',
                    style: TPText.body(c.inkDim, size: 12.5)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StyleTile extends StatelessWidget {
  final BaseMap style;
  final bool selected;
  final VoidCallback onTap;
  const _StyleTile({required this.style, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    final names = {BaseMap.street: 'Street', BaseMap.satellite: 'Satellite', BaseMap.dark: 'Night'};
    return TPCard(
      onTap: onTap,
      borderColor: selected ? c.accent : null,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(iconFor(style), color: selected ? c.accent : c.ink, size: 28),
          const SizedBox(height: 8),
          Text(names[style]!, style: TPText.body(c.ink, size: 13, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Glass panel with the live coordinates. Tap to switch format.
class LiveReadout extends StatelessWidget {
  const LiveReadout({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tp;
    return GestureDetector(
      onTap: app.cycleCoordFormat,
      child: Glass(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: AnimatedBuilder(
          animation: app.location,
          builder: (context, _) {
            final pos = app.location.position;
            final p = app.location.latLng;
            String l1 = '—', l2 = '—', k1 = 'LATITUDE', k2 = 'LONGITUDE';
            if (p != null) {
              switch (app.coordFormat) {
                case CoordFormat.decimal:
                  l1 = Geo.decimal(p.latitude, isLat: true);
                  l2 = Geo.decimal(p.longitude, isLat: false);
                  break;
                case CoordFormat.dms:
                  l1 = Geo.dms(p.latitude, isLat: true);
                  l2 = Geo.dms(p.longitude, isLat: false);
                  break;
                case CoordFormat.utm:
                  final u = Geo.toUtmLL(p);
                  k1 = 'EASTING · ${u.zoneLabel}';
                  k2 = 'NORTHING';
                  l1 = '${Geo.group(u.easting, places: 2)} m';
                  l2 = '${Geo.group(u.northing, places: 2)} m';
                  break;
              }
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Reading(label: k1, value: l1, size: 16)),
                    const SizedBox(width: 12),
                    Expanded(child: Reading(label: k2, value: l2, size: 16)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Reading(
                        label: 'Altitude',
                        value: pos == null ? '—' : '${pos.altitude.toStringAsFixed(1)} m',
                        size: 13,
                        color: c.inkDim,
                      ),
                    ),
                    Expanded(
                      child: Reading(
                        label: 'Speed',
                        value: pos == null ? '—' : '${(pos.speed * 3.6).clamp(0, 999).toStringAsFixed(1)} km/h',
                        size: 13,
                        color: c.inkDim,
                      ),
                    ),
                    Icon(Icons.swap_horiz_rounded, color: c.inkDim, size: 18),
                    const SizedBox(width: 4),
                    Text(_formatName(app.coordFormat), style: TPText.label(c.inkDim, size: 10)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(attributionFor(app.baseMap), style: TPText.body(c.inkDim, size: 9.5)),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatName(CoordFormat f) {
    switch (f) {
      case CoordFormat.decimal:
        return 'DECIMAL';
      case CoordFormat.dms:
        return 'DMS';
      case CoordFormat.utm:
        return 'UTM';
    }
  }
}

/// The app's mark: a surveyor's corner peg inside a plot outline.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _BrandPainter(context.tp.accent));
  }
}

class _BrandPainter extends CustomPainter {
  final Color color;
  _BrandPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.1
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(s * 0.12, s * 0.30)
      ..lineTo(s * 0.70, s * 0.12)
      ..lineTo(s * 0.88, s * 0.72)
      ..lineTo(s * 0.26, s * 0.88)
      ..close();
    canvas.drawPath(path, stroke);
    final fill = Paint()..color = color;
    canvas.drawCircle(Offset(s * 0.12, s * 0.30), s * 0.12, fill);
    canvas.drawCircle(Offset(s * 0.88, s * 0.72), s * 0.12, fill);
  }

  @override
  bool shouldRepaint(covariant _BrandPainter old) => old.color != color;
}
