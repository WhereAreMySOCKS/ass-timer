import Foundation

/// Wraps UserDefaults for all persisted app state.
final class PersistenceManager {
    static let shared = PersistenceManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let userConfig = "ass_timer_user_config"
        static let windowOriginX = "ass_timer_window_x"
        static let windowOriginY = "ass_timer_window_y"
        static let localEventCount = "ass_timer_local_count"
        static let nextReminderTimestamp = "ass_timer_next_reminder_ts"
        static let onboardingComplete = "ass_timer_onboarding_done"
    }

    // MARK: - User Config

    func saveConfig(_ config: UserConfig) {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: Keys.userConfig)
        }
    }

    func loadConfig() -> UserConfig {
        guard let data = defaults.data(forKey: Keys.userConfig),
              let config = try? JSONDecoder().decode(UserConfig.self, from: data)
        else {
            return UserConfig()
        }
        return config
    }

    // MARK: - Onboarding

    var onboardingComplete: Bool {
        get { defaults.bool(forKey: Keys.onboardingComplete) }
        set { defaults.set(newValue, forKey: Keys.onboardingComplete) }
    }

    // MARK: - Window Position

    func saveWindowPosition(x: CGFloat, y: CGFloat) {
        defaults.set(Double(x), forKey: Keys.windowOriginX)
        defaults.set(Double(y), forKey: Keys.windowOriginY)
    }

    func loadWindowPosition() -> CGPoint? {
        guard let x = defaults.object(forKey: Keys.windowOriginX) as? Double,
              let y = defaults.object(forKey: Keys.windowOriginY) as? Double
        else { return nil }
        return CGPoint(x: x, y: y)
    }

    // MARK: - Local Event Count

    var localEventCount: Int {
        get { defaults.integer(forKey: Keys.localEventCount) }
        set { defaults.set(newValue, forKey: Keys.localEventCount) }
    }

    func incrementEventCount() {
        localEventCount += 1
    }

    // MARK: - Next Reminder Time

    func saveNextReminderTime(_ time: Date) {
        defaults.set(time.timeIntervalSince1970, forKey: Keys.nextReminderTimestamp)
    }

    func loadNextReminderTime() -> Date? {
        let ts = defaults.double(forKey: Keys.nextReminderTimestamp)
        guard ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    func clearNextReminderTime() {
        defaults.removeObject(forKey: Keys.nextReminderTimestamp)
    }

    func clearAllLocalData() {
        defaults.removeObject(forKey: Keys.userConfig)
        defaults.removeObject(forKey: Keys.windowOriginX)
        defaults.removeObject(forKey: Keys.windowOriginY)
        defaults.removeObject(forKey: Keys.localEventCount)
        defaults.removeObject(forKey: Keys.nextReminderTimestamp)
        defaults.removeObject(forKey: Keys.onboardingComplete)
    }
}
