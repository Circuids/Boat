package com.circuids.boat.pipeline

/**
 * Immutable pipeline configuration captured at construction.
 */
data class PipelineConfig(
    val frameDurationMs: Int = 20,
    val deadlineFraction: Double = 0.80,
    val vadEnabled: Boolean = false,
    val diagnosticsEnabled: Boolean = false,
) {
    companion object {
        fun fromMap(map: Map<String, Any?>): PipelineConfig = PipelineConfig(
            frameDurationMs = (map["bufferDurationMs"] as? Number)?.toInt() ?: 20,
            deadlineFraction = 0.80,
            vadEnabled = false,
            diagnosticsEnabled = false,
        )
    }
}
