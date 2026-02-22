package com.nujs.wifiautologin

import android.net.Network
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import javax.xml.parsers.DocumentBuilderFactory

object PortalClient {

    private const val PORTAL_BASE = "http://172.24.66.1:8090"

    data class LoginResult(val success: Boolean, val status: String, val message: String)

    /**
     * POST to the Sophos/Cyberoam captive portal login endpoint.
     * Returns a LoginResult with parsed XML status + message.
     */
    fun login(username: String, password: String, network: Network? = null): LoginResult {
        return try {
            val params = "mode=191" +
                "&username=${java.net.URLEncoder.encode(username, "UTF-8")}" +
                "&password=${java.net.URLEncoder.encode(password, "UTF-8")}" +
                "&a=${System.currentTimeMillis()}" +
                "&producttype=0"

            val url = URL("$PORTAL_BASE/login.xml")
            val conn = (network?.openConnection(url) ?: url.openConnection()) as HttpURLConnection
            conn.requestMethod = "POST"
            conn.doOutput = true
            conn.connectTimeout = 10_000
            conn.readTimeout = 10_000
            conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
            conn.outputStream.use { it.write(params.toByteArray()) }

            val body = conn.inputStream.bufferedReader().use { it.readText() }
            conn.disconnect()

            val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder()
                .parse(body.byteInputStream())
            val status = doc.getElementsByTagName("status").item(0)?.textContent?.trim() ?: ""
            val message = doc.getElementsByTagName("message").item(0)?.textContent?.trim() ?: ""

            LoginResult(success = status == "LIVE", status = status, message = message)
        } catch (e: Exception) {
            LoginResult(success = false, status = "ERROR", message = e.message ?: "Unknown error")
        }
    }

    /**
     * POST logout (mode=193) to the portal.
     */
    fun logout(username: String, network: Network? = null): LoginResult {
        return try {
            val params = "mode=193" +
                "&username=${java.net.URLEncoder.encode(username, "UTF-8")}" +
                "&a=${System.currentTimeMillis()}" +
                "&producttype=0"

            val url = URL("$PORTAL_BASE/logout.xml")
            val conn = (network?.openConnection(url) ?: url.openConnection()) as HttpURLConnection
            conn.requestMethod = "POST"
            conn.doOutput = true
            conn.connectTimeout = 10_000
            conn.readTimeout = 10_000
            conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
            conn.outputStream.use { it.write(params.toByteArray()) }

            val body = conn.inputStream.bufferedReader().use { it.readText() }
            conn.disconnect()

            val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder()
                .parse(body.byteInputStream())
            val status = doc.getElementsByTagName("status").item(0)?.textContent?.trim() ?: ""
            val message = doc.getElementsByTagName("message").item(0)?.textContent?.trim() ?: ""

            LoginResult(success = true, status = status, message = message)
        } catch (e: Exception) {
            LoginResult(success = false, status = "ERROR", message = e.message ?: "Unknown error")
        }
    }

    /**
     * Check if internet is actually working (not just captive-portal-redirected).
     */
    fun isInternetWorking(network: Network? = null): Boolean {
        return try {
            val url = URL("http://connectivitycheck.gstatic.com/generate_204")
            val conn = (network?.openConnection(url) ?: url.openConnection()) as HttpURLConnection
            conn.connectTimeout = 5_000
            conn.readTimeout = 5_000
            conn.instanceFollowRedirects = false
            val code = conn.responseCode
            conn.disconnect()
            code == 204
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Check if the captive portal is reachable (meaning we're on the NUJS network).
     */
    fun isPortalReachable(network: Network? = null): Boolean {
        return try {
            val url = URL(PORTAL_BASE)
            val conn = (network?.openConnection(url) ?: url.openConnection()) as HttpURLConnection
            conn.connectTimeout = 3_000
            conn.readTimeout = 3_000
            conn.responseCode
            conn.disconnect()
            true
        } catch (e: Exception) {
            false
        }
    }
}
