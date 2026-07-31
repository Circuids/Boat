package com.circuids.boat.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager

/**
 * Manages MODE_IN_COMMUNICATION and audio focus lifecycle.
 * Mode must be set BEFORE creating AudioRecord for AEC coupling.
 */
class AudioSessionManager(context: Context) {

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var previousMode: Int = AudioManager.MODE_NORMAL
    private var focusRequest: AudioFocusRequest? = null

    @Volatile
    var hasFocus = false
        private set

    var onFocusLost: (() -> Unit)? = null

    val audioManagerRef: AudioManager get() = audioManager

    fun activate() {
        // Guard against double-call: only capture the original mode the
        // first time, so a second activate() doesn't overwrite it with
        // MODE_IN_COMMUNICATION (which would break deactivate()).
        if (audioManager.mode != AudioManager.MODE_IN_COMMUNICATION) {
            previousMode = audioManager.mode
        }
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        requestFocus()
    }

    fun deactivate() {
        abandonFocus()
        audioManager.mode = previousMode
    }

    private fun requestFocus() {
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()

        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
            .setAudioAttributes(attributes)
            .setOnAudioFocusChangeListener { focusChange ->
                when (focusChange) {
                    AudioManager.AUDIOFOCUS_LOSS,
                    AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                        hasFocus = false
                        onFocusLost?.invoke()
                    }
                    AudioManager.AUDIOFOCUS_GAIN -> hasFocus = true
                }
            }
            .build()

        focusRequest = request
        hasFocus = audioManager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun abandonFocus() {
        focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        focusRequest = null
        hasFocus = false
    }
}
