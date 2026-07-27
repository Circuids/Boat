import Foundation

/// In-place processing stage. No allocation, no return value, never throws.
protocol PipelineStage: AnyObject {
    func initialize(config: PipelineConfig)
    func process(frame: MutableAudioFrame)
    func start()
    func stop()
    func dispose()
}
