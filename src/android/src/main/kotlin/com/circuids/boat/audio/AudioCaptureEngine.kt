package com.circuids.boat.audio

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import kotlin.math.max

/**
 * Thin wrapper around AudioRecord: creation, configuration, lifecycle.
 * Does NOT own the capture thread — CapturePipeline owns the read loop.
 */
class AudioCaptureEngine(
    private val sampleRate: Int = 16000,
    private val bufferDurationMs: Int = 20,
) {
    @Volatile
    private var audioRecord: AudioRecord? = null

    val audioSessionId: Int
        get() = audioRecord?.audioSessionId ?: -1

    val frameSizeBytes: Int
        get() = sampleRate * bufferDurationMs / 1000 * 2 // 16-bit mono

    fun create(): Int {
        val channelConfig = AudioFormat.CHANNEL_IN_MONO
        val encoding = AudioFormat.ENCODING_PCM_16BIT
        val minBuffer = AudioRecord.getMinBufferSize(sampleRate, channelConfig, encoding)
        // getMinBufferSize returns ERROR_BAD_VALUE (-2) or ERROR (-1) on
        // unsupported configurations — fail fast instead of constructing
        // a broken AudioRecord.
        if (minBuffer <= 0) {
            throw IllegalStateException("AudioRecord.getMinBufferSize returned $minBuffer for ${sampleRate}Hz")
        }
        val targetBytes = sampleRate * bufferDurationMs / 1000 * 2
        val bufferSize = max(minBuffer, targetBytes) * 2

        val record = AudioRecord.Builder()
            .setAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION)
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setChannelMask(channelConfig)
                    .setEncoding(encoding)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize)
            .build()

        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            throw IllegalStateException("AudioRecord failed to initialize (state=${record.state})")
        }

        audioRecord = record
        return record.audioSessionId
    }

    fun startRecording() {
        audioRecord?.startRecording()
    }

    /** Blocking read directly into the caller's buffer. Returns bytes read. */
    fun read(buffer: ByteArray, offsetInBytes: Int, sizeInBytes: Int): Int {
        return audioRecord?.read(buffer, offsetInBytes, sizeInBytes) ?: -1
    }

    fun stop() {
        try {
            audioRecord?.stop()
        } catch (_: IllegalStateException) {
            // stop() throws if not recording — safe to ignore during teardown.
        }
    }

    fun release() {
        stop()
        audioRecord?.release()
        audioRecord = null
    }
}
