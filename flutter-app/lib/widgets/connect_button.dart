import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../services/vpn_provider.dart';

class ConnectButton extends StatefulWidget {
  final TunnelStatus status;
  final VoidCallback onTap;
  const ConnectButton({super.key, required this.status, required this.onTap});

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton>
    with TickerProviderStateMixin {

  // RGB color cycle
  late AnimationController _rgb;

  // Pulse when connected
  late AnimationController _pulse;
  late Animation<double>   _pulseAnim;

  // Spin arc when connecting
  late AnimationController _spin;

  // Ripple burst
  late AnimationController _ripple;
  late Animation<double>   _rippleScale;
  late Animation<double>   _rippleFade;
  late AnimationController _ripple2;
  late Animation<double>   _ripple2Scale;
  late Animation<double>   _ripple2Fade;

  // Pop on state change
  late AnimationController _pop;
  late Animation<double>   _popAnim;

  TunnelStatus _prevStatus = TunnelStatus.disconnected;
  Color        _prevColor  = AppColors.accent;

  @override
  void initState() {
    super.initState();

    _rgb = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))..repeat();

    _pulse = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    _spin = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));

    _ripple = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _rippleScale = Tween<double>(begin: 1.0, end: 2.5)
        .animate(CurvedAnimation(parent: _ripple, curve: Curves.easeOut));
    _rippleFade = Tween<double>(begin: 0.7, end: 0.0)
        .animate(CurvedAnimation(parent: _ripple, curve: Curves.easeOut));

    _ripple2 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _ripple2Scale = Tween<double>(begin: 1.0, end: 2.1)
        .animate(CurvedAnimation(parent: _ripple2, curve: Curves.easeOut));
    _ripple2Fade = Tween<double>(begin: 0.4, end: 0.0)
        .animate(CurvedAnimation(parent: _ripple2, curve: Curves.easeOut));

    _pop = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _popAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.84), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.84, end: 1.14), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.14, end: 1.0),  weight: 25),
    ]).animate(CurvedAnimation(parent: _pop, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(ConnectButton old) {
    super.didUpdateWidget(old);
    if (widget.status == _prevStatus) return;
    _prevColor = _colorFor(_prevStatus);

    if (widget.status == TunnelStatus.connecting) {
      _spin.repeat();
    } else {
      _spin.stop(); _spin.reset();
    }

    final isTransition =
        (widget.status == TunnelStatus.connected) ||
        (widget.status == TunnelStatus.disconnected &&
            (_prevStatus == TunnelStatus.connected ||
             _prevStatus == TunnelStatus.disconnecting));

    if (isTransition) {
      _ripple.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 160), () {
        if (mounted) _ripple2.forward(from: 0);
      });
      _pop.forward(from: 0);
    }

    _prevStatus = widget.status;
  }

  @override
  void dispose() {
    _rgb.dispose(); _pulse.dispose(); _spin.dispose();
    _ripple.dispose(); _ripple2.dispose(); _pop.dispose();
    super.dispose();
  }

  Color _colorFor(TunnelStatus s) {
    switch (s) {
      case TunnelStatus.connected:     return AppColors.connected;
      case TunnelStatus.connecting:    return AppColors.connecting;
      case TunnelStatus.disconnecting: return AppColors.connecting;
      case TunnelStatus.error:         return AppColors.disconnected;
      default:                         return AppColors.accent;
    }
  }

  Color get _stateColor => _colorFor(widget.status);

  Color get _glowColor {
    switch (widget.status) {
      case TunnelStatus.connected:     return AppColors.connectedGlow;
      case TunnelStatus.connecting:    return AppColors.connectingGlow;
      case TunnelStatus.disconnecting: return AppColors.connectingGlow;
      default:                         return AppColors.accentGlow;
    }
  }

  String get _label {
    switch (widget.status) {
      case TunnelStatus.connected:     return 'CONNECTED';
      case TunnelStatus.connecting:    return 'TAP TO CANCEL';
      case TunnelStatus.disconnecting: return 'STOPPING';
      case TunnelStatus.error:         return 'TAP TO RETRY';
      default:                         return 'CONNECT';
    }
  }

  IconData get _icon {
    switch (widget.status) {
      case TunnelStatus.connected:     return Icons.power_settings_new_rounded;
      case TunnelStatus.connecting:    return Icons.close_rounded;
      case TunnelStatus.error:         return Icons.refresh_rounded;
      default:                         return Icons.power_settings_new_outlined;
    }
  }

  bool get _canTap => widget.status != TunnelStatus.disconnecting;

  /// Interpolate through the RGB color list based on animation value 0..1
  Color _rgbColor(double t) {
    final colors = AppColors.rgbColors;
    final scaled = t * (colors.length - 1);
    final idx    = scaled.floor().clamp(0, colors.length - 2);
    final frac   = scaled - idx;
    return Color.lerp(colors[idx], colors[idx + 1], frac)!;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _canTap ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _rgb, _pulseAnim, _spin, _ripple, _ripple2, _popAnim,
        ]),
        builder: (_, __) {
          final pulse = widget.status == TunnelStatus.connected
              ? _pulseAnim.value : 1.0;

          // Current RGB color — only shown when disconnected/idle
          final rgbColor = _rgbColor(_rgb.value);

          return Transform.scale(
            scale: pulse * _popAnim.value,
            child: SizedBox(
              width: 220, height: 220,
              child: Stack(alignment: Alignment.center, children: [

                // ── Ripple ring 1 ─────────────────────────────────────
                if (_ripple.value > 0 && _ripple.value < 1)
                  Opacity(
                    opacity: _rippleFade.value,
                    child: Transform.scale(
                      scale: _rippleScale.value,
                      child: Container(width: 152, height: 152,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          border: Border.all(color: _prevColor.withOpacity(0.8), width: 2))),
                    ),
                  ),

                // ── Ripple ring 2 ─────────────────────────────────────
                if (_ripple2.value > 0 && _ripple2.value < 1)
                  Opacity(
                    opacity: _ripple2Fade.value,
                    child: Transform.scale(
                      scale: _ripple2Scale.value,
                      child: Container(width: 155, height: 155,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          border: Border.all(color: _prevColor.withOpacity(0.4), width: 1.5))),
                    ),
                  ),

                // ── Outer ambient glow ────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeInOut,
                  width: 210, height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: _glowColor,
                      blurRadius: widget.status == TunnelStatus.connected ? 90 : 55,
                      spreadRadius: widget.status == TunnelStatus.connected ? 16 : 6,
                    )],
                  ),
                ),

                // ── RGB rotating outer ring (disconnected/idle) ───────
                if (widget.status == TunnelStatus.disconnected ||
                    widget.status == TunnelStatus.error)
                  Transform.rotate(
                    angle: _rgb.value * 2 * pi,
                    child: Container(
                      width: 184, height: 184,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: AppColors.rgbColors,
                          startAngle: 0,
                          endAngle: 2 * pi,
                        ),
                      ),
                    ),
                  ),

                // ── Frosted mask to turn rotating gradient into a ring ─
                if (widget.status == TunnelStatus.disconnected ||
                    widget.status == TunnelStatus.error)
                  Container(
                    width: 176, height: 176,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0B0F1E), // matches bg — creates ring illusion
                    ),
                  ),

                // ── Subtle RGB glow behind button when idle ───────────
                if (widget.status == TunnelStatus.disconnected ||
                    widget.status == TunnelStatus.error)
                  Container(
                    width: 176, height: 176,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: rgbColor.withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: -8,
                      )],
                    ),
                  ),

                // ── Spinning connecting arcs ──────────────────────────
                if (widget.status == TunnelStatus.connecting ||
                    widget.status == TunnelStatus.disconnecting) ...[
                  Transform.rotate(
                    angle: _spin.value * 2 * pi,
                    child: SizedBox(width: 180, height: 180,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: _stateColor.withOpacity(0.55),
                        backgroundColor: Colors.transparent))),
                  Transform.rotate(
                    angle: -_spin.value * 2 * pi * 0.65,
                    child: SizedBox(width: 167, height: 167,
                      child: CircularProgressIndicator(
                        strokeWidth: 1,
                        color: _stateColor.withOpacity(0.28),
                        backgroundColor: Colors.transparent))),
                ],

                // ── Connected animated ring ────────────────────────────
                if (widget.status == TunnelStatus.connected)
                  Container(
                    width: 178, height: 178,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.connected.withOpacity(0.5 + 0.2 * (_pulseAnim.value - 0.97) / 0.06),
                        width: 1.5,
                      ),
                    ),
                  ),

                // ── Outer decorative dim ring ──────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  width: 172, height: 172,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _stateColor.withOpacity(0.12), width: 1),
                  ),
                ),

                // ── Main button ───────────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  width: 158, height: 158,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.3, -0.3),
                      colors: [
                        _stateColor.withOpacity(
                          widget.status == TunnelStatus.connected ? 0.24 : 0.13),
                        _stateColor.withOpacity(0.03),
                      ],
                    ),
                    border: Border.all(
                      color: _stateColor.withOpacity(0.75), width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: anim, child: FadeTransition(opacity: anim, child: child)),
                        child: Icon(_icon,
                          key: ValueKey(widget.status),
                          color: _stateColor, size: 52),
                      ),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        child: Text(_label,
                          key: ValueKey(widget.status),
                          style: TextStyle(
                            color: _stateColor, fontSize: 9,
                            fontWeight: FontWeight.w800, letterSpacing: 1.6)),
                      ),
                    ],
                  ),
                ),

              ]),
            ),
          );
        },
      ),
    );
  }
}
