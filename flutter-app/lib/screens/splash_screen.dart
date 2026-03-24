import 'package:flutter/material.dart';
import '../utils/theme.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _scale, _fade, _textFade;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _scale     = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)));
    _fade      = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.4, curve: Curves.easeIn)));
    _textFade  = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _c, curve: const Interval(0.5, 1.0, curve: Curves.easeIn)));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(CurvedAnimation(parent: _c, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));
    _c.forward();
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ));
    });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        // BG glow
        Center(child: Container(width: 350, height: 350, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withOpacity(0.04)))),
        Center(child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Logo
            Opacity(opacity: _fade.value, child: Transform.scale(scale: _scale.value, child: Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: AppColors.accentGradient,
                boxShadow: [BoxShadow(color: AppColors.accentGlow, blurRadius: 40, spreadRadius: -4)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                // Shows your actual logo icon
                child: Image.asset('assets/images/icon.png', fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.shield_rounded, color: Colors.white, size: 52)),
              ),
            ))),
            const SizedBox(height: 28),
            // Text
            SlideTransition(position: _textSlide, child: Opacity(opacity: _textFade.value, child: Column(children: [
              const Text('MarianaVPN', style: TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              const SizedBox(height: 8),
              const Text('SECURE  •  PRIVATE  •  FAST', style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 2.5, fontWeight: FontWeight.w600)),
            ]))),
          ]),
        )),
        // Footer
        Positioned(bottom: 40, left: 0, right: 0,
          child: AnimatedBuilder(animation: _c, builder: (_, __) => Opacity(opacity: _textFade.value,
            child: const Text('Made with ♥ by MohitW', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12))))),
      ]),
    );
  }
}
