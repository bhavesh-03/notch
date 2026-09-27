//
//  TimerController.swift
//  Notch
//
//  Created by Vineet Parmar on 26/09/26.
//


import Foundation

@Observable
final class TimerController {
    private(set) var state: TimerState
    @ObservationIgnored var onStart: (() -> Void)?
    @ObservationIgnored var onFinish: (() -> Void)?
    /// Called when the length actually changes (not for a value that rounds to the current one).
    @ObservationIgnored var onDurationChanged: ((TimeInterval) -> Void)?
    /// A length chosen while a timer runs; it takes effect once that timer finishes or is cancelled.
    @ObservationIgnored private var pendingDuration: TimeInterval?
    @ObservationIgnored private var finishTask: Task<Void, Never>?
    @ObservationIgnored private let now: () -> Date
    
    init(duration: TimeInterval = 25 * 60, now: @escaping () -> Date = Date.init) {
        self.state = TimerState(duration: duration)
        self.now = now
    }
    
    var isRunning: Bool {
        if case .running = state.phase { return true }
        return false
    }
    
    func remaining(at date: Date) -> TimeInterval {
        state.remaining(at: date)
    }
    
    func start() {
        state.start(at: now())
        scheduleFinish()
        onStart?()
    }
    
    func pause() {
        state.pause(at: now())
        cancelFinish()
    }
    
    func reset() {
        state.reset()
        cancelFinish()
        applyPendingDuration()
    }
    
    /// The length the timer is set to, in seconds.
    var duration: TimeInterval { state.duration }

    /// Sets the length. While a timer runs or is paused it keeps its length, so the new one waits.
    func setDuration(seconds: TimeInterval) {
        guard state.phase == .idle else {
            pendingDuration = seconds
            return
        }
        pendingDuration = nil
        let old = state.duration
        state.setDuration(seconds: seconds)
        if state.duration != old {
            onDurationChanged?(state.duration)
        }
    }

    private func applyPendingDuration() {
        guard let pending = pendingDuration else { return }
        setDuration(seconds: pending)
    }

    func toggle() {
        isRunning ? pause() : start()
    }
    
    private func scheduleFinish() {
        cancelFinish()
        guard case .running(let endDate) = state.phase else { return }
        let delay = endDate.timeIntervalSince(now())
        
        finishTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }
    
    private func cancelFinish() {
        finishTask?.cancel()
        finishTask = nil
    }
    
    private func finish() {
        finishTask = nil
        state.reset()
        applyPendingDuration()
        onFinish?()
    }
}
