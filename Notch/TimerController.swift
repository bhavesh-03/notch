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
    @ObservationIgnored var onFinish: (() -> Void)?
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
    }
    
    func pause() {
        state.pause(at: now())
        cancelFinish()
    }
    
    func reset() {
        state.reset()
        cancelFinish()
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
        onFinish?()
    }
}
