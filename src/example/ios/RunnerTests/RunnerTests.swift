import Flutter
import UIKit
import XCTest

@testable import boat

class RunnerTests: XCTestCase {

    func testPipelineConfigDefaults() {
        let config = PipelineConfig()
        XCTAssertEqual(config.frameDurationMs, 20)
        XCTAssertEqual(config.deadlineFraction, 0.80, accuracy: 0.001)
    }

    func testMutableAudioFrameReset() {
        let frame = MutableAudioFrame(pcm: Data(count: 640))
        frame.sequenceNumber = 99
        frame.timestampNanos = 12345
        frame.speechActive = true
        frame.processingTimeNanos = 5000
        frame.dropped = true

        frame.reset()

        XCTAssertEqual(frame.sequenceNumber, 0)
        XCTAssertEqual(frame.timestampNanos, 0)
        XCTAssertFalse(frame.speechActive)
        XCTAssertEqual(frame.processingTimeNanos, 0)
        XCTAssertFalse(frame.dropped)
    }

    func testMetadataStageSetsSequence() {
        let stage = MetadataStage()
        stage.initialize(config: PipelineConfig())

        let frame = MutableAudioFrame(pcm: Data(count: 640))
        frame.reset()
        stage.process(frame: frame)
        XCTAssertEqual(frame.sequenceNumber, 0)

        frame.reset()
        stage.process(frame: frame)
        XCTAssertEqual(frame.sequenceNumber, 1)
    }
}
