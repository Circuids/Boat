package com.circuids.boat.audio

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log

private const val TAG = "BoatAudioRoute"
private const val SCO_TIMEOUT_MS = 3000L

enum class BoatAudioRoute(val channelName: String) {
    SPEAKER("speaker"),
    EARPIECE("earpiece"),
    BLUETOOTH("bluetooth"),
    WIRED_HEADSET("wiredHeadset"),
    USB("usb");

    companion object {
        fun fromChannelName(name: String): BoatAudioRoute =
            entries.firstOrNull { it.channelName == name } ?: SPEAKER
    }
}

/// Pure route selector: external device wins, else speaker (speakerMode) or preferredRoute.
internal class RoutePolicy(
    val speakerMode: Boolean,
    val preferredRoute: BoatAudioRoute,
) {
    fun selectRoute(connectedExternal: BoatAudioRoute?): BoatAudioRoute {
        if (connectedExternal != null) return connectedExternal
        return if (speakerMode) BoatAudioRoute.SPEAKER else preferredRoute
    }
}

/**
 * Audio routing with modern API 31+ and legacy fallback.
 * Priority: Bluetooth > Wired > USB > Speaker/Earpiece.
 */
class AudioRouteManager(
    private val context: Context,
    private val audioManager: AudioManager,
    private val onRouteChanged: (BoatAudioRoute) -> Unit,
) {
    private val handler = Handler(Looper.getMainLooper())
    private var deviceCallback: AudioDeviceCallback? = null
    private var legacyReceiver: BroadcastReceiver? = null
    private var routePolicy: RoutePolicy? = null

    private var consumerOverride: BoatAudioRoute? = null // cleared when an external device connects
    private var scoTimeoutRunnable: Runnable? = null

    @Volatile
    var currentRoute: BoatAudioRoute = BoatAudioRoute.SPEAKER
        private set

    internal fun setPolicy(policy: RoutePolicy) {
        routePolicy = policy
    }

    /**
     * Apply policy to the OS. [force] re-applies even when the selection is unchanged —
     * required at start, where [start] only detects (no OS call) and the OS default
     * (earpiece in MODE_IN_COMMUNICATION, unestablished legacy SCO) differs from the field.
     */
    internal fun applyPolicy(force: Boolean = false) {
        val policy = routePolicy ?: return
        val external = detectConnectedExternal()
        if (external != null) consumerOverride = null // external always wins
        val selected = consumerOverride ?: policy.selectRoute(external)
        if (force || selected != currentRoute) {
            applyRouteToDevice(selected)
        }
    }

    fun start() {
        registerDeviceCallback() // before detection so no change is missed
        currentRoute = detectCurrentRoute() // seeds field only; OS apply is applyPolicy(force=true)
    }

    /// Consumer selection; persists across device changes until an external device connects.
    fun setRoute(route: BoatAudioRoute) {
        consumerOverride = route
        applyRouteToDevice(route)
    }

    private fun applyRouteToDevice(route: BoatAudioRoute) {
        cancelScoTimeout()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!setRouteModern(route)) {
                Log.w(TAG, "setCommunicationDevice failed for $route, falling back to legacy path")
                setRouteLegacy(route)
            }
        } else {
            setRouteLegacy(route)
        }
        currentRoute = route
        onRouteChanged(route)
    }

    fun getAvailableRoutes(): List<BoatAudioRoute> {
        val routes = mutableListOf(BoatAudioRoute.SPEAKER, BoatAudioRoute.EARPIECE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.availableCommunicationDevices.forEach { device ->
                when (device.type) {
                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> routes.add(BoatAudioRoute.BLUETOOTH)
                    AudioDeviceInfo.TYPE_WIRED_HEADSET -> routes.add(BoatAudioRoute.WIRED_HEADSET)
                    AudioDeviceInfo.TYPE_USB_HEADSET -> routes.add(BoatAudioRoute.USB)
                }
            }
        }
        return routes.distinct()
    }

    fun stop() {
        cancelScoTimeout()
        deviceCallback?.let { audioManager.unregisterAudioDeviceCallback(it) }
        deviceCallback = null
        legacyReceiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
                // Receiver may already be unregistered — safe during double-teardown.
            }
        }
        legacyReceiver = null
    }

    private fun registerDeviceCallback() {
        val callback = object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(addedDevices: Array<AudioDeviceInfo>) {
                handler.post { handleDeviceChange() }
            }

            override fun onAudioDevicesRemoved(removedDevices: Array<AudioDeviceInfo>) {
                handler.post { handleDeviceChange() }
            }
        }
        audioManager.registerAudioDeviceCallback(callback, handler)
        deviceCallback = callback

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            registerLegacyReceiver()
        }
    }

    private fun registerLegacyReceiver() {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                handler.post { handleDeviceChange() }
            }
        }
        val filter = IntentFilter().apply {
            addAction(AudioManager.ACTION_HEADSET_PLUG)
            addAction("android.bluetooth.headset.profile.action.CONNECTION_STATE_CHANGED")
        }
        context.registerReceiver(receiver, filter)
        legacyReceiver = receiver
    }

    private fun handleDeviceChange() {
        if (routePolicy != null) {
            applyPolicy()
        } else {
            val newRoute = detectCurrentRoute()
            if (newRoute != currentRoute) {
                currentRoute = newRoute
                onRouteChanged(newRoute)
            }
        }
    }

    /// Connected external device (BT > Wired > USB) or null.
    private fun detectConnectedExternal(): BoatAudioRoute? {
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        return when {
            devices.any { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO } -> BoatAudioRoute.BLUETOOTH
            devices.any { it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET } -> BoatAudioRoute.WIRED_HEADSET
            devices.any { it.type == AudioDeviceInfo.TYPE_USB_HEADSET } -> BoatAudioRoute.USB
            else -> null
        }
    }

    /// True if Bluetooth SCO is actually carrying communication audio (Phone Link
    /// call, car kit, or a headset in call mode). When active, VOICE_COMMUNICATION
    /// capture couples to 8 kHz narrowband — consumers can warn about degraded quality.
    ///
    /// On API 31+ this uses [AudioManager.getCommunicationDevice], the authoritative
    /// replacement for the deprecated [AudioManager.isBluetoothScoOn]. It reflects the
    /// device actually selected for communication routing (Boat sets it explicitly at
    /// start), so HFP-capable buds playing over A2DP correctly report false. The
    /// deprecated isBluetoothScoOn gives a false positive there because the HFP/SCO
    /// profile stays connected even while audio flows over A2DP (e.g. Galaxy Buds).
    fun isScoDeviceConnected(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val type = audioManager.communicationDevice?.type
            if (type != null) return type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO
            // No explicit communication selection — fall through to the legacy signal.
        }
        @Suppress("DEPRECATION")
        return audioManager.isBluetoothScoOn
    }

    private fun detectCurrentRoute(): BoatAudioRoute {
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        val hasBluetooth = devices.any { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO }
        val hasWired = devices.any { it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET }
        val hasUsb = devices.any { it.type == AudioDeviceInfo.TYPE_USB_HEADSET }

        return when {
            hasBluetooth -> BoatAudioRoute.BLUETOOTH
            hasWired -> BoatAudioRoute.WIRED_HEADSET
            hasUsb -> BoatAudioRoute.USB
            else -> BoatAudioRoute.SPEAKER
        }
    }

    /// True if the device was set successfully.
    private fun setRouteModern(route: BoatAudioRoute): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        val targetType = when (route) {
            BoatAudioRoute.BLUETOOTH -> AudioDeviceInfo.TYPE_BLUETOOTH_SCO
            BoatAudioRoute.WIRED_HEADSET -> AudioDeviceInfo.TYPE_WIRED_HEADSET
            BoatAudioRoute.USB -> AudioDeviceInfo.TYPE_USB_HEADSET
            BoatAudioRoute.EARPIECE -> AudioDeviceInfo.TYPE_BUILTIN_EARPIECE
            BoatAudioRoute.SPEAKER -> AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
        }
        val device = audioManager.availableCommunicationDevices
            .firstOrNull { it.type == targetType }
        if (device != null) {
            val ok = audioManager.setCommunicationDevice(device)
            if (!ok) Log.w(TAG, "setCommunicationDevice returned false for $route")
            return ok
        }
        // External device absent → nothing to select; OS default is correct.
        if (route != BoatAudioRoute.SPEAKER && route != BoatAudioRoute.EARPIECE) {
            audioManager.clearCommunicationDevice()
            return true
        }
        // Builtin speaker/earpiece missing: clear would reset to the OS default
        // (earpiece in MODE_IN_COMMUNICATION), so signal failure → legacy fallback.
        Log.w(TAG, "builtin device for $route not in availableCommunicationDevices")
        return false
    }

    @Suppress("DEPRECATION")
    private fun setRouteLegacy(route: BoatAudioRoute) {
        when (route) {
            BoatAudioRoute.BLUETOOTH -> {
                audioManager.startBluetoothSco()
                audioManager.isBluetoothScoOn = true
                audioManager.isSpeakerphoneOn = false
                scheduleScoTimeout()
            }
            BoatAudioRoute.SPEAKER -> {
                audioManager.stopBluetoothSco()
                audioManager.isBluetoothScoOn = false
                audioManager.isSpeakerphoneOn = true
            }
            BoatAudioRoute.EARPIECE -> {
                audioManager.stopBluetoothSco()
                audioManager.isBluetoothScoOn = false
                audioManager.isSpeakerphoneOn = false
            }
            else -> { /* wired/usb handled by OS */ }
        }
    }

    /// Falls back to speaker if SCO isn't up within the timeout.
    @Suppress("DEPRECATION")
    private fun scheduleScoTimeout() {
        val runnable = Runnable {
            if (currentRoute == BoatAudioRoute.BLUETOOTH && !audioManager.isBluetoothScoOn) {
                Log.w(TAG, "Bluetooth SCO timeout (${SCO_TIMEOUT_MS}ms) — falling back to speaker")
                consumerOverride = null
                applyRouteToDevice(BoatAudioRoute.SPEAKER)
            }
        }
        scoTimeoutRunnable = runnable
        handler.postDelayed(runnable, SCO_TIMEOUT_MS)
    }

    private fun cancelScoTimeout() {
        scoTimeoutRunnable?.let { handler.removeCallbacks(it) }
        scoTimeoutRunnable = null
    }
}
