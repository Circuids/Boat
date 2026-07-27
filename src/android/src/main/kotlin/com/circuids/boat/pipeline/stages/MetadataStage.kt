package com.circuids.boat.pipeline.stages

import com.circuids.boat.pipeline.MutableAudioFrame
import com.circuids.boat.pipeline.PipelineConfig
import com.circuids.boat.pipeline.PipelineStage

/**
 * Frame identity: sequence number, timestamp, duration, route.
 * Scope constraint: no statistics, no counters, no diagnostics.
 */
class MetadataStage(
    private val currentRouteProvider: () -> String,
) : PipelineStage {

    private var sequenceCounter = 0L
    private var startNanos = 0L

    override fun initialize(config: PipelineConfig) {
        sequenceCounter = 0
        startNanos = System.nanoTime()
    }

    override fun process(frame: MutableAudioFrame) {
        frame.sequenceNumber = sequenceCounter++
        frame.timestampNanos = System.nanoTime() - startNanos
    }

    override fun start() {}
    override fun stop() {}
    override fun dispose() {}
}
