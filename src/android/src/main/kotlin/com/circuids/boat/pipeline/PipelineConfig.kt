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
            deadlineFraction = (map["deadlineFraction"] as? Number)?.toDouble() ?: 0.80,
            vadEnabled = map["vadEnabled"] as? Boolean ?: false,
            diagnosticsEnabled = map["diagnosticsEnabled"] as? Boolean ?: false,
        )
    }
}
