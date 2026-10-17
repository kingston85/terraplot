import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/exporters.dart';
import '../core/geo.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/map_layers.dart';
import '../widgets/save_plot_sheet.dart';
import 'plot_result_screen.dart';

/// Builds a plot from typed or pasted corner coordinates, e.g. from a
/// survey plan, a deed or a field notebook.
class CoordinatePlotScreen extends StatefulWidget {
  const CoordinatePlotScreen({super.key});

  @override
  State<CoordinatePlotScreen> createState() => _CoordinatePlotScreenState();
}

class _CoordinatePlotScreenState extends State<CoordinatePlotScreen> {
  final _text = TextEditingController();
  final MapController _map = MapController();
  bool _utm = true;
  bool _ready = false;
  int _lastFitCount = 0;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  ParseResult get _parsed => CoordinateParser.parse(_text.text, utm: _utm);

  void _fit(ParseResult r) {
    if (!_ready || r.points.isEmpty || r.points.length == _lastFitCount) return;
    _lastFitCount = r.points.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (r.points.length == 1) {
        _map.move(r.points.first, 18);
      } else {
        _map.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(r.points),
          padding: const EdgeInsets.all(40),
        ));
      }
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    setState(() => _text.text = data!.text!);
  }

  Future<void> _save() async {
    final r = _parsed;
    if (r.points.length < 3) return;
    final app = AppScope.read(context);
    final result = await showSavePlotSheet(context, Geo.area(r.points));
    if (result == null || !mounted) return;
    final plot = savePlotFromResult(
      app,
      result,
      Plot(
        id: newId(),
        name: result.name,
        corners: r.points,
        method: MeasureMode.map,
        note: 'Entered from ${_utm ? 'UTM 29N' : 'latitude/longitude'} coordinates.',
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PlotResultScreen(plot: plot)));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tp;
    final r = _parsed;
    _fit(r);
    final area = Geo.area(r.points);

    return Scaffold(
      appBar: AppBar(title: const Text('Plot from coordinates')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(
            'Type or paste one corner per line, in order around the plot. Labels like "P1" are ignored.',
            style: TPText.body(c.inkDim, size: 13),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                for (final opt in [true, false])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _utm = opt;
                        _lastFitCount = 0;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _utm == opt ? c.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          opt ? 'UTM 29N (E, N)' : 'Lat, Long',
                          style: TextStyle(
                            fontFamily: TPText.sans,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _utm == opt ? c.onAccent : c.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            onChanged: (_) => setState(() {}),
            minLines: 5,
            maxLines: 10,
            style: TPText.reading(14, c.ink),
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: _utm
                  ? 'P1  311917.1  694446.8\nP2  311950.1  694445.8\nP3  311948.1  694478.8\nP4  311916.1  694476.8'
                  : '6.2848639, -10.7121441\n6.2848558, -10.7118459\n6.2851542, -10.7118650\n6.2851351, -10.7121541',
              hintMaxLines: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                label: const Text('Paste'),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _text.clear();
                  _lastFitCount = 0;
                }),
                icon: const Icon(Icons.clear_rounded, size: 18),
                label: const Text('Clear'),
              ),
              const Spacer(),
              Text('${r.points.length} corners', style: TPText.reading(12.5, c.inkDim)),
            ],
          ),
          if (r.errors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(r.errors.take(3).join('\n'), style: TPText.body(c.poor, size: 12.5)),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 240,
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: monrovia,
                  initialZoom: 12,
                  maxZoom: 21,
                  backgroundColor: c.bg,
                  onMapReady: () {
                    _ready = true;
                    _fit(_parsed);
                  },
                ),
                children: [
                  baseTiles(context, app.baseMap),
                  ...plotLayers(context, r.points, color: c.accent, closed: r.points.length >= 3),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          TPCard(
            child: Row(
              children: [
                Expanded(
                  child: Reading(
                    label: 'Area',
                    value: r.points.length >= 3 ? app.formatArea(area) : '—',
                    size: 18,
                  ),
                ),
                Reading(
                  label: 'Perimeter',
                  value: r.points.length >= 2 ? Geo.metres(Geo.perimeter(r.points)) : '—',
                  align: CrossAxisAlignment.end,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: r.points.length >= 3 ? _save : null,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save as plot'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Distance and bearing along a line: tap the map or add GPS positions.
class DistanceScreen extends StatefulWidget {
  const DistanceScreen({super.key});

  @override
  State<DistanceScreen> createState() => _DistanceScreenState();
}

class _DistanceScreenState extends State<DistanceScreen> {
  final List<LatLng> _pts = [];

  void _add(LatLng p) {
    HapticFeedback.selectionClick();
    setState(() => _pts.add(p));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tp;
    final total = Geo.perimeter(_pts, closed: false);
    final last = _pts.length >= 2 ? Geo.bearing(_pts[_pts.length - 2], _pts.last) : null;
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: app.location,
            builder: (context, _) => FlutterMap(
              options: MapOptions(
                initialCenter: app.location.latLng ?? monrovia,
                initialZoom: app.location.latLng != null ? 18 : 13,
                maxZoom: 21,
                backgroundColor: c.bg,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: (_, p) => _add(p),
              ),
              children: [
                baseTiles(context, app.baseMap),
                ...plotLayers(context, _pts, color: c.accent, closed: false),
                ...userLocationLayers(context, app),
              ],
            ),
          ),
          Positioned(
            top: top + 10,
            left: 12,
            right: 12,
            child: Row(
              children: [
                MapButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => Navigator.pop(context)),
                const SizedBox(width: 10),
                Expanded(
                  child: Glass(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text('Tap the map to add points along a line',
                        style: TPText.body(c.ink, size: 13, weight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + bottom),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                border: Border(top: BorderSide(color: c.line)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const PanelLabel('Total distance'),
                            const SizedBox(height: 4),
                            Text(Geo.metres(total), style: TPText.reading(32, c.ink, weight: FontWeight.w700)),
                            Text(Geo.feet(total), style: TPText.reading(12, c.inkDim)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Reading(
                            label: 'Last bearing',
                            value: last == null ? '—' : Geo.bearingText(last),
                            align: CrossAxisAlignment.end,
                          ),
                          const SizedBox(height: 8),
                          Reading(label: 'Points', value: '${_pts.length}', align: CrossAxisAlignment.end),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pts.isEmpty ? null : () => setState(() => _pts.removeLast()),
                          icon: const Icon(Icons.undo_rounded),
                          label: const Text('Undo'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: () {
                            final p = app.location.latLng;
                            if (p == null) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(app.location.statusText)));
                              return;
                            }
                            HapticFeedback.mediumImpact();
                            _add(p);
                          },
                          icon: const Icon(Icons.my_location_rounded),
                          label: const Text('Add my position'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
