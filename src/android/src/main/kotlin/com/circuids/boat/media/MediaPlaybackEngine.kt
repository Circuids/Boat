package com.circuids.boat.media

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Build
import android.os.Process
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit

/**
 * Media output: an AudioTrack with USAGE_MEDIA on its own OS-assigned session.
 *
 * Deliberately never receives a session ID — joining the capture session would
 * re-couple media to the voice path and to AEC.
 */
class MediaPlaybackEngine {

    private var audioTrack: AudioTrack? = null
    private var drainThread: Thread? = null
    private val queue = LinkedBlockingQueue<ByteArray>(2000)

    @Volatile
    private var isPlaying = false

    @Volatile
    var sampleRate: Int = 48000
        private set

    @Volatile
    var channelCount: Int = 2
        private set

    @Volatile
    var volume: Float = 1.0f
        private set

    @Volatile
    var framesWritten: Long = 0
        private set

    /** Creates the track for the given source format. Replaces any existing one. */
    fun create(sampleRate: Int, channelCount: Int) {
        release()
        this.sampleRate = sampleRate
        this.channelCount = channelCount

        val channelMask =
            if (channelCount == 1) AudioFormat.CHANNEL_OUT_MONO else AudioFormat.CHANNEL_OUT_STEREO
        val encoding = AudioFormat.ENCODING_PCM_16BIT
        val minBuffer = AudioTrack.getMinBufferSize(sampleRate, channelMask, encoding)
        if (minBuffer <= 0) {
            throw IllegalStateException(
                "AudioTrack.getMinBufferSize returned $minBuffer for ${sampleRate}Hz/${channelCount}ch"
            )
        }
        val targetBytes = sampleRate * 20 / 1000 * channelCount * 2
        val bufferSize = maxOf(minBuffer, targetBytes) * 2

        val builder = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setChannelMask(channelMask)
                    .setEncoding(encoding)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize)
            .setTransferMode(AudioTrack.MODE_STREAM)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
        }

        val track = builder.build()
        if (track.state != AudioTrack.STATE_INITIALIZED) {
            track.release()
            throw IllegalStateException("AudioTrack failed to initialize (state=${track.state})")
        }
        track.setVolume(volume)
        audioTrack = track
    }

    fun start() {
        if (isPlaying) return
        val track = audioTrack ?: return
        track.play()
        isPlaying = true

        drainThread = Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
            while (isPlaying) {
                val data = queue.poll(50, TimeUnit.MILLISECONDS) ?: continue
                track.write(data, 0, data.size)
                framesWritten++
            }
        }, "boat-media-playback").also { it.start() }
    }

    /** Enqueues PCM for playback. No-op when not playing. */
    fun write(pcm: ByteArray) {
        if (isPlaying) queue.offer(pcm)
    }

    fun pause() {
        isPlaying = false
        drainThread?.join(500)
        drainThread = null
        runCatching { audioTrack?.pause() }
    }

    fun resume() {
        runCatching { audioTrack?.play() }
        start()
    }

    fun setVolume(value: Float) {
        volume = value.coerceIn(0f, 1f)
        runCatching { audioTrack?.setVolume(volume) }
    }

    fun flush() {
        queue.clear()
        runCatching { audioTrack?.flush() }
    }

    /**
     * Stops the drain thread and waits for it to exit before touching the
     * track, so release() never races a blocking write().
     */
    fun stop() {
        isPlaying = false
        drainThread?.join(500)
        drainThread = null
        runCatching { audioTrack?.stop() }
    }

    fun release() {
        stop()
        queue.clear()
        runCatching { audioTrack?.release() }
        audioTrack = null
    }
}
