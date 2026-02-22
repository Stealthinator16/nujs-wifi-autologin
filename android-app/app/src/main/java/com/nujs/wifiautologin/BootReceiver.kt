package com.nujs.wifiautologin

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // Only auto-start if credentials are saved
            try {
                val prefs = androidx.security.crypto.EncryptedSharedPreferences.create(
                    LoginService.PREFS_FILE,
                    androidx.security.crypto.MasterKeys.getOrCreate(
                        androidx.security.crypto.MasterKeys.AES256_GCM_SPEC
                    ),
                    context,
                    androidx.security.crypto.EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    androidx.security.crypto.EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
                )
                val username = prefs.getString(LoginService.KEY_USERNAME, "") ?: ""
                val password = prefs.getString(LoginService.KEY_PASSWORD, "") ?: ""
                if (username.isNotBlank() && password.isNotBlank()) {
                    ContextCompat.startForegroundService(
                        context,
                        Intent(context, LoginService::class.java)
                    )
                }
            } catch (_: Exception) {}
        }
    }
}
