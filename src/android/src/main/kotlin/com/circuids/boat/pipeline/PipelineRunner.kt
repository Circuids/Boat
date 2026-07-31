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

    // Per-stage disabled flags — once a stage exceeds MAX_CONSECUTIVE_FAILURES
    // it is skipped for subsequent frames (not just warned about).
    private val stageDisabled = BooleanArray(stages.size)
    private val stageFailures = IntArray(stages.size)

    @Volatile
    private var running = false
    private var captureThread: Thread? = null

    @Volatile
    var captureFrameCount: Long = 0
        private set

    // Single pre-allocated frame, reused every iteration. Zero allocation per frame.
    private val frame = MutableAudioFrame(ByteArray(captureEngine.frameSizeBytes)).apply {
        this.sampleRate = this@PipelineRunner.sampleRate
        this.channelCount = this@PipelineRunner.channelCount
    }

    companion object {
        private const val MAX_CONSECUTIVE_FAILURES = 50
    }

    fun initialize() {
        stages.forEach { it.initialize(config) }
    }

    fun start() {
        if (running) return
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
     *
     * Wrapped in try/catch so an uncaught exception on the capture thread
     * emits an error event instead of dying silently.
     */
    private fun captureLoop() {
        try {
            while (running) {
                frame.reset()
                val bytesRead = captureEngine.read(frame.pcm, 0, frame.pcm.size)
                if (bytesRead <= 0) {
                    // Negative return (e.g. ERROR_DEAD_OBJECT) is fatal —
                    // break the loop and emit an error instead of spinning.
                    if (bytesRead < 0) {
                        publisher.emitError(
                            "CAPTURE_READ_FAILED",
                            "AudioRecord.read returned $bytesRead — capture device may be dead",
                        )
                        break
                    }
                    continue
                }
                frame.validBytes = bytesRead

                val startNanos = System.nanoTime()
                for ((index, stage) in stages.withIndex()) {
                    if (stageDisabled[index]) continue
                    try {
                        stage.process(frame)
                        stageFailures[index] = 0
                    } catch (_: Exception) {
                        stageFailures[index]++
                        if (stageFailures[index] >= MAX_CONSECUTIVE_FAILURES && !stageDisabled[index]) {
                            stageDisabled[index] = true
                            publisher.emitWarning(
                                "STAGE_DISABLED",
                                "Stage ${stage::class.simpleName} disabled after $MAX_CONSECUTIVE_FAILURES consecutive failures",
                            )
                        }
                    }
                }

                frame.processingTimeNanos = System.nanoTime() - startNanos
                if (frame.processingTimeNanos > deadlineNanos) {
                    publisher.emitWarning("DEADLINE_EXCEEDED", "Frame ${frame.sequenceNumber} exceeded deadline")
                }

                publisher.publish(frame)
                captureFrameCount++
            }
        } catch (e: Exception) {
            publisher.emitError("CAPTURE_THREAD_FATAL", "Capture thread terminated: ${e.message}")
        } finally {
            running = false
        }
    }

    fun stop() {
        if (!running) return
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
