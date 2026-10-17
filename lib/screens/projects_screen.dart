import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../core/exporters.dart';
import '../widgets/components.dart';
import '../widgets/export_sheet.dart';
import 'points_screen.dart';
import 'plot_result_screen.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tp;
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
              title: Text('Projects', style: TPText.title(c.ink, size: 22)),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton.filledTonal(
                  onPressed: () => _newProject(context, app),
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'New project',
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Expanded(child: _Summary(label: 'Projects', value: '${app.projects.length}')),
                  const SizedBox(width: 10),
                  Expanded(child: _Summary(label: 'Plots', value: '${app.allPlots.length}')),
                  const SizedBox(width: 10),
                  Expanded(child: _Summary(label: 'Points', value: '${app.allPoints.length}')),
                ],
              ),
            ),
          ),
          if (app.projects.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: EmptyState(
                  icon: Icons.folder_open_rounded,
                  title: 'No projects yet',
                  body: 'Projects keep your plots and points together, like "Caldwell land" or "Stream sampling".',
                  action: FilledButton.icon(
                    onPressed: () => _newProject(context, app),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New project'),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
              sliver: SliverList.separated(
                itemCount: app.projects.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _ProjectCard(project: app.projects[i]),
              ),
            ),
        ],
      ),
    );
  }

  static Future<void> _newProject(BuildContext context, AppState app) async {
    final name = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: desc,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      app.addProject(name.text.trim(), description: desc.text.trim());
    }
  }
}

class _Summary extends StatelessWidget {
  final String label;
  final String value;
  const _Summary({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelLabel(label),
          const SizedBox(height: 4),
          Text(value, style: TPText.reading(22, c.ink, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tp;
    return TPCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: project))),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: project.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(project.name,
                              style: TPText.body(c.ink, size: 16, weight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (project.sample) Tag('SAMPLE', color: c.inkDim),
                      ],
                    ),
                    if (project.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(project.description,
                          style: TPText.body(c.inkDim, size: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.crop_square_rounded, size: 16, color: c.inkDim),
                        const SizedBox(width: 4),
                        Text('${project.plots.length} plots', style: TPText.body(c.inkDim, size: 12.5)),
                        const SizedBox(width: 14),
                        Icon(Icons.place_outlined, size: 16, color: c.inkDim),
                        const SizedBox(width: 4),
                        Text('${project.points.length} points', style: TPText.body(c.inkDim, size: 12.5)),
                        const Spacer(),
                        if (project.totalArea > 0)
                          Text(app.formatArea(project.totalArea),
                              style: TPText.reading(13, c.ink, weight: FontWeight.w700)),
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
}

class ProjectDetailScreen extends StatelessWidget {
  final Project project;
  const ProjectDetailScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tp;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(project.name),
          actions: [
            IconButton(
              tooltip: 'Export and share',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => showExportSheet(context, ExportBundle.project(project)),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'rename') {
                  final ctrl = TextEditingController(text: project.name);
                  final desc = TextEditingController(text: project.description);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Project details'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Name')),
                          const SizedBox(height: 12),
                          TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
                      ],
                    ),
                  );
                  if (ok == true && ctrl.text.trim().isNotEmpty) {
                    app.update(() {
                      project.name = ctrl.text.trim();
                      project.description = desc.text.trim();
                      project.sample = false;
                    });
                  }
                }
                if (v == 'delete') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete project?'),
                      content: Text('"${project.name}" and everything in it will be removed.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    app.deleteProject(project);
                    Navigator.pop(context);
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete project')),
              ],
            ),
          ],
          bottom: TabBar(
            indicatorColor: c.accent,
            labelColor: c.ink,
            unselectedLabelColor: c.inkDim,
            labelStyle: const TextStyle(fontFamily: TPText.sans, fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Plots (${project.plots.length})'),
              Tab(text: 'Points (${project.points.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            project.plots.isEmpty
                ? const Center(
                    child: EmptyState(
                      icon: Icons.square_foot_rounded,
                      title: 'No plots yet',
                      body: 'Tap the amber Measure button to measure a plot and save it here.',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: project.plots.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final plot = project.plots[i];
                      return TPCard(
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => PlotResultScreen(plot: plot))),
                        child: Row(
                          children: [
                            _PlotThumb(plot: plot, color: project.color),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(plot.name,
                                      style: TPText.body(c.ink, size: 15, weight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text('${plot.corners.length} corners · ${shortDate(plot.created)}',
                                      style: TPText.body(c.inkDim, size: 12.5)),
                                ],
                              ),
                            ),
                            Text(app.formatArea(plot.area),
                                style: TPText.reading(13.5, c.ink, weight: FontWeight.w700)),
                          ],
                        ),
                      );
                    },
                  ),
            project.points.isEmpty
                ? const Center(
                    child: EmptyState(
                      icon: Icons.add_location_alt_rounded,
                      title: 'No points yet',
                      body: 'Mark corners, pillars, wells or sampling sites from the Points tab.',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: project.points.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => PointTile(point: project.points[i], color: project.color),
                  ),
          ],
        ),
      ),
    );
  }
}

/// Tiny drawing of a plot's outline, scaled to fit.
class _PlotThumb extends StatelessWidget {
  final Plot plot;
  final Color color;
  const _PlotThumb({required this.plot, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12)),
      child: CustomPaint(painter: _ThumbPainter(plot, color)),
    );
  }
}

class _ThumbPainter extends CustomPainter {
  final Plot plot;
  final Color color;
  _ThumbPainter(this.plot, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (plot.corners.length < 3) return;
    var minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity;
    for (final p in plot.corners) {
      minX = p.longitude < minX ? p.longitude : minX;
      maxX = p.longitude > maxX ? p.longitude : maxX;
      minY = p.latitude < minY ? p.latitude : minY;
      maxY = p.latitude > maxY ? p.latitude : maxY;
    }
    final w = (maxX - minX).abs(), h = (maxY - minY).abs();
    final span = (w > h ? w : h) == 0 ? 1.0 : (w > h ? w : h);
    const pad = 10.0;
    final s = (size.width - 2 * pad) / span;
    final ox = pad + (size.width - 2 * pad - w * s) / 2;
    final oy = pad + (size.height - 2 * pad - h * s) / 2;
    final path = Path();
    for (var i = 0; i < plot.corners.length; i++) {
      final p = plot.corners[i];
      final x = ox + (p.longitude - minX) * s;
      final y = oy + (maxY - p.latitude) * s;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color.withOpacity(0.25));
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _ThumbPainter old) => old.plot != plot || old.color != color;
}
