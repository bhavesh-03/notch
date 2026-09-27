import Foundation

/// Waits until `condition` is true, checking every 20 ms, for at most `timeout`.
///
/// Use this instead of "sleep a fixed time, then check" for things that happen after a delay:
/// it passes as soon as the condition holds, and only fails if it never does, so tests don't
/// flake when the machine is busy.
@MainActor
func eventually(timeout: Duration = .seconds(3), _ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        if ContinuousClock.now >= deadline { return false }
        try? await Task.sleep(for: .milliseconds(20))
    }
    return true
}
