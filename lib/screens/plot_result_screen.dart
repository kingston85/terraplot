import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

import '../core/geo.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/map_layers.dart';

class PlotResultScreen extends StatelessWidget {
  final Plot plot;
  const PlotResultScreen({super.key, required this.plot});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tp;
    final project = app.projectOfPlot(plot);
    final color = project?.color ?? c.accent;
    final area = plot.area;
    final sigma = plot.areaSigma;
    final top = MediaQuery.of(context).padding.top;
    final accs = plot.cornerAccuracy.where((a) => a > 0).toList();
    final avgAcc = accs.isEmpty ? null : accs.reduce((a, b) => a + b) / accs.length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 300 + top,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCameraFit: CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(plot.corners),
                          padding: EdgeInsets.fromLTRB(48, top + 70, 48, 48),
                        ),
                        maxZoom: 21,
                        backgroundColor: c.bg,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                        ),
                      ),
                      children: [
                        baseTiles(context, app.baseMap),
                        ...plotLayers(context, plot.corners, color: color),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 60,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [c.bg.withOpacity(0), c.bg],
                          ),
                        ),
                      ),
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
                          tooltip: 'Delete plot',
                          onTap: () => _delete(context, app),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    if (project != null) Tag(project.name, color: color, icon: Icons.folder_rounded),
                    const SizedBox(width: 8),
                    Tag(plot.method.label, color: c.inkDim, icon: plot.method.icon),
                  ],
                ),
                const SizedBox(height: 12),
                Text(plot.name, style: TPText.title(c.ink, size: 26)),
                const SizedBox(height: 4),
                Text('Measured ${shortDate(plot.created)} at ${timeOfDay(plot.created)}',
                    style: TPText.body(c.inkDim, size: 13)),
                const SizedBox(height: 20),

                // Hero area
                TPCard(
                  padding: const EdgeInsets.all(20),
                  borderColor: color.withOpacity(0.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PanelLabel('Area'),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(Geo.group(area, places: 1),
                                style: TPText.reading(44, c.ink, weight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            Text('m²', style: TPText.body(color, size: 20, weight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      if (sigma > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Likely range ${Geo.group(area - 2 * sigma, places: 0)} – ${Geo.group(area + 2 * sigma, places: 0)} m² (95%)',
                            style: TPText.reading(12, c.inkDim),
                          ),
                        ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final u in [AreaUnit.hectare, AreaUnit.acre, AreaUnit.sqft, AreaUnit.lot])
                            _UnitTile(
                              label: u.longName,
                              value: Geo.group(u.convert(area, lotSqm: app.lotSqm), places: u.places),
                              unit: u.label,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Perimeter',
                        value: Geo.metres(plot.perimeter),
                        sub: Geo.feet(plot.perimeter),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Corners',
                        value: '${plot.corners.length}',
                        sub: avgAcc == null ? 'from map' : 'avg ±${avgAcc.toStringAsFixed(1)} m',
                      ),
                    ),
                  ],
                ),

                const SectionHeader('Field sheet'),
                _FieldSheet(plot: plot, color: color),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'UTM Zone 29N, WGS84. Bearings from grid north. Lengths and area are ground values.',
                    style: TPText.body(c.inkDim, size: 12),
                  ),
                ),

                if (plot.note.isNotEmpty) ...[
                  const SectionHeader('Notes'),
                  TPCard(child: Text(plot.note, style: TPText.body(c.ink))),
                ],

                const SectionHeader('Export and share'),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final f in const [
                      ['PDF report', Icons.picture_as_pdf_rounded],
                      ['KML', Icons.public_rounded],
                      ['GPX', Icons.route_rounded],
                      ['CSV', Icons.table_chart_rounded],
                      ['GeoJSON', Icons.data_object_rounded],
                    ])
                      _ExportChip(
                        label: f[0] as String,
                        icon: f[1] as IconData,
                        onTap: () => showComingSoon(context, '${f[0]} export', 'phase 5'),
                      ),
                    _ExportChip(
                      label: 'Copy coordinates',
                      icon: Icons.copy_rounded,
                      onTap: () {
                        final buf = StringBuffer('Corner,Latitude,Longitude,Easting,Northing\n');
                        for (var i = 0; i < plot.corners.length; i++) {
                          final p = plot.corners[i];
                          final u = Geo.toUtmLL(p);
                          buf.writeln('${cornerLabel(i)},${p.latitude.toStringAsFixed(7)},'
                              '${p.longitude.toStringAsFixed(7)},${u.easting.toStringAsFixed(2)},'
                              '${u.northing.toStringAsFixed(2)}');
                        }
                        Clipboard.setData(ClipboardData(text: buf.toString()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Corner coordinates copied as CSV.')),
                        );
                      },
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, AppState app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this plot?'),
        content: Text('"${plot.name}" will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      app.deletePlot(plot);
      Navigator.pop(context);
    }
  }
}

class _UnitTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _UnitTile({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    return Container(
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelLabel(label),
          const SizedBox(height: 4),
          Text('$value $unit', style: TPText.reading(14.5, c.ink, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  const _StatCard({required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    return TPCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelLabel(label),
          const SizedBox(height: 6),
          Text(value, style: TPText.reading(20, c.ink, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(sub, style: TPText.reading(12, c.inkDim)),
        ],
      ),
    );
  }
}

class _FieldSheet extends StatelessWidget {
  final Plot plot;
  final Color color;
  const _FieldSheet({required this.plot, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    final n = plot.corners.length;
    TextStyle head() => TPText.label(c.inkDim, size: 10);
    TextStyle cell() => TPText.reading(12.5, c.ink);
    Widget pad(Widget w, {bool right = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Align(alignment: right ? Alignment.centerRight : Alignment.centerLeft, child: w),
        );
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(color: c.surface2),
              children: [
                pad(Text('PT', style: head())),
                pad(Text('EASTING', style: head()), right: true),
                pad(Text('NORTHING', style: head()), right: true),
                pad(Text('SIDE', style: head())),
                pad(Text('LENGTH', style: head()), right: true),
                pad(Text('BEARING', style: head()), right: true),
                pad(Text('±M', style: head()), right: true),
              ],
            ),
            for (var i = 0; i < n; i++)
              () {
                final p = plot.corners[i];
                final q = plot.corners[(i + 1) % n];
                final u = Geo.toUtmLL(p);
                final acc = i < plot.cornerAccuracy.length ? plot.cornerAccuracy[i] : 0.0;
                return TableRow(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.line.withOpacity(0.6))),
                  ),
                  children: [
                    pad(CornerChip(label: cornerLabel(i), color: color)),
                    pad(Text(Geo.group(u.easting, places: 2), style: cell()), right: true),
                    pad(Text(Geo.group(u.northing, places: 2), style: cell()), right: true),
                    pad(Text('${cornerLabel(i)}→${cornerLabel((i + 1) % n)}', style: cell())),
                    pad(Text(Geo.distance(p, q).toStringAsFixed(2), style: cell()), right: true),
                    pad(Text('${Geo.bearing(p, q).toStringAsFixed(1)}°', style: cell()), right: true),
                    pad(
                      Text(acc > 0 ? acc.toStringAsFixed(1) : '—',
                          style: TPText.reading(12.5, c.accuracyColor(acc > 0 ? acc : null))),
                      right: true,
                    ),
                  ],
                );
              }(),
          ],
        ),
      ),
    );
  }
}

class _ExportChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ExportChip({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: c.accent),
              const SizedBox(width: 8),
              Text(label, style: TPText.body(c.ink, size: 13.5, weight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
