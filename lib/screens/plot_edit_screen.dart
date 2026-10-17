import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/geo.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/map_layers.dart';

/// Edit a saved plot's corners: select a corner, then tap the map to move
/// it, move it to your GPS position, insert a corner after it, or delete it.
class PlotEditScreen extends StatefulWidget {
  final Plot plot;
  const PlotEditScreen({super.key, required this.plot});

  @override
  State<PlotEditScreen> createState() => _PlotEditScreenState();
}

class _PlotEditScreenState extends State<PlotEditScreen> {
  late final List<LatLng> _pts = List<LatLng>.from(widget.plot.corners);
  late final List<double> _acc = widget.plot.cornerAccuracy.length == widget.plot.corners.length
      ? List<double>.from(widget.plot.cornerAccuracy)
      : List<double>.filled(widget.plot.corners.length, 0, growable: true);
  int? _sel;
  bool _changed = false;
  DateTime _lastCornerTap = DateTime(2000);

  void _select(int i) {
    _lastCornerTap = DateTime.now();
    HapticFeedback.selectionClick();
    setState(() => _sel = _sel == i ? null : i);
  }

  void _moveSelected(LatLng p, double acc) {
    final i = _sel;
    if (i == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Tap a corner first, then tap where it should go.')));
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _pts[i] = p;
      _acc[i] = acc;
      _changed = true;
    });
  }

  void _moveToGps() {
    final loc = AppScope.read(context).location;
    if (!loc.hasFix) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.statusText)));
      return;
    }
    _moveSelected(loc.latLng!, loc.accuracy ?? 0);
  }

  void _insertAfter() {
    final i = _sel;
    if (i == null) return;
    final a = _pts[i];
    final b = _pts[(i + 1) % _pts.length];
    setState(() {
      _pts.insert(i + 1, LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2));
      _acc.insert(i + 1, 0);
      _sel = i + 1;
      _changed = true;
    });
    HapticFeedback.mediumImpact();
  }

  void _delete() {
    final i = _sel;
    if (i == null) return;
    if (_pts.length <= 3) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('A plot needs at least 3 corners.')));
      return;
    }
    setState(() {
      _pts.removeAt(i);
      _acc.removeAt(i);
      _sel = null;
      _changed = true;
    });
  }

  void _reverse() {
    setState(() {
      final p = _pts.reversed.toList();
      final a = _acc.reversed.toList();
      _pts
        ..clear()
        ..addAll(p);
      _acc
        ..clear()
        ..addAll(a);
      _sel = null;
      _changed = true;
    });
  }

  void _save() {
    final app = AppScope.read(context);
    app.update(() {
      widget.plot.corners = List<LatLng>.from(_pts);
      widget.plot.cornerAccuracy = List<double>.from(_acc);
    });
    Navigator.pop(context);
  }

  Future<bool> _confirmLeave() async {
    if (!_changed) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your corner edits have not been saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep editing')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tp;
    final project = app.projectOfPlot(widget.plot);
    final color = project?.color ?? c.accent;
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: !_changed,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmLeave()) {
          _changed = false;
          nav.pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            AnimatedBuilder(
              animation: app.location,
              builder: (context, _) => FlutterMap(
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(widget.plot.corners),
                    padding: EdgeInsets.fromLTRB(56, top + 90, 56, 260 + bottom),
                  ),
                  maxZoom: 21,
                  backgroundColor: c.bg,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onTap: (_, latlng) {
                    // A tap on a corner chip can also reach the map; ignore it.
                    if (DateTime.now().difference(_lastCornerTap).inMilliseconds < 350) return;
                    _moveSelected(latlng, 0);
                  },
                ),
                children: [
                  baseTiles(context, app.baseMap),
                  ...plotLayers(context, _pts, color: color, selected: _sel, onCornerTap: _select),
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
                  MapButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Cancel',
                    onTap: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Glass(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Text(
                        _sel == null
                            ? 'Tap a corner to select it'
                            : 'Corner ${cornerLabel(_sel!)} selected · tap the map to move it',
                        style: TPText.body(c.ink, size: 13, weight: FontWeight.w600),
                        maxLines: 2,
                      ),
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
                      children: [
                        Expanded(
                          child: Reading(
                            label: 'Area',
                            value: app.formatArea(Geo.area(_pts)),
                            size: 20,
                          ),
                        ),
                        Reading(
                          label: 'Perimeter',
                          value: Geo.metres(Geo.perimeter(_pts)),
                          align: CrossAxisAlignment.end,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _Tool(icon: Icons.my_location_rounded, label: 'To GPS', onTap: _sel == null ? null : _moveToGps),
                        _Tool(icon: Icons.add_circle_outline_rounded, label: 'Insert after', onTap: _sel == null ? null : _insertAfter),
                        _Tool(icon: Icons.delete_outline_rounded, label: 'Delete', onTap: _sel == null ? null : _delete, danger: true),
                        _Tool(icon: Icons.swap_horiz_rounded, label: 'Reverse', onTap: _reverse),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _changed ? _save : null,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Save changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  const _Tool({required this.icon, required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    final enabled = onTap != null;
    final color = !enabled ? c.inkDim.withOpacity(0.45) : (danger ? c.poor : c.ink);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: c.surface2,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(height: 4),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: TPText.sans, fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
