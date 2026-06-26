import Foundation
import Combine

/// The timer state machine.
enum TimerState: Sendable {
    case idle           // No timer running (onboarding incomplete)
    case running        // Timer counting down to nextReminderTime
    case reminder       // Reminder bubble showing, waiting for user action
    case waitConfirm    // User tapped "我已提肛", brief confirmation feedback
    case reset          // Calculating new nextReminderTime
}

/// Absolute-time-based timer engine that handles sleep/wake correctly.
/// Uses an absolute `nextReminderTime` rather than a countdown,
/// so it survives Mac sleep without accumulating missed reminders.
@MainActor
final class TimerEngine: ObservableObject {
    @Published var state: TimerState = .idle
    @Published var nextReminderTime: Date?

    private var timer: Timer?
    var onFire: (() -> Void)?

    /// Start the timer with the given interval in seconds.
    /// If a persisted nextReminderTime exists and hasn't elapsed yet,
    /// restores it (survives app quit/relaunch). Fires immediately if overdue.
    func start(intervalSeconds: Int) {
        stop()

        // Check for a persisted nextReminderTime from a prior session
        if let storedTime = PersistenceManager.shared.loadNextReminderTime() {
            if Date() >= storedTime {
                // Reminder was due while app was closed — fire immediately
                nextReminderTime = storedTime
                fire()
                return
            } else {
                // Restore remaining countdown
                nextReminderTime = storedTime
                state = .running
            }
        } else {
            // First ever start: compute new fire time
            let fireTime = Date().addingTimeInterval(TimeInterval(intervalSeconds))
            nextReminderTime = fireTime
            PersistenceManager.shared.saveNextReminderTime(fireTime)
            state = .running
        }

        // Tick every second, checking if we've passed the target time.
        // Timer fires on the main run loop because it's scheduled from @MainActor context;
        // assumeIsolated silences the Sendable-closure warning safely.
        timer = Timer.scheduledTimer(withTimeInterval: Constants.timerTickInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                guard self.state == .running else { return }

                if let fireTime = self.nextReminderTime, Date() >= fireTime {
                    self.fire()
                }
            }
        }
    }

    /// Stop the timer without firing.
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Fire the reminder now.
    private func fire() {
        stop()
        state = .reminder
        onFire?()
    }

    /// Called after user completes Kegel — reset for the next cycle.
    func reset(intervalSeconds: Int) {
        state = .reset
        // Calculate new absolute fire time from now
        let newFireTime = Date().addingTimeInterval(TimeInterval(intervalSeconds))
        nextReminderTime = newFireTime
        PersistenceManager.shared.saveNextReminderTime(newFireTime)
        // Transition to running
        state = .running
        start(intervalSeconds: intervalSeconds)
    }

    // MARK: - Sleep / Wake

    /// Persist the current state before sleep.
    func handleSleep() {
        if let fireTime = nextReminderTime {
            PersistenceManager.shared.saveNextReminderTime(fireTime)
        }
        stop()
    }

    /// Restore state after wake. Fires immediately if the reminder time passed.
    func handleWake(intervalSeconds: Int) {
        guard let storedTime = PersistenceManager.shared.loadNextReminderTime() else {
            // No stored time: start fresh
            start(intervalSeconds: intervalSeconds)
            return
        }

        if Date() >= storedTime {
            // Reminder time passed while asleep — fire immediately
            nextReminderTime = storedTime
            fire()
        } else {
            // Resume with remaining time
            nextReminderTime = storedTime
            state = .running
            timer = Timer.scheduledTimer(withTimeInterval: Constants.timerTickInterval, repeats: true) { [weak self] _ in
                guard let self else { return }
                MainActor.assumeIsolated {
                    guard self.state == .running else { return }

                    if let fireTime = self.nextReminderTime, Date() >= fireTime {
                        self.fire()
                    }
                }
            }
        }
    }
}
