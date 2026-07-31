import Foundation

/// Immutable pipeline configuration captured at construction.
struct PipelineConfig {
    let frameDurationMs: Int
    let deadlineFraction: Double
    let vadEnabled: Bool
    let diagnosticsEnabled: Bool

    init(frameDurationMs: Int = 20, deadlineFraction: Double = 0.80,
         vadEnabled: Bool = false, diagnosticsEnabled: Bool = false) {
        self.frameDurationMs = frameDurationMs
        self.deadlineFraction = deadlineFraction
        self.vadEnabled = vadEnabled
        self.diagnosticsEnabled = diagnosticsEnabled
    }

    static func fromMap(_ map: [String: Any]) -> PipelineConfig {
        PipelineConfig(
            frameDurationMs: map["bufferDurationMs"] as? Int ?? 20,
            deadlineFraction: (map["deadlineFraction"] as? Double) ?? 0.80,
            vadEnabled: map["vadEnabled"] as? Bool ?? false,
            diagnosticsEnabled: map["diagnosticsEnabled"] as? Bool ?? false
        )
    }
}
