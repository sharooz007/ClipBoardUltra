import Cocoa
import QuartzCore

/// Monitors global mouse dragging and detects a rapid "shake" gesture to summon the Drop Shelf.
public final class DragShakeMonitor {
    public static let shared = DragShakeMonitor()

    private var globalMonitor: Any?
    private var localMonitor: Any?

    private struct DragSample {
        let point: NSPoint
        let time: TimeInterval
    }

    private var samples: [DragSample] = []
    private var lastTriggerTime: TimeInterval = 0

    private init() {}

    public func start() {
        stop()
        guard SettingsStore.shared.dropShelfEnabled && SettingsStore.shared.dropShelfShakeToSummon else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.handleEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.handleEvent(event)
            return event
        }
    }

    public func stop() {
        if let gm = globalMonitor {
            NSEvent.removeMonitor(gm)
            globalMonitor = nil
        }
        if let lm = localMonitor {
            NSEvent.removeMonitor(lm)
            localMonitor = nil
        }
        samples.removeAll()
    }

    public func restartIfNeeded() {
        start()
    }

    private func handleEvent(_ event: NSEvent) {
        if event.type == .leftMouseUp {
            samples.removeAll()
            return
        }

        guard event.type == .leftMouseDragged else { return }
        guard SettingsStore.shared.dropShelfEnabled && SettingsStore.shared.dropShelfShakeToSummon else { return }
        guard DropShelfManager.shared.activeDragSessionCount == 0 else { return }

        let now = CACurrentMediaTime()
        let mousePoint = NSEvent.mouseLocation

        // Prune samples older than 450ms
        let windowDuration: TimeInterval = 0.45
        samples.removeAll { now - $0.time > windowDuration }
        samples.append(DragSample(point: mousePoint, time: now))

        // Cooldown check (minimum 1.5 seconds between triggers)
        guard now - lastTriggerTime > 1.5 else { return }
        guard samples.count >= 6 else { return }

        if detectShake() {
            lastTriggerTime = now
            samples.removeAll()
            DispatchQueue.main.async {
                DropShelfManager.shared.show(near: mousePoint)
            }
        }
    }

    /// Evaluates recent mouse movement for oscillatory reversals.
    private func detectShake() -> Bool {
        guard samples.count >= 6 else { return false }

        let minDelta: CGFloat = 16.0
        var xReversals = 0
        var lastXSign = 0
        var totalDistance: CGFloat = 0

        for i in 1..<samples.count {
            let prev = samples[i - 1].point
            let curr = samples[i].point
            let dx = curr.x - prev.x
            let dy = curr.y - prev.y
            totalDistance += hypot(dx, dy)

            if abs(dx) >= minDelta {
                let sign = dx > 0 ? 1 : -1
                if lastXSign != 0 && sign != lastXSign {
                    xReversals += 1
                }
                lastXSign = sign
            }
        }

        // Check vertical reversals as well (in case user shakes up and down)
        var yReversals = 0
        var lastYSign = 0
        for i in 1..<samples.count {
            let prev = samples[i - 1].point
            let curr = samples[i].point
            let dy = curr.y - prev.y

            if abs(dy) >= minDelta {
                let sign = dy > 0 ? 1 : -1
                if lastYSign != 0 && sign != lastYSign {
                    yReversals += 1
                }
                lastYSign = sign
            }
        }

        // Require at least 3 direction reversals and reasonable total travel distance
        let hasEnoughReversals = xReversals >= 3 || yReversals >= 3
        let hasEnoughDistance = totalDistance >= 120.0

        return hasEnoughReversals && hasEnoughDistance
    }
}
