import 'package:flutter/material.dart';

import '../core/geo.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/export_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.tp;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          const SectionHeader('Display'),
          TPCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  value: app.sunlight,
                  onChanged: (v) => app.update(() => app.sunlight = v),
                  title: Text('Sunlight mode', style: TPText.body(c.ink, weight: FontWeight.w600)),
                  subtitle: Text('High-contrast light theme for bright sun',
                      style: TPText.body(c.inkDim, size: 12.5)),
                  secondary: Icon(Icons.wb_sunny_outlined, color: c.accent),
                ),
                Divider(color: c.line, height: 1),
                SwitchListTile(
                  value: app.motion,
                  onChanged: (v) => app.update(() => app.motion = v),
                  title: Text('Animations', style: TPText.body(c.ink, weight: FontWeight.w600)),
                  subtitle: Text('Rolling numbers and capture effects',
                      style: TPText.body(c.inkDim, size: 12.5)),
                  secondary: Icon(Icons.animation_rounded, color: c.accent),
                ),
              ],
            ),
          ),

          const SectionHeader('Units'),
          TPCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PanelLabel('Default area unit'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final u in AreaUnit.values)
                      ChoiceChip(
                        label: Text(u.longName),
                        selected: app.areaUnit == u,
                        onSelected: (_) => app.update(() => app.areaUnit = u),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(child: PanelLabel('Size of one Liberian lot')),
                    Text('${app.lotSqm.toStringAsFixed(1)} m²',
                        style: TPText.reading(14, c.ink, weight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${(app.lotSqm / 4046.8564224).toStringAsFixed(3)} acre · ${Geo.group(app.lotSqm / 0.09290304)} ft²',
                  style: TPText.reading(12, c.inkDim),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _LotChip(label: '¼ acre', sqm: 4046.8564224 / 4),
                    _LotChip(label: '100 × 100 ft', sqm: 100 * 100 * 0.09290304),
                    _LotChip(label: '1,000 m²', sqm: 1000),
                    ActionChip(
                      label: const Text('Custom…'),
                      onPressed: () => _customLot(context, app),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SectionHeader('GPS'),
          TPCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: PanelLabel('Accuracy limit for corners')),
                    Text('${app.accuracyLimit.toStringAsFixed(0)} m',
                        style: TPText.reading(14, c.ink, weight: FontWeight.w700)),
                  ],
                ),
                Slider(
                  value: app.accuracyLimit,
                  min: 3,
                  max: 25,
                  divisions: 22,
                  label: '${app.accuracyLimit.toStringAsFixed(0)} m',
                  onChanged: (v) => app.update(() => app.accuracyLimit = v),
                ),
                Text(
                  'Corners worse than this ask before saving. Auto-walk skips them. '
                  'Green under 5 m, amber up to the limit, red above it.',
                  style: TPText.body(c.inkDim, size: 12.5),
                ),
                const SizedBox(height: 18),
                const PanelLabel('Coordinate display'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in CoordFormat.values)
                      ChoiceChip(
                        label: Text(_fmt(f)),
                        selected: app.coordFormat == f,
                        onSelected: (_) => app.update(() => app.coordFormat = f),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SectionHeader('Reports'),
          TPCard(
            child: TextFormField(
              initialValue: app.surveyorName,
              onChanged: (v) => app.update(() => app.surveyorName = v),
              decoration: const InputDecoration(
                labelText: 'Surveyor name',
                hintText: 'Printed on PDF site reports',
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ),

          const SectionHeader('Data'),
          TPCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.backup_outlined, color: c.accent),
              title: Text('Back up all data', style: TPText.body(c.ink, weight: FontWeight.w600)),
              subtitle: Text('Share every project as one file (send it to yourself or Drive)',
                  style: TPText.body(c.inkDim, size: 12.5)),
              trailing: Icon(Icons.ios_share_rounded, color: c.inkDim),
              onTap: () => shareBackup(context),
            ),
          ),
          const SizedBox(height: 8),
          Text('Everything is saved on this phone automatically.', style: TPText.body(c.inkDim, size: 12)),

          const SectionHeader('About'),
          TPCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TerraPlot LR · version 0.2', style: TPText.body(c.ink, weight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Phone GPS is usually accurate to about 3–5 m under open sky, and worse under trees or near buildings. '
                  'Results are for planning, checking and recording. Legal boundary surveys need a licensed surveyor.',
                  style: TPText.body(c.inkDim, size: 13),
                ),
                const SizedBox(height: 8),
                Text('Maps © OpenStreetMap contributors. Imagery © Esri.',
                    style: TPText.body(c.inkDim, size: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(CoordFormat f) {
    switch (f) {
      case CoordFormat.decimal:
        return 'Decimal degrees';
      case CoordFormat.dms:
        return 'Deg-min-sec';
      case CoordFormat.utm:
        return 'UTM 29N';
    }
  }

  static Future<void> _customLot(BuildContext context, AppState app) async {
    final ctrl = TextEditingController(text: app.lotSqm.toStringAsFixed(1));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lot size'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Square metres', suffixText: 'm²'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    final v = double.tryParse(ctrl.text.trim());
    if (ok == true && v != null && v > 0) app.update(() => app.lotSqm = v);
  }
}

class _LotChip extends StatelessWidget {
  final String label;
  final double sqm;
  const _LotChip({required this.label, required this.sqm});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: (app.lotSqm - sqm).abs() < 0.05,
      onSelected: (_) => app.update(() => app.lotSqm = sqm),
    );
  }
}
