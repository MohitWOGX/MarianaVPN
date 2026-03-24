import 'package:flutter/material.dart';
import '../models/vpn_server.dart';
import '../utils/theme.dart';
import 'glass_card.dart';

class ServerSelector extends StatelessWidget {
  final VpnServer selected;
  final Function(VpnServer) onSelect;
  const ServerSelector({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () => _showSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Text(selected.flagEmoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SERVER LOCATION', style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                const SizedBox(height: 3),
                Text(selected.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: Text('${selected.ping}ms', style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 22),
          ],
        ),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: AppColors.glassBorder)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 38, height: 4, decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(children: [
                const Text('Choose Server', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${VpnServer.servers.length} locations', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 14),
            ...VpnServer.servers.map((s) => _ServerTile(
              server: s,
              isSelected: s.name == selected.name,
              onTap: () { onSelect(s); Navigator.pop(context); },
            )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  final VpnServer server;
  final bool isSelected;
  final VoidCallback onTap;
  const _ServerTile({required this.server, required this.isSelected, required this.onTap});

  Color get _pingColor => server.ping < 30 ? AppColors.connected : server.ping < 80 ? AppColors.connecting : AppColors.disconnected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.accent.withOpacity(0.4) : AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Text(server.flagEmoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(server.name,    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              Text(server.country, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ])),
            // Ping dot
            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _pingColor, boxShadow: [BoxShadow(color: _pingColor.withOpacity(0.6), blurRadius: 6)])),
            const SizedBox(width: 8),
            Text('${server.ping}ms', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 20)
            else
              const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }
}
