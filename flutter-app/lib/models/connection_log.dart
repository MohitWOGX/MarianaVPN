import 'dart:convert';

class ConnectionLog {
  final DateTime timestamp;
  final String serverName;
  final String serverFlag;
  final Duration duration;
  final bool wasSuccessful;
  final String? errorMessage;

  ConnectionLog({
    required this.timestamp,
    required this.serverName,
    required this.serverFlag,
    required this.duration,
    required this.wasSuccessful,
    this.errorMessage,
  });

  String get formattedDate {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String get formattedDuration {
    final h = duration.inHours.toString().padLeft(2, '0');
    final m = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'serverName': serverName,
    'serverFlag': serverFlag,
    'durationSeconds': duration.inSeconds,
    'wasSuccessful': wasSuccessful,
    'errorMessage': errorMessage,
  };

  factory ConnectionLog.fromJson(Map<String, dynamic> j) => ConnectionLog(
    timestamp: DateTime.parse(j['timestamp']),
    serverName: j['serverName'],
    serverFlag: j['serverFlag'],
    duration: Duration(seconds: j['durationSeconds']),
    wasSuccessful: j['wasSuccessful'],
    errorMessage: j['errorMessage'],
  );
}
