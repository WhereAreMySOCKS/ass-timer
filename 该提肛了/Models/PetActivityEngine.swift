import Foundation
import Combine
import AppKit

/// Sub-state machine for pet idle activity (independent of Kegel timer).
enum PetActivityState: Sendable {
    case standing
    case walking
    case flying
    case napping
}

/// Manages the pet's stand→walk→stand activity cycle.
/// Drives sprite keyframe animation and window movement during walking.
/// Only active when the Kegel TimerState is `.running`.
@MainActor
final class PetActivityEngine: ObservableObject {
    @Published var activityState: PetActivityState = .standing
    @Published var currentSpriteName: String?   // Current keyframe name (e.g. "站立-1")
    @Published var isWalkingLeft: Bool = false   // True → PetView flips sprite horizontally
    @Published var isFlyingLeft: Bool = false    // True → flip sprite during fly

    weak var appState: AppState?
    weak var petWindow: NSWindow?

    // MARK: - Animation Phases

    private enum AnimationPhase {
        case standing
        case transitionIn(frameIndex: Int)     // 0..<4 → walkTransitionIn
        case walkLoop(frameIndex: Int)         // 0..<4 → walkLoop (cycling)
        case transitionOut(frameIndex: Int)    // 0..<4 → walkTransitionOut

        var isStanding: Bool {
            if case .standing = self { return true }
            return false
        }
    }

    private var phase: AnimationPhase = .standing
    private var frameTimer: Timer?
    private var moveTimer: Timer?
    private var pendingWalkTask: DispatchWorkItem?  // Track asyncAfter so we can cancel
    private var flyTimer: Timer?                    // Parabolic animation display link
    private var napTimer: Timer?
    private var napEndTask: DispatchWorkItem?
    private var napRequested = false
    private var flyStartTime: Date = .distantPast
    private var flyStartPosition: NSPoint = .zero
    private var flyTotalHorizontal: CGFloat = 0
    private var flyPeakHeight: CGFloat = 0
    private var flyTotalDuration: TimeInterval = 0
    private var walkDirection: CGFloat = 1.0         // 1 = right, -1 = left
    private var walkEndTime: Date = .distantPast
    private var standToggle: Bool = false

    // MARK: - Keyframe Arrays (character faces right in all frames)

    private let standingFrames = ["站立-1", "站立-2"]
    private let walkTransitionIn = ["站立-1", "站立-2", "走-2", "走-3"]
    private let walkLoop = ["走-2", "走-3", "走-2", "走-4"]
    private let walkTransitionOut = ["走-4", "走-2", "站立-2", "站立-1"]

    // MARK: - Public API

    /// Start the stand→walk→stand cycle. Only begins if Kegel state is `.running`.
    func start() {
        guard appState?.currentState == .running else { return }
        stop()
        startStanding()
        scheduleNextFly()
        scheduleNapCycle()
    }

    /// Stop all activity and clear sprite display.
    func stop() {
        frameTimer?.invalidate()
        frameTimer = nil
        moveTimer?.invalidate()
        moveTimer = nil
        pendingWalkTask?.cancel()
        pendingWalkTask = nil
        flyTimer?.invalidate()
        flyTimer = nil
        napTimer?.invalidate()
        napTimer = nil
        napEndTask?.cancel()
        napEndTask = nil
        napRequested = false
        isFlyingLeft = false
        phase = .standing
        activityState = .standing
        // Clear sprite so PetView falls back to emoji
        appState?.currentSpriteFrame = nil
        currentSpriteName = nil
    }

    // MARK: - Triggered Fly (double-click)

    /// Immediately trigger a parabolic flight from a double-click.
    func triggerFlyUp() {
        guard activityState != .flying, activityState != .napping else { return }

        flyTimer?.invalidate()
        flyTimer = nil
        frameTimer?.invalidate()
        frameTimer = nil
        moveTimer?.invalidate()
        moveTimer = nil
        pendingWalkTask?.cancel()
        pendingWalkTask = nil

        startParabolicFlight()
    }

    // MARK: - Napping

    /// Keep a wall-clock 15-minute cadence while the activity engine is running.
    private func scheduleNapCycle() {
        napTimer?.invalidate()
        let interval = Constants.petNapInterval
        napTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.requestNap()
            }
        }
    }

    private func requestNap() {
        guard appState?.currentState == .running else { return }
        guard activityState != .napping else { return }

        // Let a short flight land instead of freezing the window in mid-air.
        if activityState == .flying {
            napRequested = true
            return
        }

        startNap()
    }

    private func startNap() {
        frameTimer?.invalidate()
        frameTimer = nil
        moveTimer?.invalidate()
        moveTimer = nil
        flyTimer?.invalidate()
        flyTimer = nil
        pendingWalkTask?.cancel()
        pendingWalkTask = nil
        napEndTask?.cancel()
        napRequested = false
        isWalkingLeft = false
        isFlyingLeft = false

        activityState = .napping
        phase = .standing
        updateSprite(name: "趴")

        let duration = Constants.petNapDuration
        let task = DispatchWorkItem { [weak self] in
            guard let self, self.activityState == .napping else { return }
            self.napEndTask = nil
            self.startStanding()
            self.scheduleNextFly()
        }
        napEndTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
    }


    // MARK: - Standing

    private func startStanding() {
        // Always clean up any previous timers / pending tasks first
        frameTimer?.invalidate()
        frameTimer = nil
        pendingWalkTask?.cancel()
        pendingWalkTask = nil

        activityState = .standing
        phase = .standing
        standToggle = false
        updateSprite(name: standingFrames[0])

        // Standing breathing animation
        let interval = Constants.petStandFrameInterval
        frameTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                guard self.phase.isStanding else { return }
                self.standToggle.toggle()
                let name = self.standingFrames[self.standToggle ? 1 : 0]
                self.updateSprite(name: name)
            }
        }

        // Schedule walk after stand duration (track so we can cancel)
        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingWalkTask = nil
            self.startWalking()
        }
        pendingWalkTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.petStandDuration, execute: task)
    }

    // MARK: - Walking

    private func startWalking() {
        guard appState?.currentState == .running else {
            // Kegel state changed — abort and go back to standing
            startStanding()
            return
        }

        // Stop standing timer
        frameTimer?.invalidate()
        frameTimer = nil
        pendingWalkTask?.cancel()
        pendingWalkTask = nil

        // Random direction and duration
        walkDirection = Bool.random() ? 1.0 : -1.0
        isWalkingLeft = (walkDirection == -1.0)
        let durationRange = Constants.petWalkDurationMin...Constants.petWalkDurationMax
        let walkDuration = TimeInterval.random(in: durationRange)
        walkEndTime = Date().addingTimeInterval(walkDuration)

        activityState = .walking

        // Phase 1: transition in
        phase = .transitionIn(frameIndex: 0)
        updateSprite(name: walkTransitionIn[0])
        startFrameTimer(rate: Constants.petSpriteFrameInterval)

        // Start moving the window
        startMoveTimer()
    }

    private func endWalking() {
        // Stop movement
        moveTimer?.invalidate()
        moveTimer = nil

        // Phase: transition out
        phase = .transitionOut(frameIndex: 0)
        updateSprite(name: walkTransitionOut[0])
        startFrameTimer(rate: Constants.petSpriteFrameInterval)
    }

    // MARK: - Frame Animation

    private func startFrameTimer(rate: TimeInterval) {
        scheduleNextFrame(after: rate)
    }

    private func scheduleNextFrame(after delay: TimeInterval) {
        frameTimer?.invalidate()
        frameTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.frameTimer = nil
                self.advanceFrame()
            }
        }
    }

    private func delayForNextFrame(nextPhase: AnimationPhase) -> TimeInterval {
        switch nextPhase {
        case .walkLoop(let idx) where walkLoop[idx] == "走-4":
            return Constants.petSpriteFrameInterval + Constants.petSpritePreFourDelay
        case .transitionOut(let idx) where walkTransitionOut[idx] == "走-4":
            return Constants.petSpriteFrameInterval + Constants.petSpritePreFourDelay
        default:
            return Constants.petSpriteFrameInterval
        }
    }

    private func advanceFrame() {
        switch phase {
        case .standing:
            break // handled by standing timer

        case .transitionIn(let idx):
            let next = idx + 1
            if next < walkTransitionIn.count {
                phase = .transitionIn(frameIndex: next)
                updateSprite(name: walkTransitionIn[next])
                scheduleNextFrame(after: delayForNextFrame(nextPhase: phase))
            } else {
                // Enter walk loop
                phase = .walkLoop(frameIndex: 0)
                updateSprite(name: walkLoop[0])
                scheduleNextFrame(after: delayForNextFrame(nextPhase: phase))
            }

        case .walkLoop(let idx):
            // Check if walk duration expired
            if Date() >= walkEndTime {
                endWalking()
                return
            }
            let next = (idx + 1) % walkLoop.count
            phase = .walkLoop(frameIndex: next)
            updateSprite(name: walkLoop[next])
            scheduleNextFrame(after: delayForNextFrame(nextPhase: phase))

        case .transitionOut(let idx):
            let next = idx + 1
            if next < walkTransitionOut.count {
                phase = .transitionOut(frameIndex: next)
                updateSprite(name: walkTransitionOut[next])
                scheduleNextFrame(after: delayForNextFrame(nextPhase: phase))
            } else {
                // Back to standing
                frameTimer?.invalidate()
                frameTimer = nil
                startStanding()
            }
        }
    }

    // MARK: - Window Movement

    private func startMoveTimer() {
        moveTimer?.invalidate()
        let interval = Constants.petMoveInterval
        moveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.moveWindow(stepInterval: interval)
            }
        }
    }

    private func moveWindow(stepInterval: TimeInterval) {
        guard let window = petWindow,
              let screen = NSScreen.main else { return }

        let visibleFrame = screen.visibleFrame
        let currentFrame = window.frame
        let margin = Constants.petScreenEdgeMargin

        let step = walkDirection * Constants.petWalkSpeed * CGFloat(stepInterval)
        var newX = currentFrame.origin.x + step

        // Bounce off screen edges
        let minX = visibleFrame.minX + margin
        let maxX = visibleFrame.maxX - currentFrame.width - margin

        if newX <= minX {
            newX = minX
            walkDirection = 1.0  // bounce right
            isWalkingLeft = false
        } else if newX >= maxX {
            newX = maxX
            walkDirection = -1.0  // bounce left
            isWalkingLeft = true
        }

        window.setFrameOrigin(NSPoint(x: newX, y: currentFrame.origin.y))
        NotificationCenter.default.post(name: .petWindowDidMove, object: nil, userInfo: ["frame": window.frame])

        // Persist new position
        PersistenceManager.shared.saveWindowPosition(x: newX, y: currentFrame.origin.y)
    }

    // MARK: - Flying (Vertical Movement)

    /// Schedule the next random fly-up event (5–10 minutes from now).
    private func scheduleNextFly() {
        flyTimer?.invalidate()
        flyTimer = nil
        let interval = TimeInterval.random(in: Constants.petFlyIntervalMin...Constants.petFlyIntervalMax)
        flyTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.startFlying()
            }
        }
    }

    /// Begin a parabolic flight. Only triggers when Kegel state is `.running`.
    private func startFlying() {
        guard appState?.currentState == .running else {
            scheduleNextFly()
            return
        }
        guard activityState != .flying, activityState != .napping else {
            scheduleNextFly()
            return
        }

        frameTimer?.invalidate()
        frameTimer = nil
        moveTimer?.invalidate()
        moveTimer = nil
        pendingWalkTask?.cancel()
        pendingWalkTask = nil

        startParabolicFlight()
    }

    /// Core parabolic flight: x匀速, y二次函数 → 真正的抛物线轨迹
    private func startParabolicFlight() {
        guard let window = petWindow else {
            finishFlying()
            return
        }

        activityState = .flying
        updateSprite(name: "起飞")

        let currentFrame = window.frame
        let startX = currentFrame.origin.x
        let startY = currentFrame.origin.y

        // Calculate horizontal destination (clamped to screen)
        let totalHorizontal: CGFloat
        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let minX = visibleFrame.minX + Constants.petScreenEdgeMargin
            let maxX = visibleFrame.maxX - currentFrame.width - Constants.petScreenEdgeMargin
            let safeX = min(max(startX, minX), maxX)
            let leftAvail = max(0, safeX - minX)
            let rightAvail = max(0, maxX - safeX)
            let minTravel: CGFloat = 40
            let canL = leftAvail >= minTravel
            let canR = rightAvail >= minTravel
            let goLeft: Bool
            if canL && canR { goLeft = Bool.random() }
            else if canL { goLeft = true }
            else if canR { goLeft = false }
            else { goLeft = leftAvail > rightAvail }
            let avail = goLeft ? leftAvail : rightAvail
            let maxT = min(Constants.petFlyHorizontalRange, avail)
            let travel = maxT > 0 ? CGFloat.random(in: min(minTravel, maxT)...maxT) : 0
            totalHorizontal = goLeft ? -travel : travel
        } else {
            totalHorizontal = CGFloat.random(in: -Constants.petFlyHorizontalRange...Constants.petFlyHorizontalRange)
        }

        // Peak height = one pet height
        let peakHeight = currentFrame.height
        // Total flight time: 2 * petFlyDuration
        let totalTime = Constants.petFlyDuration * 2

        flyTotalHorizontal = totalHorizontal
        flyPeakHeight = peakHeight
        flyTotalDuration = totalTime
        flyStartPosition = NSPoint(x: startX, y: startY)
        flyStartTime = Date()
        isFlyingLeft = totalHorizontal < 0

        // Drive animation at ~60fps with a non-repeating timer
        flyTimer?.invalidate()
        flyTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.updateParabolicFlight()
            }
        }
    }

    /// Called every frame (~60fps) to update window position along the parabola.
    private func updateParabolicFlight() {
        guard let window = petWindow else {
            flyTimer?.invalidate()
            flyTimer = nil
            finishFlying()
            return
        }

        let elapsed = Date().timeIntervalSince(flyStartTime)
        let t = min(elapsed / flyTotalDuration, 1.0) // 0 → 1

        // x(t) = startX + totalHorizontal * t  (匀速水平)
        let x = flyStartPosition.x + flyTotalHorizontal * t

        // y(t) = startY + 4 * peakHeight * t * (1 - t)  (抛物线，t=0.5 时取最大值 peakHeight)
        let y = flyStartPosition.y + 4 * flyPeakHeight * t * (1 - t)

        // Update flip direction based on horizontal velocity
        isFlyingLeft = flyTotalHorizontal < 0

        let frame = NSRect(x: x, y: y,
                           width: window.frame.width, height: window.frame.height)
        window.setFrame(frame, display: true)
        NotificationCenter.default.post(name: .petWindowDidMove, object: nil, userInfo: ["frame": frame])

        if t >= 1.0 {
            flyTimer?.invalidate()
            flyTimer = nil
            finishFlying()
        }
    }

    /// Clean up flying state and resume normal stand→walk activity.
    private func finishFlying() {
        guard activityState == .flying else { return }
        isFlyingLeft = false

        // Persist the landed position
        if let window = petWindow {
            PersistenceManager.shared.saveWindowPosition(x: window.frame.origin.x, y: window.frame.origin.y)
        }

        if napRequested {
            startNap()
            return
        }

        // Resume normal stand→walk cycle
        startStanding()
        scheduleNextFly()
    }

    // MARK: - Helpers

    private func updateSprite(name: String) {
        currentSpriteName = name
        appState?.currentSpriteFrame = name
    }
}
