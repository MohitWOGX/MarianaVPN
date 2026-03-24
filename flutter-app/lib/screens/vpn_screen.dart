import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vpn_provider.dart';
import '../utils/theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/connect_button.dart';
import '../widgets/stats_bar.dart';
import '../widgets/server_selector.dart';

class VpnScreen extends StatelessWidget {
  const VpnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VpnProvider>(builder: (context, vpn, _) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(children: [

          // ── Layer 0: Static mesh gradient background ──────────────
          const _MeshBackground(),

          // ── Layer 1: Animated ambient orbs (BEHIND content) ───────
          _AmbientOrbs(status: vpn.status),

          // ── Layer 2: ALL content (scrollable, sits above BG) ──────
          SafeArea(child: Column(children: [
            _TopBar(vpn: vpn),
            Expanded(child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                const SizedBox(height: 8),
                _StatusChip(status: vpn.status),
                const SizedBox(height: 24),

                // Connect button — wrapped in its own opaque container
                // so BG orbs CANNOT bleed through it
                _ButtonArea(vpn: vpn),

                const SizedBox(height: 16),

                // Retry badge
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: vpn.isConnecting && vpn.retryCount > 0
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RetryBadge(count: vpn.retryCount))
                      : const SizedBox.shrink(),
                ),

                // Timer badge
                AnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  child: vpn.isConnected
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TimerBadge(time: vpn.elapsedTime))
                      : const SizedBox.shrink(),
                ),

                _IpCard(vpn: vpn),
                const SizedBox(height: 10),
                StatsBar(
                  download: vpn.downloadSpeed,
                  upload: vpn.uploadSpeed,
                  ping: vpn.selectedServer.ping,
                  isConnected: vpn.isConnected,
                ),

                AnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  child: vpn.isConnected
                      ? Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _DataTotals(vpn: vpn))
                      : const SizedBox.shrink(),
                ),

                const SizedBox(height: 10),
                ServerSelector(
                    selected: vpn.selectedServer, onSelect: vpn.selectServer),
                const SizedBox(height: 10),
                _KillSwitch(vpn: vpn),
                const SizedBox(height: 28),
                _Footer(),
                const SizedBox(height: 16),
              ]),
            )),
          ])),
        ]),
      );
    });
  }
}

// ── Button area with isolated background so orbs don't show through ───────────
class _ButtonArea extends StatelessWidget {
  final VpnProvider vpn;
  const _ButtonArea({required this.vpn});

  @override
  Widget build(BuildContext context) {
    return ConnectButton(
      status: vpn.status,
      onTap: () {
        if (vpn.isConnected)       vpn.disconnect();
        else if (vpn.isConnecting) vpn.disconnect(); // cancel
        else                       vpn.connect();
      },
    );
  }
}

// ── Static mesh background — rendered once, never repaints ────────────────────
class _MeshBackground extends StatelessWidget {
  const _MeshBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SizedBox.expand(
      child: CustomPaint(painter: _MeshPainter(size)),
    );
  }
}

class _MeshPainter extends CustomPainter {
  final Size screenSize;
  _MeshPainter(this.screenSize);

  @override
  void paint(Canvas canvas, Size size) {
    // Deep gradient base
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF060810), Color(0xFF0B0F1E), Color(0xFF0D1525)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Subtle diagonal grid lines (blueprint feel)
    final gridPaint = Paint()
      ..color = const Color(0x06FFFFFF)
      ..strokeWidth = 0.5;

    const spacing = 60.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), gridPaint);
    }

    // Top-right accent gradient blob
    final tr = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0x1A00D4FF), Colors.transparent],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.85, size.height * 0.08), radius: 280));
    canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.08), 280, tr);

    // Bottom-left purple blob
    final bl = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0x128B5CF6), Colors.transparent],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.1, size.height * 0.88), radius: 240));
    canvas.drawCircle(
        Offset(size.width * 0.1, size.height * 0.88), 240, bl);

    // Center bottom blue blob
    final cb = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0x0E006EFF), Colors.transparent],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height * 0.95), radius: 200));
    canvas.drawCircle(
        Offset(size.width * 0.5, size.height * 0.95), 200, cb);
  }

  @override
  bool shouldRepaint(_MeshPainter old) => false; // static — never repaints
}

// ── Ambient orbs — animated, behind content but don't affect button ───────────
class _AmbientOrbs extends StatefulWidget {
  final TunnelStatus status;
  const _AmbientOrbs({required this.status});

  @override
  State<_AmbientOrbs> createState() => _AmbientOrbsState();
}

class _AmbientOrbsState extends State<_AmbientOrbs>
    with TickerProviderStateMixin {
  late AnimationController _float;
  late AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    _float   = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
    _breathe = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    _breathe.dispose();
    super.dispose();
  }

  Color get _orbColor {
    switch (widget.status) {
      case TunnelStatus.connected:     return AppColors.connected.withOpacity(0.08);
      case TunnelStatus.connecting:
      case TunnelStatus.disconnecting: return AppColors.connecting.withOpacity(0.06);
      default:                         return AppColors.accent.withOpacity(0.06);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_float, _breathe]),
      builder: (_, __) {
        final f = _float.value;
        final b = _breathe.value;
        return Stack(children: [
          // Top-right floating orb
          Positioned(
            top: -80 + f * 30, right: -60,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 1000),
              width: 320, height: 320,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _orbColor))),

          // Bottom-left counter orb
          Positioned(
            bottom: -100 - f * 20, left: -70,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: AppColors.accentDeep.withOpacity(0.05)))),

          // Center breathing orb — positioned at button area height
          // IMPORTANT: pointer-events don't apply here, this is just visual
          Positioned(
            top: MediaQuery.of(context).size.height * 0.28,
            left: MediaQuery.of(context).size.width / 2 - 100,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: _orbColor.withOpacity(0.3 + 0.15 * b)))),
        ]);
      },
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final VpnProvider vpn;
  const _TopBar({required this.vpn});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Subtle top gradient so status bar reads cleanly
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [AppColors.bg.withOpacity(0.9), AppColors.bg.withOpacity(0)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(11),
            boxShadow: [BoxShadow(color: AppColors.accentGlow, blurRadius: 20, spreadRadius: -2)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.asset('assets/images/icon.png', fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.shield_rounded, color: Colors.white, size: 20)),
          ),
        ),
        const SizedBox(width: 11),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MarianaVPN', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 17,
            fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          Text('by MohitW ♥', style: TextStyle(
            color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w500)),
        ]),
        const Spacer(),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim,
            child: ScaleTransition(
              scale: Tween(begin: 0.7, end: 1.0).animate(anim), child: child)),
          child: vpn.isConnected
            ? GlassCard(
                key: const ValueKey('badge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                borderColor: AppColors.connected.withOpacity(0.35),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _PulseDot(color: AppColors.connected),
                  const SizedBox(width: 6),
                  const Text('SECURE', style: TextStyle(
                    color: AppColors.connected, fontSize: 9,
                    fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ]),
              )
            : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ]),
    );
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final TunnelStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    late Color c; late String t; late Widget icon;
    switch (status) {
      case TunnelStatus.connected:
        c = AppColors.connected; t = 'PROTECTED';
        icon = Icon(Icons.verified_rounded, color: c, size: 13); break;
      case TunnelStatus.connecting:
        c = AppColors.connecting; t = 'CONNECTING  —  TAP TO CANCEL';
        icon = _SpinIcon(color: c, size: 13); break;
      case TunnelStatus.disconnecting:
        c = AppColors.connecting; t = 'DISCONNECTING';
        icon = _SpinIcon(color: c, size: 13); break;
      case TunnelStatus.error:
        c = AppColors.disconnected; t = 'FAILED  —  TAP TO RETRY';
        icon = Icon(Icons.warning_rounded, color: c, size: 13); break;
      default:
        c = AppColors.disconnected; t = 'UNPROTECTED';
        icon = Icon(Icons.warning_amber_rounded, color: c, size: 13);
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: c.withOpacity(0.35)),
        // Subtle inner glow
        boxShadow: [BoxShadow(color: c.withOpacity(0.06), blurRadius: 12, spreadRadius: 0)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        icon, const SizedBox(width: 7),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(t, key: ValueKey(t), style: TextStyle(
            color: c, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.3)),
        ),
      ]),
    );
  }
}

// ── Retry badge ───────────────────────────────────────────────────────────────
class _RetryBadge extends StatelessWidget {
  final int count;
  const _RetryBadge({required this.count});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.connecting.withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.connecting.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      _SpinIcon(color: AppColors.connecting, size: 12),
      const SizedBox(width: 8),
      Text('Auto-retrying  $count / 3',
        style: const TextStyle(color: AppColors.connecting,
          fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Timer badge ───────────────────────────────────────────────────────────────
class _TimerBadge extends StatelessWidget {
  final String time;
  const _TimerBadge({required this.time});
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    borderColor: AppColors.connected.withOpacity(0.3),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.timer_outlined, color: AppColors.connected, size: 15),
      const SizedBox(width: 10),
      Text(time, style: const TextStyle(
        color: AppColors.connected, fontSize: 18, fontWeight: FontWeight.w700,
        fontFamily: 'monospace', letterSpacing: 2.5)),
    ]),
  );
}

// ── IP card ───────────────────────────────────────────────────────────────────
class _IpCard extends StatelessWidget {
  final VpnProvider vpn;
  const _IpCard({required this.vpn});
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: (vpn.isConnected ? AppColors.connected : AppColors.accent).withOpacity(0.12),
          borderRadius: BorderRadius.circular(9)),
        child: Icon(Icons.language_rounded,
          color: vpn.isConnected ? AppColors.connected : AppColors.accent, size: 16)),
      const SizedBox(width: 12),
      const Text('IP Address', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const Spacer(),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.1, 0), end: Offset.zero).animate(anim),
            child: child)),
        child: Text(vpn.connectedIp, key: ValueKey(vpn.connectedIp),
          style: TextStyle(
            color: vpn.isConnected ? AppColors.textPrimary : AppColors.textMuted,
            fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
      ),
    ]),
  );
}

// ── Data totals ───────────────────────────────────────────────────────────────
class _DataTotals extends StatelessWidget {
  final VpnProvider vpn;
  const _DataTotals({required this.vpn});
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    borderColor: AppColors.connected.withOpacity(0.15),
    child: Row(children: [
      _DataCell(Icons.arrow_downward_rounded, 'DOWNLOADED', vpn.totalDownload, AppColors.connected),
      Container(height: 28, width: 0.8, color: AppColors.glassBorder),
      _DataCell(Icons.arrow_upward_rounded,   'UPLOADED',   vpn.totalUpload,   AppColors.accent),
    ]),
  );
}

class _DataCell extends StatelessWidget {
  final IconData icon; final String label; final String value; final Color color;
  const _DataCell(this.icon, this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Row(children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted,
          fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(value, key: ValueKey(value),
            style: const TextStyle(color: AppColors.textPrimary,
              fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
    ]),
  ));
}

// ── Kill switch ───────────────────────────────────────────────────────────────
class _KillSwitch extends StatelessWidget {
  final VpnProvider vpn;
  const _KillSwitch({required this.vpn});
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: (vpn.killSwitch ? AppColors.disconnected : AppColors.textMuted).withOpacity(0.13),
          borderRadius: BorderRadius.circular(9)),
        child: Icon(Icons.block_rounded,
          color: vpn.killSwitch ? AppColors.disconnected : AppColors.textMuted, size: 17)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        Text('Kill Switch', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        Text('Block all traffic if VPN drops', style: TextStyle(
          color: AppColors.textSecondary, fontSize: 11)),
      ])),
      Switch.adaptive(
        value: vpn.killSwitch, onChanged: vpn.setKillSwitch,
        activeColor: AppColors.accent, inactiveTrackColor: AppColors.glassBorder),
    ]),
  );
}

class _Footer extends StatefulWidget {
  @override
  State<_Footer> createState() => _FooterState();
}

class _FooterState extends State<_Footer> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<Color?> _color;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _color = TweenSequence<Color?>([
      TweenSequenceItem(tween: ColorTween(begin: const Color(0xFF00D4FF), end: const Color(0xFF8B5CF6)), weight: 1),
      TweenSequenceItem(tween: ColorTween(begin: const Color(0xFF8B5CF6), end: const Color(0xFFEC4899)), weight: 1),
      TweenSequenceItem(tween: ColorTween(begin: const Color(0xFFEC4899), end: const Color(0xFFFF8C00)), weight: 1),
      TweenSequenceItem(tween: ColorTween(begin: const Color(0xFFFF8C00), end: const Color(0xFF00E5A0)), weight: 1),
      TweenSequenceItem(tween: ColorTween(begin: const Color(0xFF00E5A0), end: const Color(0xFF00D4FF)), weight: 1),
    ]).animate(_c);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _color,
    builder: (_, __) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.favorite_rounded, color: _color.value, size: 11),
        const SizedBox(width: 6),
        Text('Made with ❤️ by MohitW',
          style: TextStyle(color: _color.value, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

// ── Small reusable widgets ────────────────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override State<_PulseDot> createState() => _PulseDotState();
}
class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Container(width: 6, height: 6,
      decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color,
        boxShadow: [BoxShadow(
          color: widget.color.withOpacity(0.3 + 0.3 * _c.value),
          blurRadius: 4 + 4 * _c.value)])));
}

class _SpinIcon extends StatefulWidget {
  final Color color; final double size;
  const _SpinIcon({required this.color, required this.size});
  @override State<_SpinIcon> createState() => _SpinIconState();
}
class _SpinIconState extends State<_SpinIcon> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _c, child: Icon(Icons.sync_rounded, color: widget.color, size: widget.size));
}
