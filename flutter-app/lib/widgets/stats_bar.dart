import 'package:flutter/material.dart';
import '../utils/theme.dart';
import 'glass_card.dart';

class StatsBar extends StatelessWidget {
  final String download;
  final String upload;
  final int    ping;
  final bool   isConnected;

  const StatsBar({
    super.key,
    required this.download,
    required this.upload,
    required this.ping,
    required this.isConnected,
  });

  Color get _pingColor {
    if (!isConnected) return AppColors.textMuted;
    if (ping < 40)  return AppColors.connected;
    if (ping < 100) return AppColors.connecting;
    return AppColors.disconnected;
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _StatCell(
            icon: Icons.arrow_downward_rounded,
            label: 'DOWNLOAD',
            value: isConnected ? download : '—',
            color: isConnected ? AppColors.connected : AppColors.textMuted,
          ),
          _Divider(),
          _StatCell(
            icon: Icons.arrow_upward_rounded,
            label: 'UPLOAD',
            value: isConnected ? upload : '—',
            color: isConnected ? AppColors.accent : AppColors.textMuted,
          ),
          _Divider(),
          _StatCell(
            icon: Icons.network_ping_rounded,
            label: 'PING',
            value: isConnected ? '${ping}ms' : '—',
            color: _pingColor,
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;

  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 11),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              value,
              key: ValueKey(value),
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 32, width: 0.8, color: AppColors.glassBorder);
}
