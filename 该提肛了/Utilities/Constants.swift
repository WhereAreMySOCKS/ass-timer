import Foundation
import SwiftUI

enum Constants {
    // MARK: - Pet Options
    static let petOptions: [(emoji: String, name: String, imageName: String)] = [
        ("🦌", "小鹿", "pet_deer"),
    ]

    // MARK: - Timer
    static let defaultIntervalSeconds: Int = 2400    // seconds (40 minutes)
    static let intervalRange: ClosedRange<Double> = 10...7200  // 10s ~ 120min, in seconds
    static let intervalStep: Double = 5
    static let timerTickInterval: TimeInterval = 1.0

    static func normalizedIntervalSeconds(_ seconds: Int) -> Int {
        let minSeconds = Int(intervalRange.lowerBound)
        let maxSeconds = Int(intervalRange.upperBound)
        return min(max(seconds, minSeconds), maxSeconds)
    }

    // MARK: - Nickname
    static let nicknameMinLength = 2
    static let nicknameMaxLength = 12

    // MARK: - Invite Code
    static let inviteCodeLength = 6

    // MARK: - Bubbles
    static let groupBubbleDuration: TimeInterval = 5.0
    static let confirmHoldDuration: TimeInterval = 2.0
    static let bubbleOverlaySize: CGSize = CGSize(width: 320, height: 300)
    static let bubbleScreenEdgeMargin: CGFloat = 12
    static let bubbleTailOverlap: CGFloat = 6

    // MARK: - Networking
    nonisolated static let apiBaseURL = "https://api.guiji.online/ass-timer"
    nonisolated static let wsBaseURL = "wss://api.guiji.online/ass-timer"

    // MARK: - WebSocket
    nonisolated static let wsReconnectMaxRetries = 10
    nonisolated static let wsReconnectMaxBackoff: TimeInterval = 30.0
    nonisolated static let wsPingInterval: TimeInterval = 30.0

    // MARK: - App Updates
    nonisolated static let appUpdateCheckInterval: TimeInterval = 6 * 60 * 60

    // MARK: - Leaderboard
    static let leaderboardRefreshInterval: TimeInterval = 30.0
    static let leaderboardMaxEntries = 20

    // MARK: - Pet Window
    static let petWindowPadding: CGFloat = 28
    static let petSpriteSize: CGSize = CGSize(width: 108, height: 144)
    static let petWindowDefaultSize: CGSize = CGSize(
        width: petSpriteSize.width + petWindowPadding * 2,
        height: petSpriteSize.height + petWindowPadding * 2
    )
    static let petContentSize: CGSize = petWindowDefaultSize
    static let petActionButtonAreaWidth: CGFloat = 60
    static let petWindowTotalWidth: CGFloat = petWindowDefaultSize.width + petActionButtonAreaWidth
    static let petEdgeSnapThreshold: CGFloat = 32
    static let petDockedWindowWidth: CGFloat = petContentSize.width

    // MARK: - Pet Activity (Stand / Walk Cycle)
    static let petStandDuration: TimeInterval = 8.0          // 站立 5 秒后开始散步
    static let petWalkDurationMin: TimeInterval = 3.0         // 最短散步 3 秒
    static let petWalkDurationMax: TimeInterval = 15.0         // 最长散步 8 秒
    static let petWalkSpeed: CGFloat = 18                      // 每秒移动 18 点
    static let petSpriteFrameInterval: TimeInterval = 0.35    // 散步关键帧间隔 ~3 FPS
    static let petSpritePreFourDelay: TimeInterval = 0.15     // 走-4 帧前额外停顿
    static let petStandFrameInterval: TimeInterval = 0.6     // 站立呼吸帧间隔
    static let petScreenEdgeMargin: CGFloat = 30              // 距屏幕边缘最小距离
    static let petMoveInterval: TimeInterval = 0.05           // 窗口移动刷新间隔 ~20 FPS

    // MARK: - Pet Resting
    static let petNapInterval: TimeInterval = 15 * 60         // 每 15 分钟趴下一次
    static let petNapDuration: TimeInterval = 60              // 趴下持续 1 分钟

    // MARK: - Pet Flying
    static let petFlyIntervalMin: TimeInterval = 0           // 最短 5 分钟触发飞行
    static let petFlyIntervalMax: TimeInterval = 600           // 最长 10 分钟触发飞行
    static let petFlyDuration: TimeInterval = 0.8              // 飞行上升/下降动画时长
    static let petFlyHorizontalRange: CGFloat = 120            // 双击飞行水平随机偏移范围 (±120pt)
}
