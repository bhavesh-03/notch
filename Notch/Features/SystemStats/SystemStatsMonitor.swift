import Foundation

/// Samples the Mac's vitals every couple of seconds, but only while something shows them: views call
/// `addViewer()` when they appear and `removeViewer()` when they go, so a closed notch costs nothing.
@Observable
final class SystemStatsMonitor {
    private(set) var latest: SystemStatsSample?
    /// Recent samples, oldest first, for the usage graphs.
    private(set) var history: [SystemStatsSample] = []

    static let historyLength = 30
    let interval: Duration

    @ObservationIgnored private let reader: any SystemStatsReading
    @ObservationIgnored private var viewers = 0
    @ObservationIgnored private var samplingTask: Task<Void, Never>?

    init(reader: any SystemStatsReading = SystemStatsReader(), interval: Duration = .seconds(2)) {
        self.reader = reader
        self.interval = interval
    }

    var isSampling: Bool { samplingTask != nil }

    func addViewer() {
        viewers += 1
        guard samplingTask == nil else { return }
        samplingTask = Task { [weak self, reader, interval] in
            while !Task.isCancelled {
                // Off the main thread: the IOKit calls take a few milliseconds.
                let sample = await Task.detached(priority: .utility) { reader.sample() }.value
                guard !Task.isCancelled else { return }
                self?.record(sample)
                try? await Task.sleep(for: interval)
            }
        }
    }

    func removeViewer() {
        viewers = max(0, viewers - 1)
        guard viewers == 0 else { return }
        samplingTask?.cancel()
        samplingTask = nil
    }

    func record(_ sample: SystemStatsSample) {
        latest = sample
        history.append(sample)
        if history.count > Self.historyLength {
            history.removeFirst(history.count - Self.historyLength)
        }
    }
}
