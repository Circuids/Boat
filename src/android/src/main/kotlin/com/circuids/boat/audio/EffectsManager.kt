package com.circuids.boat.audio

import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor

data class EffectState(
    val supported: Boolean,
    val available: Boolean,
    val active: Boolean,
)

/**
 * Attaches OS audio effects (AEC/AGC/NS) to a shared audio session ID.
 */
class EffectsManager {

    private var aec: AcousticEchoCanceler? = null
    private var agc: AutomaticGainControl? = null
    private var ns: NoiseSuppressor? = null

    fun attach(sessionId: Int, enableAec: Boolean, enableAgc: Boolean, enableNs: Boolean) {
        if (enableAec && AcousticEchoCanceler.isAvailable()) {
            aec = AcousticEchoCanceler.create(sessionId)?.apply { enabled = true }
        }
        if (enableAgc && AutomaticGainControl.isAvailable()) {
            agc = AutomaticGainControl.create(sessionId)?.apply { enabled = true }
        }
        if (enableNs && NoiseSuppressor.isAvailable()) {
            ns = NoiseSuppressor.create(sessionId)?.apply { enabled = true }
        }
    }

    fun getStatus(): Map<String, EffectState> = mapOf(
        "aec" to EffectState(
            supported = AcousticEchoCanceler.isAvailable(),
            available = aec != null,
            active = aec?.enabled ?: false,
        ),
        "agc" to EffectState(
            supported = AutomaticGainControl.isAvailable(),
            available = agc != null,
            active = agc?.enabled ?: false,
        ),
        "noiseSuppression" to EffectState(
            supported = NoiseSuppressor.isAvailable(),
            available = ns != null,
            active = ns?.enabled ?: false,
        ),
    )

    fun release() {
        aec?.release()
        agc?.release()
        ns?.release()
        aec = null
        agc = null
        ns = null
    }
}
