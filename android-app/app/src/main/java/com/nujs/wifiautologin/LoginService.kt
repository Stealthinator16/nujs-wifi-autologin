package com.nujs.wifiautologin

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiInfo
import android.os.Build
import android.os.IBinder
import androidx.core.content.ContextCompat
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

class LoginService : Service() {

    companion object {
        const val CHANNEL_ID = "nujs_autologin_channel"
        const val NOTIF_ID = 1
        const val ACTION_LOG = "com.nujs.wifiautologin.LOG"
        const val EXTRA_MESSAGE = "message"
        const val PREFS_FILE = "nujs_credentials"
        const val KEY_USERNAME = "username"
        const val KEY_PASSWORD = "password"
        const val TARGET_SSID = "NUJS-CAMPUS WiFi"
    }

    private val executor = Executors.newSingleThreadExecutor()
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var isReceiverRegistered = false

    private val screenUnlockReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_USER_PRESENT) {
                log("Screen unlocked — checking login")
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                val network = cm.activeNetwork
                if (network != null) {
                    attemptLogin(network)
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIF_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            )
        } else {
            startForeground(NOTIF_ID, notification)
        }
        
        registerReceivers()
        log("Service active — monitoring $TARGET_SSID")
        
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = cm.activeNetwork
        if (network != null) {
            attemptLogin(network)
        }
        
        return START_STICKY
    }

    override fun onDestroy() {
        unregisterReceivers()
        log("Service stopped")
        executor.shutdownNow()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun registerReceivers() {
        if (isReceiverRegistered) return

        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .build()
        
        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                log("WiFi available — checking login on WiFi network")
                attemptLogin(network)
            }
        }
        cm.registerNetworkCallback(request, networkCallback!!)

        ContextCompat.registerReceiver(
            this,
            screenUnlockReceiver,
            IntentFilter(Intent.ACTION_USER_PRESENT),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
        isReceiverRegistered = true
    }

    private fun unregisterReceivers() {
        if (!isReceiverRegistered) return

        networkCallback?.let {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            try {
                cm.unregisterNetworkCallback(it)
            } catch (e: Exception) {}
            networkCallback = null
        }
        try {
            unregisterReceiver(screenUnlockReceiver)
        } catch (e: Exception) {}
        isReceiverRegistered = false
    }

    private fun attemptLogin(network: Network) {
        executor.execute {
            try {
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                val capabilities = cm.getNetworkCapabilities(network) ?: return@execute
                
                // Ensure we are only operating on WiFi
                if (!capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                    return@execute
                }

                val ssid = getSsidFromCapabilities(capabilities)
                if (ssid != null && !ssid.contains(TARGET_SSID)) {
                    log("On '$ssid', not $TARGET_SSID — skipping")
                    return@execute
                }

                // Check internet specifically on the WiFi network
                if (PortalClient.isInternetWorking(network)) {
                    log("Internet already working on WiFi")
                    return@execute
                }

                var portalReady = false
                for (attempt in 1..5) {
                    if (PortalClient.isPortalReachable(network)) {
                        portalReady = true
                        break
                    }
                    log("Waiting for portal... attempt $attempt/5")
                    Thread.sleep(3_000)
                }

                if (!portalReady) {
                    log("Portal not reachable on WiFi")
                    return@execute
                }

                val creds = getCredentials()
                if (creds == null) {
                    log("No credentials saved")
                    return@execute
                }

                log("Logging in as ${creds.first} on WiFi...")
                val result = PortalClient.login(creds.first, creds.second, network)
                if (result.success) {
                    log("Logged in successfully!")
                } else {
                    log("Login failed: ${result.message}")
                }
            } catch (e: Exception) {
                log("Error: ${e.message}")
            }
        }
    }

    private fun getSsidFromCapabilities(capabilities: NetworkCapabilities): String? {
        val wifiInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            capabilities.transportInfo as? WifiInfo
        } else {
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as android.net.wifi.WifiManager
            @Suppress("DEPRECATION")
            wm.connectionInfo
        }
        
        val ssid = wifiInfo?.ssid?.removeSurrounding("\"")
        return if (ssid == "<unknown ssid>" || ssid == null) null else ssid
    }

    private fun getCredentials(): Pair<String, String>? {
        return try {
            val prefs = EncryptedSharedPreferences.create(
                PREFS_FILE,
                MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC),
                this,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
            val u = prefs.getString(KEY_USERNAME, "") ?: ""
            val p = prefs.getString(KEY_PASSWORD, "") ?: ""
            if (u.isBlank() || p.isBlank()) null else Pair(u, p)
        } catch (e: Exception) {
            null
        }
    }

    private fun log(msg: String) {
        val ts = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date())
        val line = "[$ts] $msg"
        sendBroadcast(Intent(ACTION_LOG).apply {
            setPackage(packageName)
            putExtra(EXTRA_MESSAGE, line)
        })
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.notif_channel_name),
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            setShowBadge(false)
        }
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val openIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        val builder = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.notif_title))
            .setContentText(getString(R.string.notif_text))
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(openIntent)
            .setOngoing(true)
            
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        
        return builder.build()
    }
}
