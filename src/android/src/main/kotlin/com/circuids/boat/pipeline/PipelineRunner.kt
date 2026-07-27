package com.circuids.boat.pipeline

import android.os.Process
import com.circuids.boat.audio.AudioCaptureEngine

/**
 * THE central object. Owns: capture thread, pre-allocated frame, stage iteration,
 * deadline enforcement, error handling, and FramePublisher reference.
 *
 * Capture is the producer (not a stage). Stages process frames after production.
 */
class PipelineRunner(
    private val config: PipelineConfig,
    private val stages: List<PipelineStage>,
    private val publisher: FramePublisher,
    private val captureEngine: AudioCaptureEngine,
    private val sampleRate: Int = 16000,
    private val channelCount: Int = 1,
) {
    private val framePeriodNanos = config.frameDurationMs * 1_000_000L
    private val deadlineNanos = (framePeriodNanos * config.deadlineFraction).toLong()
    private var consecutiveFailures = 0

    @Volatile
    private var running = false
    private var captureThread: Thread? = null

    // Single pre-allocated frame, reused every iteration. Zero allocation per frame.
    private val frame = MutableAudioFrame(ByteArray(captureEngine.frameSizeBytes)).apply {
        this.sampleRate = this@CapturePipeline.sampleRate
        this.channelCount = this@CapturePipeline.channelCount
    }

    companion object {
        private const val MAX_CONSECUTIVE_FAILURES = 50
    }

    fun initialize() {
        stages.forEach { it.initialize(config) }
    }

    fun start() {
        stages.forEach { it.start() }
        running = true
        captureEngine.startRecording()

        captureThread = Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
            captureLoop()
        }, "boat-capture").also { it.start() }
    }

    /**
     * The capture loop: reset → read → stages → publish.
     * Runs on URGENT_AUDIO thread. No locks, no allocations, no thread hops.
     */
    private fun captureLoop() {
        while (running) {
            frame.reset()
            val bytesRead = captureEngine.read(frame.pcm, 0, frame.pcm.size)
            if (bytesRead <= 0) continue
            frame.validBytes = bytesRead

            val startNanos = System.nanoTime()
            for (stage in stages) {
                try {
                    stage.process(frame)
                    consecutiveFailures = 0
                } catch (_: Exception) {
                    consecutiveFailures++
                    if (consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
                        publisher.emitWarning("STAGE_DISABLED", "Stage disabled after $MAX_CONSECUTIVE_FAILURES failures")
                    }
                }
            }

            frame.processingTimeNanos = System.nanoTime() - startNanos
            if (frame.processingTimeNanos > deadlineNanos) {
                publisher.emitWarning("DEADLINE_EXCEEDED", "Frame ${frame.sequenceNumber} exceeded deadline")
            }

            publisher.publish(frame)
        }
    }

    fun stop() {
        running = false
        captureThread?.join(500)
        captureThread = null
        captureEngine.stop()
        stages.forEach { it.stop() }
    }

    fun dispose() {
        stop()
        stages.forEach { it.dispose() }
    }
}
