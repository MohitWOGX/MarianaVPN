package com.mohitw.marianavpn

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import id.laskarmedia.openvpn_flutter.OpenVPNFlutterPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG            = "MarianaVPN"
        private const val VPN_CHANNEL    = "com.mohitw.marianavpn/vpn"
        private const val NOTIF_CH_ID    = "mariana_vpn_status"
        private const val NOTIF_ID       = 2001
        private const val NOTIF_PERM_REQ = 3001
        const val ACTION_DISCONNECT      = "com.mohitw.marianavpn.DISCONNECT"
    }

    private var methodChannel: MethodChannel? = null
    // Track if we should auto-connect after VPN permission granted
    private var pendingConnect = false

    private val notifReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == ACTION_DISCONNECT) {
                methodChannel?.invokeMethod("notifAction", "disconnect")
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        createNotifChannel()
        val filter = IntentFilter().apply { addAction(ACTION_DISCONNECT) }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(notifReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(notifReceiver, filter)
        }
    }

    override fun onDestroy() {
        try { unregisterReceiver(notifReceiver) } catch (_: Exception) {}
        super.onDestroy()
    }

    // ── KEY FIX: Auto-connect after VPN permission dialog ─────────────────
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == 24) {
            val granted = resultCode == RESULT_OK
            OpenVPNFlutterPlugin.connectWhileGranted(granted)
            // If user tapped OK on VPN permission dialog, signal Flutter to proceed
            if (granted && pendingConnect) {
                pendingConnect = false
                methodChannel?.invokeMethod("vpnPermissionGranted", null)
                Log.d(TAG, "VPN permission granted - auto connecting")
            }
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIF_PERM_REQ) {
            Log.d(TAG, "Notification permission: ${grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED}")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VPN_CHANNEL)
        methodChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (ContextCompat.checkSelfPermission(this,
                                Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            ActivityCompat.requestPermissions(this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIF_PERM_REQ)
                        }
                    }
                    result.success(null)
                }
                "setPendingConnect" -> {
                    pendingConnect = true
                    result.success(null)
                }
                "showConnected" -> {
                    showConnectedNotif(
                        call.argument("server")  ?: "",
                        call.argument("flag")    ?: "",
                        call.argument("ip")      ?: "---",
                        call.argument("elapsed") ?: "00:00:00",
                        call.argument("dlSpeed") ?: "0 KB/s",
                        call.argument("ulSpeed") ?: "0 KB/s"
                    )
                    result.success(null)
                }
                "showConnecting" -> {
                    showConnectingNotif(call.argument("server") ?: "")
                    result.success(null)
                }
                "dismissNotif" -> { dismissNotif(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    // ── Single combined notification ───────────────────────────────────────
    private fun showConnectedNotif(
        server: String, flag: String, ip: String,
        elapsed: String, dlSpeed: String, ulSpeed: String
    ) {
        if (!canNotify()) return
        val disconnectPi = PendingIntent.getBroadcast(
            this, 1, Intent(ACTION_DISCONNECT),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        // Single line: flag + server name
        // Big text: IP, speeds, duration
        val bigText = "IP: $ip\n↓ $dlSpeed   ↑ $ulSpeed\nDuration: $elapsed"

        val notif = NotificationCompat.Builder(this, NOTIF_CH_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("$flag  $server — Protected")
            .setContentText("$ip  •  ↓$dlSpeed  ↑$ulSpeed")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(openAppPi())
            .setColor(0xFF00E5A0.toInt())
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Disconnect", disconnectPi)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .build()

        NotificationManagerCompat.from(this).notify(NOTIF_ID, notif)
    }

    private fun showConnectingNotif(server: String) {
        if (!canNotify()) return
        val cancelPi = PendingIntent.getBroadcast(
            this, 2, Intent(ACTION_DISCONNECT),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val notif = NotificationCompat.Builder(this, NOTIF_CH_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("MarianaVPN")
            .setContentText("Connecting to $server...")
            .setOngoing(true).setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setProgress(0, 0, true)
            .setContentIntent(openAppPi())
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Cancel", cancelPi)
            .build()

        NotificationManagerCompat.from(this).notify(NOTIF_ID, notif)
    }

    private fun dismissNotif() = NotificationManagerCompat.from(this).cancel(NOTIF_ID)

    private fun canNotify(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this,
                Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else true
    }

    private fun openAppPi() = PendingIntent.getActivity(
        this, 0,
        Intent(this, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun createNotifChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(NOTIF_CH_ID, "VPN Status",
                NotificationManager.IMPORTANCE_LOW).apply {
                description = "MarianaVPN connection status"
                setShowBadge(false); enableLights(false); enableVibration(false)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }
    }
}
