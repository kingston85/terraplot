import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../core/geo.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import 'settings_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    final tools = <_Tool>[
      _Tool(
        icon: Icons.swap_horiz_rounded,
        title: 'Coordinate converter',
        body: 'Lat/long ⇄ UTM Zone 29N, decimal ⇄ DMS',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConverterScreen())),
      ),
      _Tool(
        icon: Icons.download_for_offline_outlined,
        title: 'Offline maps',
        body: 'Download a town or county to use with no data',
        badge: 'Phase 2',
        onTap: () => showComingSoon(context, 'Offline map downloads', 'phase 2'),
      ),
      _Tool(
        icon: Icons.file_open_outlined,
        title: 'Import files',
        body: 'KML, GPX and CSV from other apps and surveyors',
        badge: 'Phase 5',
        onTap: () => showComingSoon(context, 'File import', 'phase 5'),
      ),
      _Tool(
        icon: Icons.settings_rounded,
        title: 'Settings',
        body: 'Units, lot size, accuracy limit, display',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
      ),
    ];
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
              title: Text('Tools', style: TPText.title(c.ink, size: 22)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
            sliver: SliverList.separated(
              itemCount: tools.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _ToolCard(tool: tools[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tool {
  final IconData icon;
  final String title;
  final String body;
  final String? badge;
  final VoidCallback onTap;
  _Tool({required this.icon, required this.title, required this.body, required this.onTap, this.badge});
}

class _ToolCard extends StatelessWidget {
  final _Tool tool;
  const _ToolCard({required this.tool});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    return TPCard(
      onTap: tool.onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: c.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(tool.icon, color: c.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(tool.title, style: TPText.body(c.ink, size: 15.5, weight: FontWeight.w700)),
                    ),
                    if (tool.badge != null) ...[
                      const SizedBox(width: 8),
                      Tag(tool.badge!, color: c.inkDim),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(tool.body, style: TPText.body(c.inkDim, size: 13)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.inkDim),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Coordinate converter
// ---------------------------------------------------------------------------

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  bool _fromLatLon = true;
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  final _e = TextEditingController();
  final _n = TextEditingController();

  @override
  void dispose() {
    _lat.dispose();
    _lon.dispose();
    _e.dispose();
    _n.dispose();
    super.dispose();
  }

  LatLng? get _result {
    if (_fromLatLon) {
      final la = Geo.parseAngle(_lat.text);
      final lo = Geo.parseAngle(_lon.text);
      if (la == null || lo == null || la.abs() > 90 || lo.abs() > 180) return null;
      return LatLng(la, lo);
    }
    final e = double.tryParse(_e.text.replaceAll(',', '').trim());
    final n = double.tryParse(_n.text.replaceAll(',', '').trim());
    if (e == null || n == null || e < 100000 || e > 900000 || n < 0 || n > 10000000) return null;
    return Geo.fromUtm(e, n);
  }

  void _useMyLocation() {
    final p = AppScope.read(context).location.latLng;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No GPS fix yet.')));
      return;
    }
    setState(() {
      if (_fromLatLon) {
        _lat.text = p.latitude.toStringAsFixed(7);
        _lon.text = p.longitude.toStringAsFixed(7);
      } else {
        final u = Geo.toUtmLL(p);
        _e.text = u.easting.toStringAsFixed(2);
        _n.text = u.northing.toStringAsFixed(2);
      }
    });
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Copied $text')));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    final r = _result;
    final u = r == null ? null : Geo.toUtmLL(r);
    final outsideZone = r != null && Geo.zoneFor(r.longitude) != Geo.liberiaZone;

    return Scaffold(
      appBar: AppBar(title: const Text('Coordinate converter')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                _Seg(label: 'Lat/Long → UTM', selected: _fromLatLon, onTap: () => setState(() => _fromLatLon = true)),
                _Seg(label: 'UTM → Lat/Long', selected: !_fromLatLon, onTap: () => setState(() => _fromLatLon = false)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_fromLatLon) ...[
            TextField(
              controller: _lat,
              onChanged: (_) => setState(() {}),
              style: TPText.reading(16, c.ink),
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(labelText: 'Latitude', hintText: '6.3156 or 6 18 56.2 N'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lon,
              onChanged: (_) => setState(() {}),
              style: TPText.reading(16, c.ink),
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(labelText: 'Longitude', hintText: '-10.8074 or 10 48 26.6 W'),
            ),
          ] else ...[
            TextField(
              controller: _e,
              onChanged: (_) => setState(() {}),
              style: TPText.reading(16, c.ink),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Easting (m)', hintText: '300061.54', suffixText: '29N'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _n,
              onChanged: (_) => setState(() {}),
              style: TPText.reading(16, c.ink),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Northing (m)', hintText: '698438.87'),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _useMyLocation,
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: const Text('Use my location'),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: r == null
                ? TPCard(
                    key: const ValueKey('empty'),
                    child: Text(
                      'Enter coordinates above. Latitude and longitude accept decimal degrees or degrees-minutes-seconds; '
                      'west and south are negative.',
                      style: TPText.body(c.inkDim, size: 13),
                    ),
                  )
                : TPCard(
                    key: const ValueKey('result'),
                    borderColor: c.accent.withOpacity(0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Out(label: 'Easting · UTM ${u!.zoneLabel}', value: '${u!.easting.toStringAsFixed(2)} m', onCopy: _copy),
                        _Out(label: 'Northing', value: '${u!.northing.toStringAsFixed(2)} m', onCopy: _copy),
                        const Divider(height: 24),
                        _Out(label: 'Latitude (decimal)', value: r.latitude.toStringAsFixed(7), onCopy: _copy),
                        _Out(label: 'Longitude (decimal)', value: r.longitude.toStringAsFixed(7), onCopy: _copy),
                        const Divider(height: 24),
                        _Out(label: 'Latitude (DMS)', value: Geo.dms(r.latitude, isLat: true), onCopy: _copy),
                        _Out(label: 'Longitude (DMS)', value: Geo.dms(r.longitude, isLat: false), onCopy: _copy),
                      ],
                    ),
                  ),
          ),
          if (outsideZone) ...[
            const SizedBox(height: 12),
            Text(
              'This point is outside UTM Zone 29 (Liberia). The result is still computed in Zone 29 for consistency.',
              style: TPText.body(c.fair, size: 12.5),
            ),
          ],
          const SizedBox(height: 16),
          Text('Datum: WGS84 (EPSG:32629). Accuracy of the conversion is better than 1 mm.',
              style: TPText.body(c.inkDim, size: 12)),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Seg({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? c.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                fontFamily: TPText.sans,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? c.onAccent : c.ink,
              )),
        ),
      ),
    );
  }
}

class _Out extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onCopy;
  const _Out({required this.label, required this.value, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    return InkWell(
      onTap: () => onCopy(value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PanelLabel(label),
                  const SizedBox(height: 3),
                  Text(value, style: TPText.reading(16, c.ink, weight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.copy_rounded, size: 16, color: c.inkDim),
          ],
        ),
      ),
    );
  }
}
