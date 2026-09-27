//
//  TimerState.swift
//  Notch
//
//  Created by Vineet Parmar on 26/09/26.
//


import Foundation

struct TimerState: Equatable {
    enum Phase: Equatable {
        case idle
        case running(endDate: Date)
        case paused(remaining: TimeInterval)
    }
    
    /// Lengths are set in 15-second steps, from 15 s to 2 h.
    static let step: TimeInterval = 15
    static let durationRange: ClosedRange<TimeInterval> = 15...(120 * 60)

    private(set) var duration: TimeInterval
    private(set) var phase: Phase = .idle
    
    init(duration: TimeInterval) {
        self.duration = duration
    }
    
    func remaining(at now: Date) -> TimeInterval  {
        switch phase {
        case .idle: duration
        case .running(let endDate): max(0, endDate.timeIntervalSince(now))
        case .paused(let remaining): remaining
        }
    }
    
    func isFinished(at now: Date) -> Bool  {
        if case .running = phase { return remaining(at: now) == 0 }
        return false
    }
    
    mutating func start(at now: Date)  {
        switch phase {
        case .idle: phase = .running(endDate: now.addingTimeInterval(duration))
        case .paused(let remaining): phase = .running(endDate: now.addingTimeInterval(remaining))
        case .running: break
        }
    }
    
    mutating func pause(at now: Date) {
        guard case .running = phase else { return }
        phase = .paused(remaining: remaining(at: now))
    }
    
    /// Changes the length, rounded to a 15-second step and clamped to `durationRange`.
    /// Only while idle: a running or paused timer keeps its length.
    mutating func setDuration(seconds: TimeInterval) {
        guard phase == .idle else { return }
        let stepped = (seconds / Self.step).rounded() * Self.step
        duration = min(max(stepped, Self.durationRange.lowerBound), Self.durationRange.upperBound)
    }

    mutating func reset() {
        phase = .idle
    }
}
