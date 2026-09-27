import Foundation

/// Finds a video call link in an event's URL, location or notes, where calendar invites put them.
enum CallLink {
    /// Hosts of the services people join calls on. Matched as whole host names or their subdomains.
    static let hosts = ["zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com", "facetime.apple.com", "webex.com"]

    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    /// The first call link in the texts, in order.
    static func find(in texts: [String?]) -> URL? {
        for text in texts.compactMap({ $0 }) where !text.isEmpty {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector?.matches(in: text, range: range) ?? [] {
                if let url = match.url, isCall(url) { return url }
            }
        }
        return nil
    }

    static func isCall(_ url: URL) -> Bool {
        guard let host = url.host()?.lowercased(), url.scheme?.hasPrefix("http") == true else { return false }
        return hosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}
