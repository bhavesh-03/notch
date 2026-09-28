import AppKit

/// The calculator's state: what's typed, its live result, and recent calculations.
@Observable
final class CalculatorModel {
    var expression = ""
    private(set) var history: [Entry] = []

    static let historyLength = 6

    struct Entry: Equatable, Identifiable {
        let id = UUID()
        let expression: String
        let result: Double
    }

    enum Key: Hashable {
        case digit(Int), point, op(String), open, close, clear, backspace, equals
    }

    /// The result as you type; nil while the expression is incomplete.
    var result: Double? { Calculation.evaluate(expression) }

    var lastResult: Double? { history.first?.result }

    func press(_ key: Key) {
        switch key {
        case .digit(let digit): expression += String(digit)
        case .point: expression += "."
        case .op(let symbol): expression += symbol
        case .open: expression += "("
        case .close: expression += ")"
        case .clear: expression = ""
        case .backspace: if !expression.isEmpty { expression.removeLast() }
        case .equals: commit()
        }
    }

    /// Keeps the calculation in history and continues from its result, like a calculator's =.
    func commit() {
        guard let result, Calculation.format(result) != expression else { return }
        history.insert(Entry(expression: expression, result: result), at: 0)
        if history.count > Self.historyLength { history.removeLast() }
        expression = Self.plain(result)
    }

    /// Continues from an earlier result.
    func use(_ entry: Entry) {
        expression = Self.plain(entry.result)
    }

    func copy(_ value: Double) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.plain(value), forType: .string)
    }

    /// A result as plain digits (no grouping), for typing on from or pasting elsewhere.
    static func plain(_ value: Double) -> String {
        Calculation.format(value).replacingOccurrences(of: ",", with: "")
    }
}
