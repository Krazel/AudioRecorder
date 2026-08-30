import XCTest
@testable import AudioRecorder

final class ContinuousSegmentRotationTests: XCTestCase {
    func testBothModesUseTheContinuousEngine() {
        XCTAssertEqual(RecordingBackendPolicy.backend(for: .everything), .continuousAudioEngine)
        XCTAssertEqual(RecordingBackendPolicy.backend(for: .soundActivated), .continuousAudioEngine)
        XCTAssertFalse(RecordingBackendPolicy.stopsCaptureDuringSegmentRotation)
    }

    func testRotationBacklogPreservesOrderAndDrainsAtomically() {
        var backlog = SegmentRotationBacklog<Int>(capacity: 3)

        XCTAssertTrue(backlog.append(10))
        XCTAssertTrue(backlog.append(20))
        XCTAssertTrue(backlog.append(30))
        XCTAssertEqual(backlog.drain(), [10, 20, 30])
        XCTAssertTrue(backlog.values.isEmpty)
    }

    func testRotationBacklogFailsClosedAtItsBound() {
        var backlog = SegmentRotationBacklog<Int>(capacity: 2)

        XCTAssertTrue(backlog.append(1))
        XCTAssertTrue(backlog.append(2))
        XCTAssertFalse(backlog.append(3))
        XCTAssertEqual(backlog.values, [1, 2])
    }

    func testCancelledRetryCannotRunLater() async {
        let retry = Task {
            await RecordingRetryGate.wait(nanoseconds: 5_000_000_000)
        }

        retry.cancel()
        XCTAssertFalse(await retry.value)
    }
}
