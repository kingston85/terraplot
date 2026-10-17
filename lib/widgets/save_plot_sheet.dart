import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import 'components.dart';

/// Asks for a plot name and project. Returns null if cancelled.
Future<SavePlotResult?> showSavePlotSheet(BuildContext context, double area) {
  return showModalBottomSheet<SavePlotResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SavePlotSheet(area: area),
  );
}

/// Saves a new plot from the sheet's answers and returns it.
Plot savePlotFromResult(AppState app, SavePlotResult r, Plot plot) {
  final project = r.project ?? app.addProject(r.newProjectName ?? 'My survey');
  plot.name = r.name;
  app.addPlot(project, plot);
  return plot;
}

class SavePlotResult {
  final String name;
  final Project? project;
  final String? newProjectName;
  SavePlotResult(this.name, this.project, this.newProjectName);
}

class SavePlotSheet extends StatefulWidget {
  final double area;
  const SavePlotSheet({super.key, required this.area});

  @override
  State<SavePlotSheet> createState() => _SavePlotSheetState();
}

class _SavePlotSheetState extends State<SavePlotSheet> {
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
                  Navigator.pop(context, SavePlotResult(name, _creating ? null : _project, _creating ? np : null));
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
