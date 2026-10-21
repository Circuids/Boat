import XCTest

@testable import boat

final class MediaSessionArbiterTests: XCTestCase {

    private let arbiter = MediaSessionArbiter.shared

    override func setUp() {
        super.setUp()
        arbiter.resetForTest()
    }

    override func tearDown() {
        arbiter.resetForTest()
        super.tearDown()
    }

    func testStartsUnowned() {
        XCTAssertEqual(arbiter.owner, .none)
    }

    func testAcquireMediaSucceedsWhenUnowned() {
        XCTAssertTrue(arbiter.acquireMedia())
        XCTAssertEqual(arbiter.owner, .media)
    }

    func testAcquireMediaIsIdempotentWhileMediaOwns() {
        XCTAssertTrue(arbiter.acquireMedia())
        XCTAssertTrue(arbiter.acquireMedia())
        XCTAssertEqual(arbiter.owner, .media)
    }

    func testAcquireMediaRefusedWhenVoiceOwns() {
        arbiter.acquireVoice()
        XCTAssertFalse(arbiter.acquireMedia())
        XCTAssertEqual(arbiter.owner, .voice)
    }

    func testAcquireVoiceAlwaysSucceeds() {
        arbiter.acquireVoice()
        arbiter.acquireVoice()
        XCTAssertEqual(arbiter.owner, .voice)
    }

    func testAcquireVoicePreemptsMediaAndInvokesStopCallback() {
        var stopped = false
        arbiter.onMediaStop = { stopped = true }
        _ = arbiter.acquireMedia()

        arbiter.acquireVoice()

        XCTAssertTrue(stopped, "media-stop callback must fire before acquireVoice returns")
        XCTAssertEqual(arbiter.owner, .voice)
    }

    func testAcquireVoiceDoesNotInvokeCallbackWhenMediaIdle() {
        var stopped = false
        arbiter.onMediaStop = { stopped = true }

        arbiter.acquireVoice()

        XCTAssertFalse(stopped)
    }

    func testReleaseClearsMatchingOwner() {
        _ = arbiter.acquireMedia()
        arbiter.release(.media)
        XCTAssertEqual(arbiter.owner, .none)
    }

    func testReleaseIgnoresNonMatchingOwner() {
        arbiter.acquireVoice()
        arbiter.release(.media)
        XCTAssertEqual(arbiter.owner, .voice)
    }

    func testMediaCanAcquireAfterVoiceReleases() {
        arbiter.acquireVoice()
        arbiter.release(.voice)
        XCTAssertTrue(arbiter.acquireMedia())
    }
}
