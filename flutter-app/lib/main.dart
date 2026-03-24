import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/vpn_provider.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Run these in parallel for faster startup
  await Future.wait([
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0B0F1E),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const MarianaVpnApp());
}

class MarianaVpnApp extends StatelessWidget {
  const MarianaVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final vpn = VpnProvider();
        NotificationService.init((action) {
          if (action == 'disconnect') vpn.disconnect();
          if (action == 'permissionGranted' && true) vpn.onPermissionGranted();
        });
        return vpn;
      },
      child: MaterialApp(
        title: 'MarianaVPN',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const SplashScreen(),
        // Lock text scale so large system fonts don't break layout
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0)),
          child: child!,
        ),
      ),
    );
  }
}
