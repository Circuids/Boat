package com.circuids.boat.pipeline

/**
 * In-place processing stage. No allocation, no return value, never throws.
 */
interface PipelineStage {
    fun initialize(config: PipelineConfig)
    fun process(frame: MutableAudioFrame)
    fun start()
    fun stop()
    fun dispose()
}
