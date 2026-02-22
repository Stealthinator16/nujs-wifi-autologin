package com.nujs.wifiautologin

import android.Manifest
import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.res.ColorStateList
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.widget.Button
import android.widget.EditText
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
import com.google.android.material.button.MaterialButton
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

class MainActivity : AppCompatActivity() {

    companion object {
        private const val PERM_REQUEST = 100
        private const val KEY_LOG_TEXT = "log_text"
    }

    private lateinit var editUsername: EditText
    private lateinit var editPassword: EditText
    private lateinit var btnConnect: MaterialButton
    private lateinit var btnDisconnect: MaterialButton
    private lateinit var txtLog: TextView
    private lateinit var scrollLog: ScrollView

    private val executor = Executors.newSingleThreadExecutor()

    private val logReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val msg = intent.getStringExtra(LoginService.EXTRA_MESSAGE) ?: return
            appendLog(msg)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        editUsername = findViewById(R.id.editUsername)
        editPassword = findViewById(R.id.editPassword)
        btnConnect = findViewById(R.id.btnConnect)
        btnDisconnect = findViewById(R.id.btnDisconnect)
        txtLog = findViewById(R.id.txtLog)
        scrollLog = findViewById(R.id.scrollLog)

        loadCredentials()

        btnConnect.setOnClickListener { startService() }
        btnDisconnect.setOnClickListener { disconnect() }

        requestPermissions()
        requestBatteryOptimizationExemption()

        if (savedInstanceState != null) {
            txtLog.text = savedInstanceState.getString(KEY_LOG_TEXT, "")
            scrollLog.post { scrollLog.fullScroll(ScrollView.FOCUS_DOWN) }
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putString(KEY_LOG_TEXT, txtLog.text.toString())
    }

    override fun onResume() {
        super.onResume()
        ContextCompat.registerReceiver(
            this, logReceiver,
            IntentFilter(LoginService.ACTION_LOG),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
        updateButtonStates()
    }

    override fun onPause() {
        super.onPause()
        unregisterReceiver(logReceiver)
    }

    private fun updateButtonStates() {
        val running = isServiceRunning(LoginService::class.java)
        if (running) {
            btnConnect.text = getString(R.string.btn_connected)
            btnConnect.isEnabled = false
            btnConnect.icon = ContextCompat.getDrawable(this, android.R.drawable.checkbox_on_background)
            
            // Highlight Disconnect as the active action
            btnDisconnect.setBackgroundTintList(ColorStateList.valueOf(Color.parseColor("#D32F2F"))) // Material Red 700
            btnDisconnect.setTextColor(Color.WHITE)
        } else {
            btnConnect.text = getString(R.string.btn_connect)
            btnConnect.isEnabled = true
            btnConnect.icon = null
            
            // Reset to default Material 3 styles
            btnConnect.setBackgroundTintList(ColorStateList.valueOf(Color.parseColor("#1976D2"))) // Material Blue 700
            btnConnect.setTextColor(Color.WHITE)
            
            // Reset Disconnect to Tonal style
            btnDisconnect.setBackgroundTintList(null) 
            btnDisconnect.setTextColor(Color.parseColor("#1976D2"))
        }
    }

    private fun isServiceRunning(serviceClass: Class<*>): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        @Suppress("DEPRECATION")
        for (service in manager.getRunningServices(Int.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
    }

    private fun requestPermissions() {
        val needed = mutableListOf<String>()
        needed.add(Manifest.permission.ACCESS_FINE_LOCATION)
        if (Build.VERSION.SDK_INT >= 33) {
            needed.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        val missing = needed.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, missing.toTypedArray(), PERM_REQUEST)
        }
    }

    private fun requestBatteryOptimizationExemption() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            } catch (e: Exception) {
                appendLog("[${timestamp()}] Warning: Could not request battery optimization exemption")
            }
        }
    }

    private fun startService() {
        saveCredentials()
        val username = editUsername.text.toString().trim()
        val password = editPassword.text.toString().trim()
        if (username.isEmpty() || password.isEmpty()) {
            Toast.makeText(this, "Enter username and password first", Toast.LENGTH_SHORT).show()
            return
        }
        appendLog("[${timestamp()}] Starting service...")
        ContextCompat.startForegroundService(this, Intent(this, LoginService::class.java))
        btnConnect.postDelayed({ updateButtonStates() }, 500)
    }

    private fun disconnect() {
        val username = editUsername.text.toString().trim()
        appendLog("[${timestamp()}] Disconnecting...")
        
        executor.execute {
            if (username.isNotEmpty()) {
                val result = PortalClient.logout(username)
                post {
                    appendLog("[${timestamp()}] Logout request sent. Result: ${result.message}")
                    appendLog("[${timestamp()}] Stopping service...")
                    stopService(Intent(this, LoginService::class.java))
                    updateButtonStates()
                }
            } else {
                post {
                    appendLog("[${timestamp()}] No username, just stopping service...")
                    stopService(Intent(this, LoginService::class.java))
                    updateButtonStates()
                }
            }
        }
    }

    private fun loadCredentials() {
        val prefs = getEncryptedPrefs()
        editUsername.setText(prefs.getString(LoginService.KEY_USERNAME, ""))
        editPassword.setText(prefs.getString(LoginService.KEY_PASSWORD, ""))
    }

    private fun saveCredentials() {
        val prefs = getEncryptedPrefs()
        prefs.edit()
            .putString(LoginService.KEY_USERNAME, editUsername.text.toString().trim())
            .putString(LoginService.KEY_PASSWORD, editPassword.text.toString().trim())
            .apply()
    }

    private fun getEncryptedPrefs() = EncryptedSharedPreferences.create(
        LoginService.PREFS_FILE,
        MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC),
        this,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    private fun appendLog(msg: String) {
        txtLog.append("$msg\n")
        scrollLog.post { scrollLog.fullScroll(ScrollView.FOCUS_DOWN) }
    }

    private fun post(action: () -> Unit) {
        runOnUiThread(action)
    }

    private fun timestamp(): String =
        SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date())
}
