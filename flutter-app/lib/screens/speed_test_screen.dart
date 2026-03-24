import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/theme.dart';
import '../widgets/glass_card.dart';

enum TestPhase { idle, ping, download, upload, done, error }

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});
  @override State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen>
    with TickerProviderStateMixin {

  TestPhase _phase      = TestPhase.idle;
  String    _statusMsg  = '';
  String    _errorMsg   = '';

  // Real results
  double _pingMs        = 0;
  double _jitterMs      = 0;
  double _downloadMbps  = 0;
  double _uploadMbps    = 0;
  double _packetLoss    = 0;

  // Live display
  double _liveSpeed     = 0;
  double _gaugeTarget   = 0;
  double _progress      = 0;

  late AnimationController _gaugeCtrl;
  late Animation<double>   _gaugeAnim;

  // Speedtest uses Cloudflare's speed test endpoints — real measured data
  static const _dlUrls = [
    'https://speed.cloudflare.com/__down?bytes=10000000',  // 10MB
    'https://speed.cloudflare.com/__down?bytes=25000000',  // 25MB
  ];
  static const _ulUrl = 'https://speed.cloudflare.com/__up';
  static const _pingUrl = 'https://speed.cloudflare.com/__down?bytes=0';

  @override
  void initState() {
    super.initState();
    _gaugeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _gaugeAnim = Tween<double>(begin: 0, end: 0)
        .animate(CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _gaugeCtrl.dispose(); super.dispose(); }

  void _setGauge(double val, double max) {
    final t = (val / max).clamp(0.0, 1.0);
    _gaugeAnim = Tween<double>(begin: _gaugeAnim.value, end: t)
        .animate(CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOut));
    _gaugeCtrl.forward(from: 0);
  }

  // ── Real Ping test — uses TCP socket for accurate latency ─────────────────
  // HTTP adds TLS handshake overhead. Raw TCP connect to port 443 measures
  // actual network latency the same way ping measures ICMP round-trip.
  Future<void> _testPing() async {
    setState(() { _phase = TestPhase.ping; _statusMsg = 'Measuring latency...'; _progress = 0.05; });

    final pings = <double>[];
    int failed = 0;

    // Warm up connection first (first TCP connect includes route setup)
    try {
      final sock = await Socket.connect('speed.cloudflare.com', 443,
          timeout: const Duration(seconds: 5));
      sock.destroy();
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 100));

    for (int i = 0; i < 10; i++) {
      try {
        final sw = Stopwatch()..start();
        // TCP connect to port 443 — measures pure network latency
        // without TLS handshake or HTTP overhead
        final sock = await Socket.connect('speed.cloudflare.com', 443,
            timeout: const Duration(seconds: 5));
        sw.stop();
        sock.destroy();
        pings.add(sw.elapsedMilliseconds.toDouble());
      } catch (_) {
        failed++;
      }

      await Future.delayed(const Duration(milliseconds: 150));

      setState(() {
        _progress = 0.05 + (i + 1) / 10 * 0.15;
        if (pings.isNotEmpty) {
          _pingMs = pings.reduce((a, b) => a + b) / pings.length;
          _liveSpeed = _pingMs;
          _setGauge(_pingMs, 300);
        }
      });
    }

    _packetLoss = failed / 10 * 100;
    if (pings.isNotEmpty) {
      // Remove highest and lowest outlier for cleaner result
      final sorted = List<double>.from(pings)..sort();
      final trimmed = sorted.length > 4
          ? sorted.sublist(1, sorted.length - 1)
          : sorted;
      _pingMs = trimmed.reduce((a, b) => a + b) / trimmed.length;
      _jitterMs = trimmed.map((p) => (p - _pingMs).abs())
          .reduce((a, b) => a + b) / trimmed.length;
    }
  }

  // ── Real Download test ─────────────────────────────────────────────────────
  Future<void> _testDownload() async {
    setState(() { _phase = TestPhase.download; _statusMsg = 'Testing download speed...'; _liveSpeed = 0; });

    final speeds = <double>[];

    for (int run = 0; run < _dlUrls.length; run++) {
      try {
        int bytesReceived = 0;
        final sw = Stopwatch()..start();
        DateTime lastCheck = DateTime.now();
        int lastBytes = 0;

        final client = http.Client();
        final request = http.Request('GET', Uri.parse(_dlUrls[run]));
        final response = await client.send(request)
            .timeout(const Duration(seconds: 30));

        await for (final chunk in response.stream
            .timeout(const Duration(seconds: 30))) {
          bytesReceived += chunk.length;

          final now = DateTime.now();
          final elapsed = now.difference(lastCheck).inMilliseconds;
          if (elapsed >= 300) {
            final chunkBytes = bytesReceived - lastBytes;
            final speedMbps = (chunkBytes * 8) / (elapsed / 1000) / 1000000;
            speeds.add(speedMbps);
            lastBytes = bytesReceived;
            lastCheck = now;

            setState(() {
              _liveSpeed = speedMbps;
              _downloadMbps = speeds.isNotEmpty
                  ? speeds.reduce((a, b) => a + b) / speeds.length : 0;
              _progress = 0.20 + (run * speeds.length) / 20 * 0.35;
              _setGauge(speedMbps, 500);
            });
          }
        }
        client.close();
      } catch (e) {
        debugPrint('Download test error: $e');
      }
    }

    // Use 90th percentile for more accurate result (remove outliers)
    if (speeds.isNotEmpty) {
      speeds.sort();
      final p90idx = (speeds.length * 0.9).floor().clamp(0, speeds.length - 1);
      _downloadMbps = speeds.sublist(0, p90idx + 1)
          .reduce((a, b) => a + b) / (p90idx + 1);
    }

    setState(() { _progress = 0.55; });
  }

  // ── Real Upload test ───────────────────────────────────────────────────────
  Future<void> _testUpload() async {
    setState(() { _phase = TestPhase.upload; _statusMsg = 'Testing upload speed...'; _liveSpeed = 0; });

    final speeds = <double>[];

    // Upload different sizes to get accurate reading
    final uploadSizes = [1000000, 5000000, 10000000]; // 1MB, 5MB, 10MB

    for (int run = 0; run < uploadSizes.length; run++) {
      try {
        // Generate random payload
        final payload = Uint8List(uploadSizes[run]);
        final rnd = Random();
        for (int i = 0; i < payload.length; i++) {
          payload[i] = rnd.nextInt(256);
        }

        final sw = Stopwatch()..start();
        final res = await http.post(
          Uri.parse(_ulUrl),
          headers: {'Content-Type': 'application/octet-stream'},
          body: payload,
        ).timeout(const Duration(seconds: 30));
        sw.stop();

        if (res.statusCode == 200) {
          final seconds = sw.elapsedMilliseconds / 1000;
          final speedMbps = (uploadSizes[run] * 8) / seconds / 1000000;
          speeds.add(speedMbps);
          setState(() {
            _liveSpeed = speedMbps;
            _uploadMbps = speeds.reduce((a, b) => a + b) / speeds.length;
            _progress = 0.55 + (run + 1) / uploadSizes.length * 0.35;
            _setGauge(speedMbps, 500);
          });
        }
      } catch (e) {
        debugPrint('Upload test error: $e');
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (speeds.isNotEmpty) {
      _uploadMbps = speeds.reduce((a, b) => a + b) / speeds.length;
    }

    setState(() { _progress = 0.90; });
  }

  Future<void> _runFullTest() async {
    setState(() {
      _phase = TestPhase.ping;
      _pingMs = 0; _jitterMs = 0;
      _downloadMbps = 0; _uploadMbps = 0;
      _packetLoss = 0; _liveSpeed = 0;
      _progress = 0; _errorMsg = '';
    });

    try {
      await _testPing();
      await _testDownload();
      await _testUpload();
      setState(() { _phase = TestPhase.done; _statusMsg = ''; _progress = 1.0; _liveSpeed = 0; });
      _setGauge(0, 1);
    } catch (e) {
      setState(() {
        _phase = TestPhase.error;
        _errorMsg = 'Test failed. Check your connection.\n$e';
      });
    }
  }

  String get _phaseLabel {
    switch (_phase) {
      case TestPhase.ping:     return 'PING';
      case TestPhase.download: return 'DOWNLOAD';
      case TestPhase.upload:   return 'UPLOAD';
      default: return '';
    }
  }

  String get _liveUnit {
    switch (_phase) {
      case TestPhase.ping: return 'ms';
      default: return 'Mbps';
    }
  }

  @override
  Widget build(BuildContext context) {
    final running = _phase != TestPhase.idle &&
                    _phase != TestPhase.done &&
                    _phase != TestPhase.error;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        // BG mesh
        Container(decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF060810), Color(0xFF0B0F1E), Color(0xFF0D1525)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter))),
        SafeArea(child: Column(children: [
          _TopBar(),
          Expanded(child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              const SizedBox(height: 16),

              // ── Server info ──────────────────────────────────────────────
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.cloud_rounded, color: AppColors.accent, size: 16),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Test Server', style: TextStyle(
                      color: AppColors.textMuted, fontSize: 9,
                      fontWeight: FontWeight.w700, letterSpacing: 1)),
                    const Text('Cloudflare Global Network',
                      style: TextStyle(color: AppColors.textPrimary,
                        fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.connected.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.connected.withOpacity(0.3))),
                    child: const Text('REAL TEST', style: TextStyle(
                      color: AppColors.connected, fontSize: 9,
                      fontWeight: FontWeight.w700, letterSpacing: 1))),
                ]),
              ),

              const SizedBox(height: 20),

              // ── Gauge ────────────────────────────────────────────────────
              AnimatedBuilder(
                animation: _gaugeAnim,
                builder: (_, __) => SizedBox(width: 260, height: 260,
                  child: CustomPaint(
                    painter: _GaugePainter(
                      progress: _gaugeAnim.value, phase: _phase),
                    child: Center(child: _GaugeCenter(
                      phase: _phase, liveSpeed: _liveSpeed,
                      unit: _liveUnit, label: _phaseLabel,
                      ping: _pingMs, download: _downloadMbps,
                      upload: _uploadMbps)),
                  )),
              ),

              const SizedBox(height: 16),

              // ── Progress ─────────────────────────────────────────────────
              if (running) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: AppColors.glassBorder,
                    valueColor: AlwaysStoppedAnimation(_phaseColor),
                    minHeight: 3)),
                const SizedBox(height: 8),
                Text(_statusMsg, style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 16),
              ],

              if (_phase == TestPhase.error)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.disconnected.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.disconnected.withOpacity(0.3))),
                  child: Text(_errorMsg, style: const TextStyle(
                    color: AppColors.disconnected, fontSize: 12))),

              // ── Start / Run again button ──────────────────────────────────
              if (!running)
                GestureDetector(
                  onTap: _runFullTest,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                        color: AppColors.accentGlow,
                        blurRadius: 20, spreadRadius: -4)]),
                    child: Text(
                      _phase == TestPhase.idle ? 'START SPEED TEST' : 'TEST AGAIN',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w800,
                        letterSpacing: 1.5)))),

              const SizedBox(height: 20),

              // ── Results ───────────────────────────────────────────────────
              if (_pingMs > 0 || _downloadMbps > 0 || _uploadMbps > 0) ...[
                Row(children: [
                  _ResultCard('PING',
                    '${_pingMs.toStringAsFixed(0)} ms',
                    _pingColor(_pingMs), Icons.network_ping_rounded),
                  const SizedBox(width: 10),
                  _ResultCard('JITTER',
                    '${_jitterMs.toStringAsFixed(1)} ms',
                    AppColors.connecting, Icons.timeline_rounded),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _ResultCard('DOWNLOAD',
                    '${_downloadMbps.toStringAsFixed(1)} Mbps',
                    AppColors.connected, Icons.arrow_downward_rounded),
                  const SizedBox(width: 10),
                  _ResultCard('UPLOAD',
                    '${_uploadMbps.toStringAsFixed(1)} Mbps',
                    AppColors.accent, Icons.arrow_upward_rounded),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _ResultCard('PACKET LOSS',
                    '${_packetLoss.toStringAsFixed(1)}%',
                    _packetLoss < 1 ? AppColors.connected : AppColors.disconnected,
                    Icons.wifi_tethering_error_rounded),
                  const SizedBox(width: 10),
                  _ResultCard('VIDEO QUALITY',
                    _videoQuality,
                    AppColors.accent, Icons.play_circle_outline_rounded,
                    subtitle: _videoBitrateStr),
                ]),

                if (_phase == TestPhase.done) ...[
                  const SizedBox(height: 10),
                  _QualityCard(
                    download: _downloadMbps, upload: _uploadMbps,
                    ping: _pingMs, loss: _packetLoss),
                ],
              ],

              const SizedBox(height: 24),
            ]),
          )),
        ])),
      ]),
    );
  }

  Color get _phaseColor {
    switch (_phase) {
      case TestPhase.ping:     return AppColors.connecting;
      case TestPhase.download: return AppColors.connected;
      case TestPhase.upload:   return AppColors.accent;
      default:                 return AppColors.accent;
    }
  }

  Color _pingColor(double p) {
    if (p < 30)  return AppColors.connected;
    if (p < 80)  return AppColors.connecting;
    return AppColors.disconnected;
  }

  String get _videoQuality {
    if (_downloadMbps <= 0) return '—';
    if (_downloadMbps > 80) return '8K';
    if (_downloadMbps > 40) return '4K';
    if (_downloadMbps > 15) return '1080p';
    if (_downloadMbps > 5)  return '720p';
    if (_downloadMbps > 2)  return '480p';
    return '360p';
  }

  String get _videoBitrateStr {
    if (_downloadMbps <= 0) return '';
    return '${(_downloadMbps * 0.85).toStringAsFixed(1)} Mbps available';
  }
}

// ── Gauge center display ──────────────────────────────────────────────────────
class _GaugeCenter extends StatelessWidget {
  final TestPhase phase;
  final double liveSpeed, ping, download, upload;
  final String unit, label;

  const _GaugeCenter({
    required this.phase, required this.liveSpeed, required this.ping,
    required this.download, required this.upload,
    required this.unit, required this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (phase == TestPhase.idle) {
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
        Icon(Icons.speed_rounded, color: AppColors.textMuted, size: 52),
        SizedBox(height: 10),
        Text('REAL SPEED TEST', style: TextStyle(
          color: AppColors.textMuted, fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        SizedBox(height: 4),
        Text('Powered by Cloudflare', style: TextStyle(
          color: AppColors.textMuted, fontSize: 10)),
      ]);
    }

    if (phase == TestPhase.done) {
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.connected, size: 44),
        const SizedBox(height: 8),
        Text('${download.toStringAsFixed(1)}', style: const TextStyle(
          color: AppColors.connected, fontSize: 36,
          fontWeight: FontWeight.w700, fontFamily: 'monospace')),
        const Text('Mbps down', style: TextStyle(
          color: AppColors.textSecondary, fontSize: 12)),
      ]);
    }

    if (phase == TestPhase.error) {
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
        Icon(Icons.error_outline_rounded, color: AppColors.disconnected, size: 44),
        SizedBox(height: 8),
        Text('Test Failed', style: TextStyle(
          color: AppColors.disconnected, fontSize: 14, fontWeight: FontWeight.w600)),
      ]);
    }

    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(
        phase == TestPhase.ping
            ? liveSpeed.toStringAsFixed(0)
            : liveSpeed.toStringAsFixed(1),
        style: const TextStyle(color: AppColors.textPrimary,
          fontSize: 44, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
      Text(unit, style: const TextStyle(
        color: AppColors.textSecondary, fontSize: 14)),
      if (label.isNotEmpty) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accent.withOpacity(0.3))),
          child: Text(label, style: const TextStyle(
            color: AppColors.accent, fontSize: 9,
            fontWeight: FontWeight.w700, letterSpacing: 1.2))),
      ],
    ]);
  }
}

// ── Gauge painter ─────────────────────────────────────────────────────────────
class _GaugePainter extends CustomPainter {
  final double progress;
  final TestPhase phase;
  _GaugePainter({required this.progress, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    const start  = pi * 0.75;
    const sweep  = pi * 1.5;

    // Background track
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
      start, sweep, false,
      Paint()..color = AppColors.glassBorder
             ..style = PaintingStyle.stroke
             ..strokeWidth = 10..strokeCap = StrokeCap.round);

    if (progress > 0) {
      final color = phase == TestPhase.download ? AppColors.connected :
                    phase == TestPhase.upload    ? AppColors.accent :
                    phase == TestPhase.ping      ? AppColors.connecting :
                    AppColors.accent;

      // Glow
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        start, sweep * progress, false,
        Paint()..color = color.withOpacity(0.25)
               ..style = PaintingStyle.stroke
               ..strokeWidth = 20..strokeCap = StrokeCap.round
               ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

      // Main arc
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        start, sweep * progress, false,
        Paint()..color = color
               ..style = PaintingStyle.stroke
               ..strokeWidth = 10..strokeCap = StrokeCap.round);
    }

    // Speed labels: 0, 100, 200, 500 Mbps
    final labels = ['0', '100', '200', '500'];
    final labelAngles = [start, start + sweep * 0.33,
                         start + sweep * 0.66, start + sweep];
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < labels.length; i++) {
      tp.text = TextSpan(text: labels[i],
        style: const TextStyle(color: AppColors.textMuted,
          fontSize: 9, fontWeight: FontWeight.w500));
      tp.layout();
      final lx = center.dx + (radius + 16) * cos(labelAngles[i]) - tp.width / 2;
      final ly = center.dy + (radius + 16) * sin(labelAngles[i]) - tp.height / 2;
      tp.paint(canvas, Offset(lx, ly));
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress || old.phase != phase;
}

// ── Top bar ───────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(children: [
      const Text('Speed Test', style: TextStyle(
        color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
      const Spacer(),
      GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.verified_rounded, color: AppColors.connected, size: 12),
          SizedBox(width: 5),
          Text('Real Data', style: TextStyle(
            color: AppColors.connected, fontSize: 10, fontWeight: FontWeight.w700)),
        ])),
    ]),
  );
}

// ── Result card ───────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final String label, value;
  final Color  color;
  final IconData icon;
  final String? subtitle;
  const _ResultCard(this.label, this.value, this.color, this.icon, {this.subtitle});

  @override
  Widget build(BuildContext context) => Expanded(child: GlassCard(
    padding: const EdgeInsets.all(14),
    borderColor: color.withOpacity(0.2),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 28, height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 14)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(
          color: AppColors.textMuted, fontSize: 8,
          fontWeight: FontWeight.w700, letterSpacing: 1)),
      ]),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(
        color: color, fontSize: 18, fontWeight: FontWeight.w700)),
      if (subtitle != null)
        Text(subtitle!, style: const TextStyle(
          color: AppColors.textSecondary, fontSize: 10)),
    ]),
  ));
}

// ── Quality card ──────────────────────────────────────────────────────────────
class _QualityCard extends StatelessWidget {
  final double download, upload, ping, loss;
  const _QualityCard({
    required this.download, required this.upload,
    required this.ping, required this.loss});

  String get _grade {
    int score = 0;
    if (download > 100) score += 3;
    else if (download > 50) score += 2;
    else if (download > 10) score += 1;
    if (ping < 20) score += 3;
    else if (ping < 50) score += 2;
    else if (ping < 100) score += 1;
    if (loss < 0.1) score += 2;
    else if (loss < 1) score += 1;
    if (score >= 7) return 'Excellent';
    if (score >= 5) return 'Good';
    if (score >= 3) return 'Fair';
    return 'Poor';
  }

  Color get _gradeColor {
    switch (_grade) {
      case 'Excellent': return AppColors.connected;
      case 'Good':      return AppColors.accent;
      case 'Fair':      return AppColors.connecting;
      default:          return AppColors.disconnected;
    }
  }

  List<_UseCase> get _useCases => [
    _UseCase('4K Streaming',   download >= 25,  '📺'),
    _UseCase('1080p Streaming',download >= 5,   '📺'),
    _UseCase('Video Calls',    download >= 3 && upload >= 1, '📹'),
    _UseCase('Online Gaming',  ping <= 60 && loss < 1, '🎮'),
    _UseCase('Cloud Backup',   upload >= 10,    '☁️'),
    _UseCase('Large Downloads',download >= 50,  '⬇️'),
  ];

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(16),
    borderColor: _gradeColor.withOpacity(0.2),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Connection Quality', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: _gradeColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _gradeColor.withOpacity(0.3))),
          child: Text(_grade, style: TextStyle(
            color: _gradeColor, fontSize: 12, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 14),
      ..._useCases.map((u) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text(u.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          Expanded(child: Text(u.name, style: const TextStyle(
            color: AppColors.textSecondary, fontSize: 13))),
          Icon(
            u.ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: u.ok ? AppColors.connected : AppColors.textMuted,
            size: 16),
        ]))),
    ]),
  );
}

class _UseCase {
  final String name, emoji;
  final bool ok;
  const _UseCase(this.name, this.ok, this.emoji);
}
