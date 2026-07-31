package com.circuids.boat.permission

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.collection.SparseArrayCompat
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.PluginRegistry

class PermissionManager(
    private val context: Context,
) : PluginRegistry.RequestPermissionsResultListener {

    companion object {
        private const val REQUEST_CODE_BASE = 19847
    }

    private var activity: Activity? = null
    private var nextRequestCode = REQUEST_CODE_BASE

    private data class PendingRequest(
        val permission: String,
        val result: io.flutter.plugin.common.MethodChannel.Result,
    )

    // Queue of pending permission requests keyed by request code —
    // concurrent requests each get a unique code and callback.
    private val pendingRequests = SparseArrayCompat<PendingRequest>()

    fun setActivity(activity: Activity?) {
        this.activity = activity
    }

    fun check(type: String): String {
        return when (type) {
            "microphone" -> checkAndroidPermission(Manifest.permission.RECORD_AUDIO)
            "bluetoothConnect" -> checkBluetooth()
            else -> "denied"
        }
    }

    fun request(type: String, result: io.flutter.plugin.common.MethodChannel.Result) {
        when (type) {
            "microphone" -> requestAndroidPermission(Manifest.permission.RECORD_AUDIO, result)
            "bluetoothConnect" -> requestBluetooth(result)
            else -> result.success("denied")
        }
    }

    fun openSettings() {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", context.packageName, null),
        )
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        val pending = pendingRequests.get(requestCode) ?: return false
        pendingRequests.remove(requestCode)

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED

        if (granted) {
            pending.result.success("granted")
            return true
        }

        val act = activity
        val permanentlyDenied = act != null &&
            !ActivityCompat.shouldShowRequestPermissionRationale(act, pending.permission)
        pending.result.success(if (permanentlyDenied) "permanentlyDenied" else "denied")
        return true
    }

    private fun checkAndroidPermission(permission: String): String {
        return if (ContextCompat.checkSelfPermission(context, permission)
            == PackageManager.PERMISSION_GRANTED
        ) {
            "granted"
        } else {
            "denied"
        }
    }

    private fun requestAndroidPermission(
        permission: String,
        result: io.flutter.plugin.common.MethodChannel.Result,
    ) {
        val act = activity
        if (act == null) {
            result.success("denied")
            return
        }

        if (ContextCompat.checkSelfPermission(context, permission)
            == PackageManager.PERMISSION_GRANTED
        ) {
            result.success("granted")
            return
        }

        val requestCode = nextRequestCode++
        pendingRequests.put(requestCode, PendingRequest(permission, result))
        ActivityCompat.requestPermissions(act, arrayOf(permission), requestCode)
    }

    private fun checkBluetooth(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return "granted"
        return checkAndroidPermission(Manifest.permission.BLUETOOTH_CONNECT)
    }

    private fun requestBluetooth(result: io.flutter.plugin.common.MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            result.success("granted")
            return
        }
        requestAndroidPermission(Manifest.permission.BLUETOOTH_CONNECT, result)
    }
}
