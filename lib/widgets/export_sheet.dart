import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/exporters.dart';
import '../core/pdf_report.dart';
import '../data/app_state.dart';
import '../data/storage.dart';
import '../theme/app_theme.dart';
import 'components.dart';

/// Writes the bundle in [format] to a temporary file and opens the share sheet.
Future<void> shareExport(BuildContext context, ExportFormat format, ExportBundle bundle) async {
  final app = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${Exporters.safeFileName(bundle.title)}.${format.fileExt}');
    if (format == ExportFormat.pdf) {
      final bytes = await PdfReport.build(bundle, surveyor: app.surveyorName, lotSqm: app.lotSqm);
      await file.writeAsBytes(bytes, flush: true);
    } else {
      await file.writeAsString(Exporters.text(format, bundle, lotSqm: app.lotSqm), flush: true);
    }
    await Share.shareXFiles(
      [XFile(file.path, mimeType: format.mime)],
      subject: '${bundle.title} — TerraPlot LR',
      text: '${bundle.title} (${format.label}) from TerraPlot LR',
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not export: $e')));
  }
}

/// Shares a full backup of all data as JSON.
Future<void> shareBackup(BuildContext context) async {
  final app = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await app.saveNow();
    final f = await Storage.file();
    final dir = await getTemporaryDirectory();
    final d = DateTime.now();
    final name = 'TerraPlot_backup_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.json';
    final copy = await f.copy('${dir.path}/$name');
    await Share.shareXFiles([XFile(copy.path, mimeType: 'application/json')],
        subject: 'TerraPlot LR backup', text: 'TerraPlot LR backup of all projects');
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not create backup: $e')));
  }
}

/// Bottom sheet listing export formats for a plot or project.
Future<void> showExportSheet(BuildContext context, ExportBundle bundle) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ExportSheet(bundle: bundle),
  );
}

class _ExportSheet extends StatefulWidget {
  final ExportBundle bundle;
  const _ExportSheet({required this.bundle});

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  ExportFormat? _busy;

  IconData _icon(ExportFormat f) {
    switch (f) {
      case ExportFormat.pdf:
        return Icons.picture_as_pdf_rounded;
      case ExportFormat.kml:
        return Icons.public_rounded;
      case ExportFormat.gpx:
        return Icons.route_rounded;
      case ExportFormat.csv:
        return Icons.table_chart_rounded;
      case ExportFormat.geojson:
        return Icons.data_object_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    final b = widget.bundle;
    final hasPlots = b.plots.any((p) => p.corners.length >= 3);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export and share', style: TPText.title(c.ink)),
            const SizedBox(height: 4),
            Text(
              '${b.title} · ${b.plots.length} plot${b.plots.length == 1 ? '' : 's'}, '
              '${b.points.length} point${b.points.length == 1 ? '' : 's'}',
              style: TPText.body(c.inkDim, size: 13),
            ),
            const SizedBox(height: 14),
            for (final f in ExportFormat.values)
              if (f != ExportFormat.pdf || hasPlots || b.points.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TPCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    onTap: _busy != null
                        ? null
                        : () async {
                            setState(() => _busy = f);
                            await shareExport(context, f, b);
                            if (mounted) setState(() => _busy = null);
                          },
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_icon(f), color: c.accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.label, style: TPText.body(c.ink, size: 15, weight: FontWeight.w700)),
                              Text(f.description, style: TPText.body(c.inkDim, size: 12.5)),
                            ],
                          ),
                        ),
                        if (_busy == f)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: c.accent),
                          )
                        else
                          Icon(Icons.ios_share_rounded, color: c.inkDim, size: 20),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 4),
            const PanelLabel('Share opens WhatsApp, email, Drive or Bluetooth'),
          ],
        ),
      ),
    );
  }
}
