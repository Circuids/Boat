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

    var currentRoute: BoatAudioRoute = BoatAudioRoute.SPEAKER
        private set

    fun start() {
        registerDeviceCallback()
        currentRoute = detectCurrentRoute()
    }

    fun setRoute(route: BoatAudioRoute) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            setRouteModern(route)
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
        deviceCallback?.let { audioManager.unregisterAudioDeviceCallback(it) }
        deviceCallback = null
        legacyReceiver?.let { context.unregisterReceiver(it) }
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
        val newRoute = detectCurrentRoute()
        if (newRoute != currentRoute) {
            currentRoute = newRoute
            onRouteChanged(newRoute)
        }
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

    private fun setRouteModern(route: BoatAudioRoute) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
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
            audioManager.setCommunicationDevice(device)
        } else {
            audioManager.clearCommunicationDevice()
        }
    }

    @Suppress("DEPRECATION")
    private fun setRouteLegacy(route: BoatAudioRoute) {
        when (route) {
            BoatAudioRoute.BLUETOOTH -> {
                audioManager.startBluetoothSco()
                audioManager.isBluetoothScoOn = true
                audioManager.isSpeakerphoneOn = false
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
}
