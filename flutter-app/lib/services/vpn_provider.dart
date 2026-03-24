import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart' as ovpn;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vpn_server.dart';
import '../models/connection_log.dart';
import 'notification_service.dart';

enum TunnelStatus { disconnected, connecting, connected, disconnecting, error }

class VpnProvider extends ChangeNotifier {
  late ovpn.OpenVPN _engine;

  TunnelStatus _status        = TunnelStatus.disconnected;
  VpnServer    _server        = VpnServer.servers.first;
  String       _connectedIp   = '---.---.---.---';
  DateTime?    _connectedAt;
  String       _elapsedTime   = '00:00:00';

  int      _lastIn    = 0;
  int      _lastOut   = 0;
  int      _totalIn   = 0;
  int      _totalOut  = 0;
  String   _dlSpeed   = '0 KB/s';
  String   _ulSpeed   = '0 KB/s';
  DateTime? _lastStatAt;

  bool   _killSwitch    = false;
  bool   _dnsLeak       = true;
  bool   _autoReconnect = true;
  String _protocol      = 'UDP';

  Timer? _clockTimer;
  Timer? _retryTimer;
  Timer? _connectTimeoutTimer;

  int  _retryCount       = 0;
  static const _maxRetries = 3;
  bool _userWantsConnect = false;
  bool _permissionPending = false; // tracks if waiting for VPN permission

  final List<ConnectionLog> _logs = [];

  TunnelStatus get status         => _status;
  VpnServer    get selectedServer => _server;
  String       get downloadSpeed  => _dlSpeed;
  String       get uploadSpeed    => _ulSpeed;
  String       get totalDownload  => _fmtBytes(_totalIn);
  String       get totalUpload    => _fmtBytes(_totalOut);
  String       get connectedIp    => _connectedIp;
  bool         get killSwitch     => _killSwitch;
  bool         get dnsLeak        => _dnsLeak;
  bool         get autoReconnect  => _autoReconnect;
  String       get protocol       => _protocol;
  String       get elapsedTime    => _elapsedTime;
  int          get retryCount     => _retryCount;
  List<ConnectionLog> get logs    => List.unmodifiable(_logs);

  bool get isConnected    => _status == TunnelStatus.connected;
  bool get isConnecting   => _status == TunnelStatus.connecting;
  bool get isDisconnected => _status == TunnelStatus.disconnected;
  bool get isError        => _status == TunnelStatus.error;

  VpnProvider() {
    _engine = ovpn.OpenVPN(
      onVpnStatusChanged: _onStats,
      onVpnStageChanged:  _onStage,
    );
    _engine.initialize(
      groupIdentifier:          'group.com.mohitw.marianavpn',
      providerBundleIdentifier: 'com.mohitw.marianavpn',
      localizedDescription:     'MarianaVPN',
      lastStage:  (s) => _onStage(s, s.name),
      lastStatus: (s) => _onStats(s),
    );

    // Handle notification actions + VPN permission auto-connect
    NotificationService.init((action) {
      if (action == 'disconnect') disconnect();
      // Auto-connect after VPN permission granted on first time
      if (action == 'permissionGranted' && _permissionPending) {
        _permissionPending = false;
        debugPrint('MarianaVPN: auto-connecting after permission grant');
        _doConnect();
      }
    });

    _loadPrefs();
  }

  void _onStage(ovpn.VPNStage stage, String raw) {
    debugPrint('MarianaVPN stage: $stage');
    switch (stage) {
      case ovpn.VPNStage.connected:
        _connectTimeoutTimer?.cancel();
        _status      = TunnelStatus.connected;
        _connectedAt ??= DateTime.now();
        _retryCount  = 0;
        _cancelRetry();
        _startClock();
        NotificationService.showConnected(
          server: _server.name, flag: _server.flagEmoji,
          ip: _connectedIp, elapsed: _elapsedTime,
          dlSpeed: _dlSpeed, ulSpeed: _ulSpeed);
        break;
      case ovpn.VPNStage.connecting:
      case ovpn.VPNStage.authenticating:
      case ovpn.VPNStage.vpn_generate_config:
      case ovpn.VPNStage.get_config:
      case ovpn.VPNStage.assign_ip:
      case ovpn.VPNStage.prepare:
        if (_status != TunnelStatus.connected) {
          _status = TunnelStatus.connecting;
          NotificationService.showConnecting(_server.name);
        }
        break;
      case ovpn.VPNStage.disconnected:
        _connectTimeoutTimer?.cancel();
        _handleDisconnect();
        break;
      case ovpn.VPNStage.disconnecting:
        _status = TunnelStatus.disconnecting;
        break;
      case ovpn.VPNStage.error:
        _connectTimeoutTimer?.cancel();
        _handleDisconnect(error: 'Connection error');
        break;
      default:
        break;
    }
    notifyListeners();
  }

  void _onStats(ovpn.VpnStatus? s) {
    if (s == null || !isConnected) return;
    final cumIn  = int.tryParse(s.byteIn  ?? '0') ?? 0;
    final cumOut = int.tryParse(s.byteOut ?? '0') ?? 0;
    final now    = DateTime.now();
    if (_lastStatAt != null) {
      final ms = now.difference(_lastStatAt!).inMilliseconds;
      if (ms > 200) {
        final bpsIn  = ((cumIn  - _lastIn ).clamp(0, 999999999) * 1000 / ms).round();
        final bpsOut = ((cumOut - _lastOut).clamp(0, 999999999) * 1000 / ms).round();
        _dlSpeed = _fmtSpeed(bpsIn);
        _ulSpeed = _fmtSpeed(bpsOut);
      }
    }
    if (cumIn  > _totalIn)  _totalIn  = cumIn;
    if (cumOut > _totalOut) _totalOut = cumOut;
    _lastIn = cumIn; _lastOut = cumOut; _lastStatAt = now;
    notifyListeners();
  }

  void _handleDisconnect({String? error}) {
    if (_connectedAt != null) {
      _logs.insert(0, ConnectionLog(
        timestamp: _connectedAt!, serverName: _server.name,
        serverFlag: _server.flagEmoji,
        duration: DateTime.now().difference(_connectedAt!),
        wasSuccessful: error == null, errorMessage: error));
      if (_logs.length > 50) _logs.removeLast();
      _savePrefs();
    }
    _dlSpeed = '0 KB/s'; _ulSpeed = '0 KB/s';
    _lastIn = 0; _lastOut = 0; _lastStatAt = null;
    _connectedAt = null; _elapsedTime = '00:00:00';
    _connectedIp = '---.---.---.---';
    _stopClock();

    if (_userWantsConnect && _autoReconnect && _retryCount < _maxRetries) {
      _status = TunnelStatus.connecting;
      _retryCount++;
      NotificationService.showConnecting(_server.name);
      _retryTimer = Timer(Duration(seconds: 2 + _retryCount * 2), () {
        if (_userWantsConnect) _doConnect();
      });
    } else {
      _status = (error != null && _retryCount >= _maxRetries)
          ? TunnelStatus.error : TunnelStatus.disconnected;
      if (_retryCount >= _maxRetries) _retryCount = 0;
      NotificationService.dismiss();
    }
    notifyListeners();
  }

  void _startClock() {
    _stopClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_connectedAt == null) return;
      final d = DateTime.now().difference(_connectedAt!);
      _elapsedTime =
        '${d.inHours.toString().padLeft(2,'0')}:'
        '${(d.inMinutes%60).toString().padLeft(2,'0')}:'
        '${(d.inSeconds%60).toString().padLeft(2,'0')}';
      // Update notification with speeds every 5s
      if (d.inSeconds % 5 == 0) {
        NotificationService.showConnected(
          server: _server.name, flag: _server.flagEmoji,
          ip: _connectedIp, elapsed: _elapsedTime,
          dlSpeed: _dlSpeed, ulSpeed: _ulSpeed);
      }
      notifyListeners();
    });
  }

  void _stopClock()    { _clockTimer?.cancel();          _clockTimer = null; }
  void _cancelRetry()  { _retryTimer?.cancel();          _retryTimer = null; }
  void _cancelTimeout(){ _connectTimeoutTimer?.cancel(); _connectTimeoutTimer = null; }

  /// Called when VPN permission granted from notification action callback
  void onPermissionGranted() {
    if (_permissionPending && _userWantsConnect) {
      _permissionPending = false;
      _startTunnel();
    }
  }

  Future<void> connect() async {
    if (isConnected || isConnecting) return;
    _userWantsConnect = true;
    _retryCount = 0;
    _totalIn = 0; _totalOut = 0;
    _status = TunnelStatus.connecting;
    notifyListeners();
    NotificationService.showConnecting(_server.name);
    await _doConnect();
  }

  Future<void> _doConnect() async {
    try {
      // Signal native that next VPN permission result should auto-connect
      _permissionPending = true;
      await NotificationService.setPendingConnect();

      final granted = await _engine.requestPermissionAndroid();

      // If permission was already granted (returns true immediately),
      // proceed directly — no need to wait for the callback
      if (granted == true) {
        _permissionPending = false;
        await _startTunnel();
      } else if (granted == false) {
        // User denied
        _permissionPending = false;
        _userWantsConnect = false;
        _status = TunnelStatus.disconnected;
        NotificationService.dismiss();
        notifyListeners();
      }
      // If granted == null, permission dialog shown — wait for onActivityResult callback
    } catch (e) {
      _permissionPending = false;
      debugPrint('MarianaVPN connect error: $e');
      _handleDisconnect(error: e.toString());
    }
  }

  Future<void> _startTunnel() async {
    try {
      final config = await rootBundle.loadString(_server.ovpnAsset);
      await Future.delayed(const Duration(milliseconds: 400));

      debugPrint('MarianaVPN: starting tunnel for ${_server.name}');
      _engine.connect(
        config, _server.name,
        username:       VpnServer.vpnUsername,
        password:       VpnServer.vpnPassword,
        certIsRequired: false,
        bypassPackages: [],
      );

      _cancelTimeout();
      _connectTimeoutTimer = Timer(const Duration(seconds: 25), () {
        if (_status == TunnelStatus.connecting && _userWantsConnect) {
          debugPrint('MarianaVPN: timeout - retrying');
          _engine.disconnect();
          Future.delayed(const Duration(seconds: 2), () {
            if (_userWantsConnect) _doConnect();
          });
        }
      });
    } catch (e) {
      debugPrint('MarianaVPN _startTunnel error: $e');
      _handleDisconnect(error: e.toString());
    }
  }

  Future<void> disconnect() async {
    _userWantsConnect = false;
    _permissionPending = false;
    _cancelRetry(); _cancelTimeout();
    _retryCount = 0;
    if (isDisconnected) return;
    _status = TunnelStatus.disconnecting;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));
    _engine.disconnect();
    NotificationService.dismiss();
  }

  Future<void> selectServer(VpnServer s) async {
    if (isConnected || isConnecting) await disconnect();
    _server = s; _savePrefs(); notifyListeners();
  }

  void setKillSwitch(bool v)    { _killSwitch    = v; _savePrefs(); notifyListeners(); }
  void setDnsLeak(bool v)       { _dnsLeak       = v; _savePrefs(); notifyListeners(); }
  void setAutoReconnect(bool v) { _autoReconnect = v; _savePrefs(); notifyListeners(); }
  void setProtocol(String v)    { _protocol      = v; _savePrefs(); notifyListeners(); }
  void clearLogs()              { _logs.clear();       _savePrefs(); notifyListeners(); }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    _killSwitch    = p.getBool('ks')       ?? false;
    _dnsLeak       = p.getBool('dns')      ?? true;
    _autoReconnect = p.getBool('ar')       ?? true;
    _protocol      = p.getString('proto')  ?? 'UDP';
    final saved    = p.getString('server') ?? '';
    if (saved.isNotEmpty) {
      final m = VpnServer.servers.where((s) => s.name == saved);
      if (m.isNotEmpty) _server = m.first;
    }
    final rawLogs = p.getStringList('logs') ?? [];
    for (final e in rawLogs) {
      try { _logs.add(ConnectionLog.fromJson(jsonDecode(e))); } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('ks', _killSwitch); await p.setBool('dns', _dnsLeak);
    await p.setBool('ar', _autoReconnect); await p.setString('proto', _protocol);
    await p.setString('server', _server.name);
    await p.setStringList('logs', _logs.map((e) => jsonEncode(e.toJson())).toList());
  }

  String _fmtSpeed(int bps) {
    if (bps <= 0)          return '0 KB/s';
    if (bps < 1024)        return '$bps B/s';
    if (bps < 1024 * 1024) return '${(bps / 1024).toStringAsFixed(1)} KB/s';
    return '${(bps / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  String _fmtBytes(int b) {
    if (b <= 0)                 return '0 B';
    if (b < 1024)               return '$b B';
    if (b < 1024 * 1024)        return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  void dispose() {
    _stopClock(); _cancelRetry(); _cancelTimeout();
    super.dispose();
  }
}
