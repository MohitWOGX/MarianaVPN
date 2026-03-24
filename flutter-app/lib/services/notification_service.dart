import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NotificationService {
  static const _ch = MethodChannel('com.mohitw.marianavpn/vpn');

  static void init(void Function(String) onAction) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'notifAction') onAction(call.arguments as String);
      if (call.method == 'vpnPermissionGranted') onAction('permissionGranted');
    });
    _ch.invokeMethod('requestNotificationPermission').catchError((_) {});
  }

  /// Call this BEFORE requesting VPN permission so native knows to auto-connect
  static Future<void> setPendingConnect() async {
    try { await _ch.invokeMethod('setPendingConnect'); } catch (_) {}
  }

  static Future<void> showConnecting(String server) async {
    try {
      await _ch.invokeMethod('showConnecting', {'server': server});
    } catch (e) { debugPrint('notif showConnecting: $e'); }
  }

  static Future<void> showConnected({
    required String server,
    required String flag,
    required String ip,
    required String elapsed,
    String dlSpeed = '0 KB/s',
    String ulSpeed = '0 KB/s',
  }) async {
    try {
      await _ch.invokeMethod('showConnected', {
        'server':  server,
        'flag':    flag,
        'ip':      ip,
        'elapsed': elapsed,
        'dlSpeed': dlSpeed,
        'ulSpeed': ulSpeed,
      });
    } catch (e) { debugPrint('notif showConnected: $e'); }
  }

  static Future<void> dismiss() async {
    try { await _ch.invokeMethod('dismissNotif'); } catch (_) {}
  }
}
