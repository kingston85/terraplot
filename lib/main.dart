import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/app_state.dart';
import 'screens/map_home_screen.dart';
import 'screens/measure_screen.dart';
import 'screens/points_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/tools_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  runApp(TerraPlotApp(state: state));
  state.location.start();
}

class TerraPlotApp extends StatelessWidget {
  final AppState state;
  const TerraPlotApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: Builder(builder: (context) {
        final app = AppScope.of(context);
        final colors = app.sunlight ? TPColors.sunlight : TPColors.field;
        SystemChrome.setSystemUIOverlayStyle(
          app.sunlight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
        );
        return MaterialApp(
          title: 'TerraPlot LR',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(colors),
          home: const AppShell(),
        );
      }),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  static const _pages = <Widget>[
    MapHomeScreen(),
    ProjectsScreen(),
    PointsScreen(),
    ToolsScreen(),
  ];

  void _openMeasure() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MeasureScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: TPBottomBar(
        index: _tab,
        onTab: (i) => setState(() => _tab = i),
        onMeasure: _openMeasure,
      ),
    );
  }
}

/// Bottom bar: four tabs around a raised amber Measure button.
class TPBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTab;
  final VoidCallback onMeasure;
  const TPBottomBar({super.key, required this.index, required this.onTab, required this.onMeasure});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    final bottom = MediaQuery.of(context).padding.bottom;
    return SizedBox(
      height: 76 + bottom + 18,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 76 + bottom,
              padding: EdgeInsets.only(bottom: bottom),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.line)),
              ),
              child: Row(
                children: [
                  _NavItem(icon: Icons.map_rounded, label: 'Map', selected: index == 0, onTap: () => onTab(0)),
                  _NavItem(icon: Icons.folder_rounded, label: 'Projects', selected: index == 1, onTap: () => onTab(1)),
                  const SizedBox(width: 84),
                  _NavItem(icon: Icons.place_rounded, label: 'Points', selected: index == 2, onTap: () => onTab(2)),
                  _NavItem(icon: Icons.handyman_rounded, label: 'Tools', selected: index == 3, onTap: () => onTab(3)),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: bottom + 22,
            child: _MeasureButton(onTap: onMeasure),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    final color = selected ? c.accent : c.inkDim;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? c.accent.withOpacity(0.14) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontFamily: TPText.sans,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                )),
          ],
        ),
      ),
    );
  }
}

class _MeasureButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MeasureButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.tp;
    return Semantics(
      button: true,
      label: 'Measure land',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.accent,
            border: Border.all(color: c.bg, width: 5),
            boxShadow: [
              BoxShadow(color: c.accent.withOpacity(0.45), blurRadius: 18, spreadRadius: 1),
            ],
          ),
          child: Icon(Icons.square_foot_rounded, color: c.onAccent, size: 32),
        ),
      ),
    );
  }
}
