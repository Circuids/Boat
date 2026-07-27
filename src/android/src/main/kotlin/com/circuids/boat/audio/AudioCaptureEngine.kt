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
    private var audioRecord: AudioRecord? = null

    val audioSessionId: Int
        get() = audioRecord?.audioSessionId ?: -1

    val frameSizeBytes: Int
        get() = sampleRate * bufferDurationMs / 1000 * 2 // 16-bit mono

    fun create(): Int {
        val channelConfig = AudioFormat.CHANNEL_IN_MONO
        val encoding = AudioFormat.ENCODING_PCM_16BIT
        val minBuffer = AudioRecord.getMinBufferSize(sampleRate, channelConfig, encoding)
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
        audioRecord?.stop()
    }

    fun release() {
        stop()
        audioRecord?.release()
        audioRecord = null
    }
}
