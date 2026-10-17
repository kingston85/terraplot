import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../core/geo.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import 'point_detail_screen.dart';

class PointsScreen extends StatefulWidget {
  const PointsScreen({super.key});

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
  PointType? _filter;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tp;
    final entries = <MapEntry<SurveyPoint, Project>>[
      for (final pr in app.projects)
        for (final pt in pr.points)
          if (_filter == null || pt.type == _filter) MapEntry(pt, pr),
    ]..sort((a, b) => b.key.time.compareTo(a.key.time));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: c.bg,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 14),
              title: Text('Points', style: TPText.title(c.ink, size: 22)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: _MarkPointHero(onTap: () => showMarkPointSheet(context)),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                children: [
                  _FilterChip(label: 'All', selected: _filter == null, onTap: () => setState(() => _filter = null)),
                  for (final t in PointType.values)
                    _FilterChip(
                      label: t.label,
                      icon: t.icon,
                      selected: _filter == t,
                      onTap: () => setState(() => _filter = _filter == t ? null : t),
                    ),
                ],
              ),
            ),
          ),
          if (entries.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: EmptyState(
                  icon: Icons.add_location_alt_rounded,
                  title: 'No points here',
                  body: 'Mark a corner, pillar, well or sampling site with an averaged GPS position.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
              sliver: SliverList.separated(
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) =>
                    PointTile(point: entries[i].key, color: entries[i].value.color, project: entries[i].value),
              ),
            ),
        ],
      ),
    );
  }
}

class _MarkPointHero extends StatelessWidget {
  final VoidCallback onTap;
  const _MarkPointHero({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    return Material(
      color: c.accent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: c.onAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.add_location_alt_rounded, color: c.onAccent, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mark a point',
                        style: TextStyle(
                            fontFamily: TPText.sans, fontSize: 17, fontWeight: FontWeight.w800, color: c.onAccent)),
                    const SizedBox(height: 2),
                    Text('Averaged GPS for a steadier position',
                        style: TextStyle(fontFamily: TPText.sans, fontSize: 13, color: c.onAccent.withOpacity(0.8))),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: c.onAccent),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.accent.withOpacity(0.16) : c.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? c.accent : c.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: selected ? c.accent : c.inkDim),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TPText.body(selected ? c.ink : c.inkDim, size: 13, weight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// List row for a saved point.
class PointTile extends StatelessWidget {
  final SurveyPoint point;
  final Color color;
  final Project? project;
  const PointTile({super.key, required this.point, required this.color, this.project});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    return TPCard(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => PointDetailScreen(point: point))),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(point.type.icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(point.name,
                    style: TPText.body(c.ink, size: 15, weight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${point.type.label}${project != null ? ' · ${project!.name}' : ''}',
                  style: TPText.body(c.inkDim, size: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('±${point.accuracy.toStringAsFixed(1)} m',
                  style: TPText.reading(12.5, c.accuracyColor(point.accuracy), weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(point.readings > 1 ? '${point.readings} readings' : '1 reading',
                  style: TPText.body(c.inkDim, size: 11.5)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mark point sheet with GPS averaging
// ---------------------------------------------------------------------------

Future<void> showMarkPointSheet(BuildContext context, {PointType type = PointType.pillar}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MarkPointSheet(initialType: type),
  );
}

class _MarkPointSheet extends StatefulWidget {
  final PointType initialType;
  const _MarkPointSheet({required this.initialType});

  @override
  State<_MarkPointSheet> createState() => _MarkPointSheetState();
}

class _MarkPointSheetState extends State<_MarkPointSheet> with SingleTickerProviderStateMixin {
  final _name = TextEditingController();
  final _note = TextEditingController();
  late PointType _type = widget.initialType;
  int _seconds = 60;
  bool _averaging = false;
  final List<LatLng> _samples = [];
  final List<double> _sigmas = [];
  final List<double> _alts = [];
  DateTime? _started;
  Timer? _timer;
  Project? _project;
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
    _project ??= app.projects.isEmpty ? null : app.projects.first;
    if (_name.text.isEmpty) _name.text = '${_type.label} ${app.allPoints.length + 1}';
  }

  @override
  void dispose() {
    _app?.location.removeListener(_onLocation);
    _timer?.cancel();
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _onLocation() {
    if (!_averaging) {
      if (mounted) setState(() {});
      return;
    }
    final loc = _app!.location;
    final p = loc.latLng;
    if (p == null || !loc.hasFix) return;
    _samples.add(p);
    _sigmas.add(loc.accuracy ?? 10);
    _alts.add(loc.position?.altitude ?? 0);
    if (mounted) setState(() {});
  }

  void _start() {
    HapticFeedback.mediumImpact();
    setState(() {
      _averaging = true;
      _samples.clear();
      _sigmas.clear();
      _alts.clear();
      _started = DateTime.now();
    });
    _onLocation();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(_started!).inMilliseconds / 1000;
      if (elapsed >= _seconds) {
        t.cancel();
        setState(() => _averaging = false);
        HapticFeedback.heavyImpact();
      } else {
        setState(() {});
      }
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() => _averaging = false);
  }

  double get _progress {
    if (_started == null) return 0;
    final e = DateTime.now().difference(_started!).inMilliseconds / 1000;
    return (e / _seconds).clamp(0.0, 1.0);
  }

  void _save({bool single = false}) {
    final app = AppScope.read(context);
    LatLng pos;
    double acc;
    double alt;
    int n;
    if (!single && _samples.isNotEmpty) {
      pos = Geo.weightedMean(_samples, _sigmas);
      acc = Geo.averagedAccuracy(_sigmas);
      alt = _alts.reduce((a, b) => a + b) / _alts.length;
      n = _samples.length;
    } else {
      final loc = app.location;
      if (!loc.hasFix) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.statusText)));
        return;
      }
      pos = loc.latLng!;
      acc = loc.accuracy ?? 0;
      alt = loc.position?.altitude ?? 0;
      n = 1;
    }
    final project = _project ?? app.ensureProject();
    app.addPoint(
      project,
      SurveyPoint(
        id: newId(),
        name: _name.text.trim().isEmpty ? _type.label : _name.text.trim(),
        type: _type,
        lat: pos.latitude,
        lon: pos.longitude,
        accuracy: acc,
        altitude: alt,
        readings: n,
        note: _note.text.trim(),
      ),
    );
    HapticFeedback.heavyImpact();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Saved to ${project.name} · ±${acc.toStringAsFixed(1)} m')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tp;
    final done = !_averaging && _samples.isNotEmpty;
    final liveAcc = _sigmas.isEmpty ? app.location.accuracy : Geo.averagedAccuracy(_sigmas);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Mark point', style: TPText.title(c.ink))),
                  const AccuracyPill(compact: true),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: _AveragingRing(
                  progress: _progress,
                  active: _averaging,
                  done: done,
                  accuracy: liveAcc,
                  samples: _samples.length,
                  limit: app.accuracyLimit,
                ),
              ),
              const SizedBox(height: 18),
              if (!_averaging && !done) ...[
                const PanelLabel('Averaging time'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final s in const [30, 60, 120]) ...[
                      Expanded(
                        child: ChoiceChip(
                          label: Text('$s s'),
                          selected: _seconds == s,
                          onSelected: (_) => setState(() => _seconds = s),
                        ),
                      ),
                      if (s != 120) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
              ],
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final t in PointType.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(t.icon, size: 16),
                          label: Text(t.label),
                          selected: _type == t,
                          onSelected: (_) => setState(() => _type = t),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (app.projects.isNotEmpty)
                DropdownButtonFormField<Project>(
                  value: _project,
                  decoration: const InputDecoration(labelText: 'Project'),
                  items: [
                    for (final p in app.projects)
                      DropdownMenuItem(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (p) => setState(() => _project = p),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 18),
              if (_averaging)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Stop averaging'),
                  ),
                )
              else if (done)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: _start, child: const Text('Redo')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save point'),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _save(single: true),
                        child: const Text('Quick save'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: app.location.hasFix ? _start : null,
                        icon: const Icon(Icons.timer_outlined),
                        label: Text('Average $_seconds s'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AveragingRing extends StatelessWidget {
  final double progress;
  final bool active;
  final bool done;
  final double? accuracy;
  final int samples;
  final double limit;
  const _AveragingRing({
    required this.progress,
    required this.active,
    required this.done,
    required this.accuracy,
    required this.samples,
    required this.limit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    final color = c.accuracyColor(accuracy, limit: limit);
    return SizedBox(
      width: 190,
      height: 190,
      child: CustomPaint(
        painter: _RingPainter(
          progress: active || done ? progress : 0,
          color: done ? c.good : c.accent,
          track: c.surface2,
          inner: color,
          innerScale: accuracy == null ? 0.6 : (accuracy! / 20).clamp(0.12, 0.6).toDouble(),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                accuracy == null ? '—' : '±${accuracy!.toStringAsFixed(accuracy! < 10 ? 2 : 1)}',
                style: TPText.reading(28, c.ink, weight: FontWeight.w700),
              ),
              Text('metres', style: TPText.body(c.inkDim, size: 12)),
              const SizedBox(height: 6),
              PanelLabel(done
                  ? '$samples readings · done'
                  : active
                      ? '$samples readings'
                      : 'live accuracy'),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  final Color inner;
  final double innerScale;
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.inner,
    required this.innerScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round,
      );
    }
    // Inner disc shrinks as accuracy improves.
    canvas.drawCircle(center, r * innerScale * 1.4, Paint()..color = inner.withOpacity(0.10));
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color || old.inner != inner || old.innerScale != innerScale;
}
