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
            val effect = AcousticEchoCanceler.create(sessionId)
            if (effect != null) {
                aec = effect
                try {
                    effect.enabled = true
                } catch (_: RuntimeException) {
                    // enabled = true can throw on some devices — the
                    // effect is attached but inactive; report via status.
                }
            }
        }
        if (enableAgc && AutomaticGainControl.isAvailable()) {
            val effect = AutomaticGainControl.create(sessionId)
            if (effect != null) {
                agc = effect
                try {
                    effect.enabled = true
                } catch (_: RuntimeException) {
                }
            }
        }
        if (enableNs && NoiseSuppressor.isAvailable()) {
            val effect = NoiseSuppressor.create(sessionId)
            if (effect != null) {
                ns = effect
                try {
                    effect.enabled = true
                } catch (_: RuntimeException) {
                }
            }
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
        // Disable before release to cleanly detach from the audio session.
        aec?.let { it.enabled = false; it.release() }
        agc?.let { it.enabled = false; it.release() }
        ns?.let { it.enabled = false; it.release() }
        aec = null
        agc = null
        ns = null
    }
}
