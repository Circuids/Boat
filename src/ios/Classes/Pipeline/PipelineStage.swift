import Foundation

/// In-place processing stage. No allocation, no blocking, no Flutter calls.
/// Stages should not throw under normal operation — PipelineRunner catches
/// any exception and disables the stage after repeated failures.
protocol PipelineStage: AnyObject {
    func initialize(config: PipelineConfig)
    func process(frame: MutableAudioFrame) throws
    func start()
    func stop()
    func dispose()
}
