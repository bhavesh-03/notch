import Foundation

/// Evaluates what you'd type into a calculator: + − × ÷ with the usual precedence, parentheses,
/// decimals, negative numbers, % (a hundredth) and ^ (power). Written by hand rather than with
/// NSExpression, which raises an Objective-C exception on half-typed input like "12+" (fatal in
/// Swift); here anything malformed or undefined just has no result.
enum Calculation {
    static func evaluate(_ text: String) -> Double? {
        var parser = Parser(tokens: tokenize(text))
        guard let tokens = parser.tokens, !tokens.isEmpty,
              let value = parser.expression(), parser.isAtEnd, value.isFinite
        else { return nil }
        return value
    }

    // MARK: - Tokens

    enum Token: Equatable {
        case number(Double)
        case op(Character)
        case open, close
    }

    /// Nil for a character that doesn't belong in a calculation.
    static func tokenize(_ text: String) -> [Token]? {
        var tokens: [Token] = []
        var number = ""
        func flush() -> Bool {
            guard !number.isEmpty else { return true }
            guard let value = Double(number) else { return false }
            tokens.append(.number(value))
            number = ""
            return true
        }
        for character in text {
            switch character {
            case "0"..."9", ".":
                number.append(character)
            case ",", " ", "\u{00A0}":
                continue   // thousands separators and spaces
            default:
                guard flush() else { return nil }
                switch character {
                case "+": tokens.append(.op("+"))
                case "-", "−", "–": tokens.append(.op("-"))
                case "*", "×", "x", "X": tokens.append(.op("*"))
                case "/", "÷": tokens.append(.op("/"))
                case "^": tokens.append(.op("^"))
                case "%": tokens.append(.op("%"))
                case "(": tokens.append(.open)
                case ")": tokens.append(.close)
                default: return nil
                }
            }
        }
        guard flush() else { return nil }
        return tokens
    }

    // MARK: - Parsing

    /// Recursive descent, one function per precedence level:
    /// expression = term (± term)*; term = unary (×÷ unary)*; unary = (±) unary | power;
    /// power = postfix (^ unary)?; postfix = primary %*; primary = number | ( expression ).
    /// A leading minus binds looser than ^, as in written maths: -2^2 is -(2^2) = -4.
    private struct Parser {
        let tokens: [Token]?
        private var index = 0

        init(tokens: [Token]?) {
            self.tokens = tokens
        }

        var isAtEnd: Bool { index == (tokens?.count ?? 0) }

        private var current: Token? {
            guard let tokens, index < tokens.count else { return nil }
            return tokens[index]
        }

        private mutating func take(_ token: Token) -> Bool {
            guard current == token else { return false }
            index += 1
            return true
        }

        mutating func expression() -> Double? {
            guard var value = term() else { return nil }
            while true {
                if take(.op("+")) { guard let rhs = term() else { return nil }; value += rhs }
                else if take(.op("-")) { guard let rhs = term() else { return nil }; value -= rhs }
                else { return value }
            }
        }

        private mutating func term() -> Double? {
            guard var value = unary() else { return nil }
            while true {
                if take(.op("*")) { guard let rhs = unary() else { return nil }; value *= rhs }
                else if take(.op("/")) {
                    guard let rhs = unary(), rhs != 0 else { return nil }   // ÷ 0 has no answer
                    value /= rhs
                } else { return value }
            }
        }

        private mutating func unary() -> Double? {
            if take(.op("-")) { return unary().map { -$0 } }
            if take(.op("+")) { return unary() }
            return power()
        }

        private mutating func power() -> Double? {
            guard let base = postfix() else { return nil }
            guard take(.op("^")) else { return base }
            // The exponent is a unary, so 2^-1 works and 2^3^2 is 2^9 (right to left).
            guard let exponent = unary() else { return nil }
            return pow(base, exponent)
        }

        private mutating func postfix() -> Double? {
            guard var value = primary() else { return nil }
            while take(.op("%")) { value /= 100 }
            return value
        }

        private mutating func primary() -> Double? {
            if case .number(let value) = current {
                index += 1
                return value
            }
            if take(.open) {
                guard let value = expression(), take(.close) else { return nil }
                return value
            }
            return nil
        }
    }

    // MARK: - Showing results

    /// "1,234.5", "0.333333333", "1.5e+15": grouped, without trailing zeros, scientific when huge or tiny.
    static func format(_ value: Double) -> String {
        let magnitude = abs(value)
        if magnitude != 0, magnitude >= 1e15 || magnitude < 1e-9 {
            return String(format: "%.6g", value)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 9
        formatter.usesGroupingSeparator = true
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: value == 0 ? 0 : value)) ?? "\(value)"   // no "-0"
    }
}
