package com.circuids.boat.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Build
import android.os.Process
import java.util.concurrent.LinkedBlockingQueue

/**
 * Wraps AudioTrack with USAGE_VOICE_COMMUNICATION.
 * Uses OS internal buffer — no custom queue for timing.
 */
class AudioPlaybackEngine(
    private val sampleRate: Int = 16000,
    private val sessionId: Int = 0,
) {
    private var audioTrack: AudioTrack? = null
    private var playbackThread: Thread? = null
    // Sized for ~40s of 20ms frames — absorbs burst delivery (e.g. test-app
    // replay) without dropping, while the blocking write paces actual output.
    private val queue = LinkedBlockingQueue<ByteArray>(2000)

    @Volatile
    var isPlaying = false
        private set

    @Volatile
    var playbackFrameCount: Long = 0
        private set

    var underrunCount: Int = 0
        private set

    fun create() {
        val channelConfig = AudioFormat.CHANNEL_OUT_MONO
        val encoding = AudioFormat.ENCODING_PCM_16BIT
        val minBuffer = AudioTrack.getMinBufferSize(sampleRate, channelConfig, encoding)

        val builder = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setChannelMask(channelConfig)
                    .setEncoding(encoding)
                    .build()
            )
            .setBufferSizeInBytes(minBuffer * 2)
            .setTransferMode(AudioTrack.MODE_STREAM)

        if (sessionId > 0) {
            builder.setSessionId(sessionId)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
        }

        audioTrack = builder.build()
    }

    fun start() {
        if (isPlaying) return
        val track = audioTrack ?: return
        track.play()
        isPlaying = true

        playbackThread = Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
            while (isPlaying) {
                val data = queue.poll(50, java.util.concurrent.TimeUnit.MILLISECONDS) ?: continue
                track.write(data, 0, data.size)
                playbackFrameCount++
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    underrunCount = track.underrunCount
                }
            }
        }, "boat-playback").also { it.start() }
    }

    fun write(pcm: ByteArray) {
        if (isPlaying) {
            queue.offer(pcm)
        }
    }

    fun flush() {
        queue.clear()
        audioTrack?.flush()
    }

    fun stop() {
        // Signal the playback thread to exit, then wait for it to drain
        // the queue before stopping the track — this prevents a race
        // where release() is called while a blocking write() is in
        // progress on the playback thread.
        isPlaying = false
        playbackThread?.join(500)
        playbackThread = null
        try {
            audioTrack?.stop()
        } catch (_: IllegalStateException) {
            // stop() throws if already stopped — safe during teardown.
        }
    }

    fun release() {
        stop()
        audioTrack?.release()
        audioTrack = null
    }
}
