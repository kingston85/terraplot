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
import 'plot_result_screen.dart';

class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> with SingleTickerProviderStateMixin {
  final MapController _map = MapController();
  final List<LatLng> _pts = [];
  final List<double> _acc = [];
  MeasureMode _mode = MeasureMode.walk;
  bool _recording = false;
  bool _ready = false;
  bool _follow = true;
  int? _selected;
  AppState? _app;

  /// Minimum spacing between auto-walk corners, in metres.
  static const double _autoSpacing = 3.0;

  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

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
    _pulse.dispose();
    super.dispose();
  }

  void _onLocation() {
    final app = _app;
    if (app == null) return;
    final p = app.location.latLng;
    if (p == null) return;
    if (_ready && _follow && _mode != MeasureMode.map) {
      _map.move(p, _map.camera.zoom);
    }
    if (_mode == MeasureMode.auto && _recording && app.location.hasFix) {
      final acc = app.location.accuracy ?? 99;
      if (acc > app.accuracyLimit) return;
      if (_pts.isEmpty || Geo.distance(_pts.last, p) >= _autoSpacing) {
        setState(() {
          _pts.add(p);
          _acc.add(acc);
        });
        HapticFeedback.selectionClick();
      }
    }
  }

  void _addCorner(LatLng p, double acc) {
    setState(() {
      _pts.add(p);
      _acc.add(acc);
      _selected = null;
    });
    HapticFeedback.heavyImpact();
    if (_app?.motion ?? true) _pulse.forward(from: 0);
  }

  Future<void> _captureHere() async {
    final app = AppScope.read(context);
    final loc = app.location;
    if (!loc.hasFix) {
      _toast(loc.statusText);
      return;
    }
    final acc = loc.accuracy ?? 99;
    if (acc > app.accuracyLimit) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) {
          final c = context.tp;
          return AlertDialog(
            icon: Icon(Icons.gps_not_fixed_rounded, color: c.poor),
            title: const Text('Poor GPS accuracy'),
            content: Text(
              'Current accuracy is ±${acc.toStringAsFixed(1)} m, above your limit of '
              '${app.accuracyLimit.toStringAsFixed(0)} m. Wait a few seconds in open sky, or capture anyway.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Wait')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Capture anyway')),
            ],
          );
        },
      );
      if (ok != true) return;
    }
    _addCorner(loc.latLng!, acc);
  }

  void _undo() {
    if (_pts.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pts.removeLast();
      _acc.removeLast();
      _selected = null;
    });
  }

  void _deleteSelected() {
    final i = _selected;
    if (i == null) return;
    setState(() {
      _pts.removeAt(i);
      _acc.removeAt(i);
      _selected = null;
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _finish() async {
    if (_pts.length < 3) {
      _toast('Add at least 3 corners to make a plot.');
      return;
    }
    setState(() => _recording = false);
    final app = AppScope.read(context);
    final result = await showModalBottomSheet<_SaveResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AppScope(state: app, child: _SaveSheet(area: Geo.area(_pts))),
    );
    if (result == null || !mounted) return;
    final project = result.project ?? app.addProject(result.newProjectName ?? 'My survey');
    final plot = Plot(
      id: newId(),
      name: result.name,
      corners: List<LatLng>.from(_pts),
      cornerAccuracy: List<double>.from(_acc),
      method: _mode,
    );
    app.addPlot(project, plot);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PlotResultScreen(plot: plot)),
    );
  }

  Future<bool> _confirmDiscard() async {
    if (_pts.isEmpty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this measurement?'),
        content: Text('${_pts.length} corners will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep measuring')),
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
    final top = MediaQuery.of(context).padding.top;
    final area = Geo.area(_pts);
    final perim = Geo.perimeter(_pts, closed: _pts.length >= 3);
    final sigma = Geo.areaUncertainty(_pts, _acc);

    return PopScope(
      canPop: _pts.isEmpty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) {
          _pts.clear();
          nav.pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            AnimatedBuilder(
              animation: app.location,
              builder: (context, _) => FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: app.location.latLng ?? monrovia,
                  initialZoom: app.location.latLng != null ? 19 : 14,
                  maxZoom: 21,
                  backgroundColor: c.bg,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () => _ready = true,
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture && _follow) setState(() => _follow = false);
                  },
                  onTap: (tap, latlng) {
                    if (_mode == MeasureMode.map) {
                      _addCorner(latlng, 0);
                    } else if (_selected != null) {
                      setState(() => _selected = null);
                    }
                  },
                ),
                children: [
                  baseTiles(context, app.baseMap),
                  ...plotLayers(
                    context,
                    _pts,
                    color: c.accent,
                    closed: _pts.length >= 3,
                    selected: _selected,
                    onCornerTap: (i) => setState(() => _selected = _selected == i ? null : i),
                  ),
                  ...userLocationLayers(context, app),
                ],
              ),
            ),

            // Top controls
            Positioned(
              top: top + 10,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  Row(
                    children: [
                      MapButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onTap: () => Navigator.maybePop(context),
                      ),
                      const Spacer(),
                      const AccuracyPill(),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _ModeSwitch(
                    mode: _mode,
                    onChanged: (m) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _mode = m;
                        _recording = false;
                      });
                    },
                  ),
                  if (_mode == MeasureMode.map && _pts.isEmpty) ...[
                    const SizedBox(height: 10),
                    Glass(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Text('Tap the map at each corner of the plot, in order.',
                          style: TPText.body(c.ink, size: 13)),
                    ),
                  ],
                  if (_mode == MeasureMode.auto && _recording) ...[
                    const SizedBox(height: 10),
                    Glass(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fiber_manual_record, color: c.poor, size: 14),
                          const SizedBox(width: 8),
                          Text('Recording — walk the boundary slowly',
                              style: TPText.body(c.ink, size: 13, weight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Recenter
            Positioned(
              right: 12,
              bottom: 300 + MediaQuery.of(context).padding.bottom,
              child: MapButton(
                icon: _follow ? Icons.my_location_rounded : Icons.location_searching_rounded,
                tooltip: 'Centre on me',
                active: _follow,
                onTap: () {
                  setState(() => _follow = true);
                  final p = app.location.latLng;
                  if (p != null && _ready) _map.move(p, _map.camera.zoom);
                },
              ),
            ),

            // Bottom panel
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + MediaQuery.of(context).padding.bottom),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                  border: Border(top: BorderSide(color: c.line)),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: app.cycleAreaUnit,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const PanelLabel('Area'),
                                  const SizedBox(width: 6),
                                  Icon(Icons.swap_vert_rounded, size: 14, color: c.inkDim),
                                ]),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      RollingNumber(
                                        value: app.areaUnit.convert(area, lotSqm: app.lotSqm),
                                        format: (v) => Geo.group(v, places: app.areaUnit.places),
                                        style: TPText.reading(38, c.ink, weight: FontWeight.w700),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(app.areaUnit.label,
                                          style: TPText.body(c.accent, size: 16, weight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                                if (sigma > 0 && _pts.length >= 3)
                                  Text('± ${app.formatArea(sigma)} (1σ)',
                                      style: TPText.reading(11.5, c.inkDim)),
                              ],
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Reading(
                              label: 'Perimeter',
                              value: Geo.metres(perim),
                              align: CrossAxisAlignment.end,
                            ),
                            const SizedBox(height: 10),
                            Reading(
                              label: 'Corners',
                              value: '${_pts.length}',
                              align: CrossAxisAlignment.end,
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_selected != null) ...[
                      const SizedBox(height: 12),
                      _SelectedCornerBar(
                        label: cornerLabel(_selected!),
                        point: _pts[_selected!],
                        accuracy: _acc[_selected!],
                        onDelete: _deleteSelected,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _SquareAction(icon: Icons.undo_rounded, label: 'Undo', onTap: _pts.isEmpty ? null : _undo),
                        const SizedBox(width: 10),
                        Expanded(child: _primaryAction(c)),
                        const SizedBox(width: 10),
                        _SquareAction(
                          icon: Icons.check_rounded,
                          label: 'Finish',
                          highlight: _pts.length >= 3,
                          onTap: _finish,
                        ),
                      ],
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

  Widget _primaryAction(TPColors c) {
    switch (_mode) {
      case MeasureMode.walk:
        return _CaptureButton(
          pulse: _pulse,
          label: 'Capture corner ${cornerLabel(_pts.length)}',
          icon: Icons.add_location_alt_rounded,
          onTap: _captureHere,
        );
      case MeasureMode.auto:
        return _CaptureButton(
          pulse: _pulse,
          label: _recording ? 'Stop recording' : (_pts.isEmpty ? 'Start walking' : 'Resume'),
          icon: _recording ? Icons.stop_rounded : Icons.play_arrow_rounded,
          danger: _recording,
          onTap: () {
            HapticFeedback.mediumImpact();
            setState(() => _recording = !_recording);
            if (_recording) _onLocation();
          },
        );
      case MeasureMode.map:
        return _CaptureButton(
          pulse: _pulse,
          label: 'Add my position',
          icon: Icons.my_location_rounded,
          onTap: _captureHere,
        );
    }
  }
}

class _ModeSwitch extends StatelessWidget {
  final MeasureMode mode;
  final ValueChanged<MeasureMode> onChanged;
  const _ModeSwitch({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    return Glass(
      padding: const EdgeInsets.all(4),
      radius: BorderRadius.circular(16),
      child: Row(
        children: [
          for (final m in MeasureMode.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: mode == m ? c.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(m.icon, size: 16, color: mode == m ? c.onAccent : c.ink),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          m.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: TPText.sans,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: mode == m ? c.onAccent : c.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final AnimationController pulse;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;
  const _CaptureButton({
    required this.pulse,
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    final bg = danger ? c.poor : c.accent;
    final fg = danger ? Colors.white : c.onAccent;
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final t = pulse.value;
        final scale = t == 0 ? 1.0 : 1 - 0.06 * (1 - (2 * t - 1).abs());
        return SizedBox(
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (t > 0 && t < 1)
                Positioned(
                  left: -10 * t,
                  right: -10 * t,
                  top: -10 * t,
                  bottom: -10 * t,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14 + 6 * t),
                        border: Border.all(color: bg.withOpacity(1 - t), width: 3),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(child: Transform.scale(scale: scale, child: child)),
            ],
          ),
        );
      },
      child: SizedBox(
        height: 64,
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: bg, foregroundColor: fg),
          onPressed: onTap,
          icon: Icon(icon, size: 22),
          label: Text(label, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _SquareAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlight;
  const _SquareAction({required this.icon, required this.label, required this.onTap, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    final enabled = onTap != null;
    final color = !enabled ? c.inkDim.withOpacity(0.5) : (highlight ? c.good : c.ink);
    return Material(
      color: c.surface2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontFamily: TPText.sans, fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedCornerBar extends StatelessWidget {
  final String label;
  final LatLng point;
  final double accuracy;
  final VoidCallback onDelete;
  const _SelectedCornerBar({
    required this.label,
    required this.point,
    required this.accuracy,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    final u = Geo.toUtmLL(point);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CornerChip(label: label, color: c.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'E ${Geo.group(u.easting, places: 1)}  N ${Geo.group(u.northing, places: 1)}'
              '${accuracy > 0 ? '  ±${accuracy.toStringAsFixed(1)} m' : ''}',
              style: TPText.reading(12, c.ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded, color: c.poor),
            tooltip: 'Delete corner',
          ),
        ],
      ),
    );
  }
}

class _SaveResult {
  final String name;
  final Project? project;
  final String? newProjectName;
  _SaveResult(this.name, this.project, this.newProjectName);
}

class _SaveSheet extends StatefulWidget {
  final double area;
  const _SaveSheet({required this.area});

  @override
  State<_SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends State<_SaveSheet> {
  final _name = TextEditingController(text: 'Plot ${timeOfDay(DateTime.now())}');
  final _newProject = TextEditingController();
  Project? _project;
  bool _creating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.read(context);
    _project ??= app.projects.where((p) => !p.sample).isNotEmpty
        ? app.projects.firstWhere((p) => !p.sample)
        : null;
    if (_project == null) _creating = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _newProject.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tp;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Save plot', style: TPText.title(c.ink)),
            const SizedBox(height: 4),
            Text(app.formatArea(widget.area), style: TPText.reading(15, c.accent, weight: FontWeight.w700)),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Plot name'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 18),
            const PanelLabel('Project'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in app.projects)
                  ChoiceChip(
                    label: Text(p.name),
                    selected: !_creating && _project == p,
                    avatar: CircleAvatar(backgroundColor: p.color, radius: 6),
                    onSelected: (_) => setState(() {
                      _project = p;
                      _creating = false;
                    }),
                  ),
                ChoiceChip(
                  label: const Text('+ New project'),
                  selected: _creating,
                  onSelected: (_) => setState(() => _creating = true),
                ),
              ],
            ),
            if (_creating) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _newProject,
                decoration: const InputDecoration(labelText: 'New project name'),
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  final name = _name.text.trim().isEmpty ? 'Untitled plot' : _name.text.trim();
                  final np = _newProject.text.trim().isEmpty ? 'My survey' : _newProject.text.trim();
                  Navigator.pop(context, _SaveResult(name, _creating ? null : _project, _creating ? np : null));
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save and view result'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
