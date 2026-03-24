import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vpn_provider.dart';
import '../utils/theme.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        Positioned(top: -50, right: -60, child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withOpacity(0.04)))),
        SafeArea(child: Consumer<VpnProvider>(builder: (context, vpn, _) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Settings', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),

            // Profile card
            GlassCard(
              borderColor: AppColors.accent.withOpacity(0.18),
              child: Row(children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(gradient: AppColors.accentGradient, borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: AppColors.accentGlow, blurRadius: 10)]),
                  child: ClipRRect(borderRadius: BorderRadius.circular(14),
                    child: Image.asset('assets/images/icon.png', fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: Colors.white, size: 26)))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('MohitW', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                  const Text('MarianaVPN • Personal', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(gradient: AppColors.accentGradient, borderRadius: BorderRadius.circular(7)),
                  child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1))),
              ]),
            ),
            const SizedBox(height: 22),

            _label('SECURITY'),
            const SizedBox(height: 8),
            GlassCard(padding: EdgeInsets.zero, child: Column(children: [
              _Toggle(icon: Icons.block_rounded,  color: AppColors.disconnected, title: 'Kill Switch',         sub: 'Block traffic if VPN drops',    value: vpn.killSwitch, onChanged: vpn.setKillSwitch),
              _Div(),
              _Toggle(icon: Icons.dns_rounded,    color: AppColors.accent,       title: 'DNS Leak Protection', sub: 'Force DNS through VPN',          value: vpn.dnsLeak,    onChanged: vpn.setDnsLeak),
            ])),
            const SizedBox(height: 22),

            _label('CONNECTION'),
            const SizedBox(height: 8),
            GlassCard(padding: EdgeInsets.zero, child: Column(children: [
              _Toggle(icon: Icons.autorenew_rounded, color: AppColors.connected, title: 'Auto-Reconnect', sub: 'Reconnect if connection drops', value: vpn.autoReconnect, onChanged: vpn.setAutoReconnect),
              _Div(),
              _ProtocolRow(current: vpn.protocol, onSelect: (p) { vpn.setProtocol(p); Navigator.pop(context); }),
            ])),
            const SizedBox(height: 22),

            _label('SERVERS'),
            const SizedBox(height: 8),
            GlassCard(padding: EdgeInsets.zero, child: Column(children: [
              _InfoRow(icon: Icons.location_on_rounded, color: const Color(0xFFFF6B6B), title: 'Mumbai',    sub: 'India • 43.205.242.165 • 12ms', trailing: '🇮🇳'),
              _Div(),
              _InfoRow(icon: Icons.location_on_rounded, color: const Color(0xFF4ECDC4), title: 'Singapore', sub: 'Singapore • 54.255.132.228 • 48ms', trailing: '🇸🇬'),
            ])),
            const SizedBox(height: 22),

            _label('ABOUT'),
            const SizedBox(height: 8),
            GlassCard(padding: EdgeInsets.zero, child: Column(children: [
              _InfoRow(icon: Icons.info_outline_rounded, color: AppColors.accent,       title: 'Version',    sub: 'MarianaVPN v1.0.0',           trailing: ''),
              _Div(),
              _InfoRow(icon: Icons.shield_rounded,       color: AppColors.accent,       title: 'Powered by', sub: 'OpenVPN (ics-openvpn)',        trailing: ''),
              _Div(),
              _InfoRow(icon: Icons.favorite_rounded,     color: AppColors.disconnected, title: 'Made by',    sub: 'MohitW',                       trailing: '♥'),
            ])),
            const SizedBox(height: 36),

            Center(child: Column(children: [
              Container(width: 52, height: 52,
                decoration: BoxDecoration(gradient: AppColors.accentGradient, borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: AppColors.accentGlow, blurRadius: 18, spreadRadius: -3)]),
                child: ClipRRect(borderRadius: BorderRadius.circular(15),
                  child: Image.asset('assets/images/icon.png', fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.shield_rounded, color: Colors.white, size: 28)))),
              const SizedBox(height: 10),
              const Text('MarianaVPN', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              const Text('Made with ♥ by MohitW', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 3),
              const Text('v1.0.0  •  OpenVPN', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.5)),
            ])),
            const SizedBox(height: 20),
          ]),
        ))),
      ]),
    );
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(left: 3),
    child: Text(t, style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.8)));
}

// ── Reusable tile widgets ─────────────────────────────────────────────────────
class _Toggle extends StatelessWidget {
  final IconData icon; final Color color; final String title, sub; final bool value; final Function(bool) onChanged;
  const _Toggle({required this.icon, required this.color, required this.title, required this.sub, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(children: [
      AnimatedContainer(duration: const Duration(milliseconds: 200), width: 36, height: 36,
        decoration: BoxDecoration(color: (value ? color : AppColors.textMuted).withOpacity(0.13), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: value ? color : AppColors.textMuted, size: 17)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(sub,   style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      ])),
      Switch.adaptive(value: value, onChanged: onChanged, activeColor: AppColors.accent, inactiveTrackColor: AppColors.glassBorder),
    ]));
}

class _ProtocolRow extends StatelessWidget {
  final String current; final Function(String) onSelect;
  const _ProtocolRow({required this.current, required this.onSelect});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (_) => _ProtocolSheet(current: current, onSelect: onSelect)),
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.connecting.withOpacity(0.13), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.bolt_rounded, color: AppColors.connecting, size: 17)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Protocol', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          Text('$current (recommended)', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(color: AppColors.connecting.withOpacity(0.11), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.connecting.withOpacity(0.3))),
          child: Text(current, style: const TextStyle(color: AppColors.connecting, fontSize: 10, fontWeight: FontWeight.w700))),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 17),
      ])),
  );
}

class _ProtocolSheet extends StatelessWidget {
  final String current; final Function(String) onSelect;
  const _ProtocolSheet({required this.current, required this.onSelect});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(color: Color(0xFF111827), borderRadius: BorderRadius.vertical(top: Radius.circular(26)), border: Border(top: BorderSide(color: AppColors.glassBorder))),
    padding: const EdgeInsets.all(22),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 38, height: 4, decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 18),
      const Align(alignment: Alignment.centerLeft, child: Text('Select Protocol', style: TextStyle(color: AppColors.textPrimary, fontSize: 19, fontWeight: FontWeight.w700))),
      const SizedBox(height: 4),
      const Align(alignment: Alignment.centerLeft, child: Text('UDP is faster, TCP is more reliable', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
      const SizedBox(height: 16),
      ...[('UDP', 'Faster, lower latency', Icons.speed_rounded), ('TCP', 'More reliable, bypasses firewalls', Icons.security_rounded)].map((p) =>
        GestureDetector(onTap: () => onSelect(p.$1), child: AnimatedContainer(duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: current == p.$1 ? AppColors.accent.withOpacity(0.09) : Colors.transparent, borderRadius: BorderRadius.circular(13),
            border: Border.all(color: current == p.$1 ? AppColors.accent.withOpacity(0.4) : AppColors.glassBorder)),
          child: Row(children: [
            Icon(p.$3, color: current == p.$1 ? AppColors.accent : AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.$1, style: TextStyle(color: current == p.$1 ? AppColors.accent : AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              Text(p.$2, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ])),
            if (current == p.$1) const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 19),
          ])))),
      const SizedBox(height: 8),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final Color color; final String title, sub, trailing;
  const _InfoRow({required this.icon, required this.color, required this.title, required this.sub, required this.trailing});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 17)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(sub,   style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      ])),
      if (trailing.isNotEmpty) Text(trailing, style: TextStyle(color: AppColors.textSecondary, fontSize: trailing.length == 1 ? 18 : 12)),
    ]));
}

class _Div extends StatelessWidget {
  @override Widget build(BuildContext context) => Container(height: 0.5, margin: const EdgeInsets.symmetric(horizontal: 14), color: AppColors.glassBorder);
}
