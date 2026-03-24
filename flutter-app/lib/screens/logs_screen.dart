import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vpn_provider.dart';
import '../models/connection_log.dart';
import '../utils/theme.dart';
import '../widgets/glass_card.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(child: Consumer<VpnProvider>(builder: (context, vpn, _) {
        final logs = vpn.logs;
        return Column(children: [
          _topBar(),
          if (logs.isEmpty)
            Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.history_rounded, color: AppColors.textMuted, size: 60),
              const SizedBox(height: 14),
              const Text('No sessions yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              const Text('Connect to see your history here', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ])))
          else ...[
            _summary(logs),
            Expanded(child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
              itemCount: logs.length,
              itemBuilder: (_, i) => _LogTile(log: logs[i]),
            )),
            _clearBtn(context, vpn),
          ],
        ]);
      })),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
    child: const Align(alignment: Alignment.centerLeft,
      child: Text('History', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700))),
  );

  Widget _summary(List<ConnectionLog> logs) {
    final succ = logs.where((l) => l.wasSuccessful).length;
    final rate = logs.isEmpty ? 0 : (succ * 100 ~/ logs.length);
    final total = logs.fold(Duration.zero, (s, l) => s + l.duration);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Row(children: [
        _SumCard('Sessions', '${logs.length}', AppColors.accent),
        const SizedBox(width: 10),
        _SumCard('Success', '$rate%', AppColors.connected),
        const SizedBox(width: 10),
        _SumCard('Time', '${total.inHours}h ${total.inMinutes % 60}m', AppColors.connecting),
      ]),
    );
  }

  Widget _clearBtn(BuildContext context, VpnProvider vpn) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    child: GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 13),
      borderColor: AppColors.disconnected.withOpacity(0.22),
      onTap: () => showDialog(context: context, builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.glassBorder)),
        title: const Text('Clear History', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Delete all connection logs?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(onPressed: () { vpn.clearLogs(); Navigator.pop(context); }, child: const Text('Clear', style: TextStyle(color: AppColors.disconnected))),
        ],
      )),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.delete_outline_rounded, color: AppColors.disconnected, size: 17),
        SizedBox(width: 8),
        Text('Clear All', style: TextStyle(color: AppColors.disconnected, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _SumCard extends StatelessWidget {
  final String label; final String value; final Color color;
  const _SumCard(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: GlassCard(
    padding: const EdgeInsets.symmetric(vertical: 12),
    borderColor: color.withOpacity(0.2),
    child: Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    ]),
  ));
}

class _LogTile extends StatelessWidget {
  final ConnectionLog log;
  const _LogTile({required this.log});
  @override
  Widget build(BuildContext context) {
    final color = log.wasSuccessful ? AppColors.connected : AppColors.disconnected;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 5)])),
        const SizedBox(width: 10),
        Text(log.serverFlag, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(log.serverName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          Text(log.errorMessage ?? log.formattedDuration, style: TextStyle(color: log.errorMessage != null ? AppColors.disconnected : AppColors.textSecondary, fontSize: 11)),
        ])),
        Text(log.formattedDate, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
      ]),
    );
  }
}
