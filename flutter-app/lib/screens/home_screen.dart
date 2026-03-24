import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import 'vpn_screen.dart';
import 'speed_test_screen.dart';
import 'logs_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;

  static const _pages = [VpnScreen(), SpeedTestScreen(), LogsScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _idx, children: _pages),
      bottomNavigationBar: _BottomNav(
        current: _idx,
        onTap: (i) => setState(() => _idx = i)),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int current;
  final Function(int) onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 64 + bottom,
          padding: EdgeInsets.only(bottom: bottom),
          decoration: BoxDecoration(
            color: AppColors.bgDeep.withOpacity(0.9),
            border: const Border(top: BorderSide(color: AppColors.glassBorder, width: 0.5)),
          ),
          child: Row(children: [
            _NavItem(icon: Icons.shield_rounded,  label: 'VPN',      active: current == 0, onTap: () => onTap(0)),
            _NavItem(icon: Icons.speed_rounded,   label: 'Speed',    active: current == 1, onTap: () => onTap(1)),
            _NavItem(icon: Icons.history_rounded, label: 'History',  active: current == 2, onTap: () => onTap(2)),
            _NavItem(icon: Icons.tune_rounded,    label: 'Settings', active: current == 3, onTap: () => onTap(3)),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.textMuted;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: active ? 36 : 0, height: active ? 2.5 : 0,
            margin: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
              boxShadow: active ? [BoxShadow(color: AppColors.accentGlow, blurRadius: 8)] : [],
            ),
          ),
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: color, fontSize: 9,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500, letterSpacing: 0.4)),
        ]),
      ),
    );
  }
}
