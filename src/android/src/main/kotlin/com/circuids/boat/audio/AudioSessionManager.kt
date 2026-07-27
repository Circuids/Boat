package com.circuids.boat.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build

/**
 * Manages MODE_IN_COMMUNICATION and audio focus lifecycle.
 * Mode must be set BEFORE creating AudioRecord for AEC coupling.
 */
class AudioSessionManager(context: Context) {

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var previousMode: Int = AudioManager.MODE_NORMAL
    private var focusRequest: AudioFocusRequest? = null
    private var hasFocus = false

    val audioManagerRef: AudioManager get() = audioManager

    fun activate() {
        previousMode = audioManager.mode
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
                    AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> hasFocus = false
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
