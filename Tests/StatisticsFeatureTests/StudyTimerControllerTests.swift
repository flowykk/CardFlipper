import Foundation
import StatisticsFeature
import Testing

@MainActor
@Test func timerCountsOnlyWhileSceneIsActiveAndResumesAutomatically() {
    let fixture = TimerFixture()
    let sessionID = UUID()
    fixture.timer.setSceneActive(true)
    fixture.timer.startSession(id: sessionID)

    fixture.advance(40)
    fixture.timer.tick()
    #expect(fixture.timer.snapshot.todayElapsedSeconds == 40)
    #expect(fixture.timer.snapshot.sessionElapsedSeconds == 40)

    fixture.timer.setSceneActive(false)
    fixture.advance(50)
    fixture.timer.tick()
    #expect(fixture.timer.snapshot.todayElapsedSeconds == 40)

    fixture.timer.setSceneActive(true)
    fixture.advance(20)
    fixture.timer.tick()
    #expect(fixture.timer.snapshot.todayElapsedSeconds == 60)
    #expect(fixture.timer.snapshot.sessionElapsedSeconds == 60)
    #expect(fixture.activity.phases == [.running, .paused, .running])
}

@MainActor
@Test func endingSessionCommitsOnceAndRejectsStaleIdentifier() {
    let fixture = TimerFixture()
    let sessionID = UUID()
    fixture.timer.setSceneActive(true)
    fixture.timer.startSession(id: sessionID)
    fixture.advance(15)

    fixture.timer.endSession(id: UUID())
    #expect(fixture.timer.snapshot.isVisible)

    fixture.timer.endSession(id: sessionID)
    fixture.timer.endSession(id: sessionID)

    #expect(!fixture.timer.snapshot.isVisible)
    #expect(fixture.store.progress(for: fixture.now, calendar: fixture.calendar).elapsedSeconds == 15)
    #expect(fixture.activity.endCount == 1)
}

@MainActor
@Test func newSessionKeepsDailyTotalAndResetsSessionTotal() {
    let fixture = TimerFixture()
    fixture.timer.setSceneActive(true)
    let first = UUID()
    fixture.timer.startSession(id: first)
    fixture.advance(25)
    fixture.timer.endSession(id: first)

    fixture.timer.startSession(id: UUID())

    #expect(fixture.timer.snapshot.todayElapsedSeconds == 25)
    #expect(fixture.timer.snapshot.sessionElapsedSeconds == 0)
}

@MainActor
private final class TimerFixture {
    private let clock = TestClock()
    var now: Date { clock.now }
    let calendar: Calendar
    let store: UserDefaultsDailyProgressRepository
    let activity = ActivitySpy()
    let timer: StudyTimerController

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        let defaults = UserDefaults(suiteName: "StudyTimerControllerTests.\(UUID().uuidString)")!
        store = UserDefaultsDailyProgressRepository(defaults: defaults)
        timer = StudyTimerController(
            progress: store,
            liveActivity: activity,
            calendar: calendar,
            now: { [clock] in clock.now }
        )
    }

    func advance(_ seconds: TimeInterval) {
        clock.now = clock.now.addingTimeInterval(seconds)
    }
}

private final class TestClock: @unchecked Sendable {
    var now = Date(timeIntervalSince1970: 1_786_406_400)
}

@MainActor
private final class ActivitySpy: StudyTimerLiveActivityClient {
    var phases: [StudyTimerActivityAttributes.Phase] = []
    var endCount = 0

    func cleanupOrphans() {}
    func start(snapshot: StudyTimerSnapshot) { phases.append(.running) }
    func publish(snapshot: StudyTimerSnapshot, phase: StudyTimerActivityAttributes.Phase) {
        phases.append(phase)
    }
    func end(finalSnapshot: StudyTimerSnapshot) { endCount += 1 }
}
