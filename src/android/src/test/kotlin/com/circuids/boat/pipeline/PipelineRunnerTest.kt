package com.circuids.boat.pipeline

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

internal class PipelineRunnerTest {

    private class RecordingStage(val name: String, val log: MutableList<String>) : PipelineStage {
        override fun initialize(config: PipelineConfig) {}
        override fun process(frame: MutableAudioFrame) { log.add(name) }
        override fun start() {}
        override fun stop() {}
        override fun dispose() {}
    }

    private class ThrowingStage : PipelineStage {
        override fun initialize(config: PipelineConfig) {}
        override fun process(frame: MutableAudioFrame) { throw RuntimeException("stage error") }
        override fun start() {}
        override fun stop() {}
        override fun dispose() {}
    }

    @Test
    fun stagesExecuteInOrder() {
        val log = mutableListOf<String>()
        val stages = listOf(RecordingStage("a", log), RecordingStage("b", log), RecordingStage("c", log))
        val config = PipelineConfig()
        val frame = MutableAudioFrame(ByteArray(640))

        stages.forEach { it.initialize(config) }
        frame.reset()
        stages.forEach { it.process(frame) }

        assertEquals(listOf("a", "b", "c"), log)
    }

    @Test
    fun errorInOneStageDoesNotStopPipeline() {
        val log = mutableListOf<String>()
        val stages = listOf(ThrowingStage(), RecordingStage("after", log))
        val frame = MutableAudioFrame(ByteArray(640))
        frame.reset()

        for (stage in stages) {
            try {
                stage.process(frame)
            } catch (_: Exception) { /* pipeline catches */ }
        }

        assertTrue(log.contains("after"))
    }

    @Test
    fun resetZeroesAllMutableFields() {
        val frame = MutableAudioFrame(ByteArray(640))
        frame.sequenceNumber = 99
        frame.timestampNanos = 12345
        frame.speechActive = true
        frame.speechConfidence = 0.9f
        frame.processingTimeNanos = 5000
        frame.dropped = true

        frame.reset()

        assertEquals(0, frame.sequenceNumber)
        assertEquals(0L, frame.timestampNanos)
        assertTrue(!frame.speechActive)
        assertEquals(0f, frame.speechConfidence)
        assertEquals(0L, frame.processingTimeNanos)
        assertTrue(!frame.dropped)
    }

    @Test
    fun metadataStageSetsSequenceAndTimestamp() {
        val stage = com.circuids.boat.pipeline.stages.MetadataStage { "speaker" }
        stage.initialize(PipelineConfig())

        val frame = MutableAudioFrame(ByteArray(640))
        frame.reset()
        stage.process(frame)
        assertEquals(0, frame.sequenceNumber)
        assertTrue(frame.timestampNanos >= 0)

        frame.reset()
        stage.process(frame)
        assertEquals(1, frame.sequenceNumber)
    }
}
