import Foundation
import Testing
@testable import Notch

struct CalculationTests {
    @Test(arguments: [
        ("2+3", 5.0),
        ("2+3×4", 14),
        ("(2+3)×4", 20),
        ("10÷4", 2.5),
        ("10/4", 2.5),
        ("7*6", 42),
        ("2−5", -3),
        ("-5+2", -3),
        ("-(2+3)", -5),
        ("3*-2", -6),
        ("2^10", 1024),
        ("2^3^2", 512),
        ("-2^2", -4),
        ("2^-1", 0.5),
        ("50%", 0.5),
        ("200×15%", 30),
        ("1,000 + 1", 1001),
        (" 1 . 5 + 1", 2.5),
        ("0.1+0.2", 0.30000000000000004),
        ("((1))", 1),
    ])
    func evaluates(expression: String, expected: Double) {
        #expect(Calculation.evaluate(expression) == expected)
    }

    @Test(arguments: ["", "12+", "(", "(2+3", "2+3)", "5÷0", "abc", "2..3", "×3", "1(2)", "()"])
    func halfTypedOrUndefinedHasNoResult(expression: String) {
        #expect(Calculation.evaluate(expression) == nil)
    }

    @Test(arguments: [
        (1234.5, "1,234.5"),
        (1.0 / 3.0, "0.333333333"),
        (42.0, "42"),
        (-0.0, "0"),
        (-1500.25, "-1,500.25"),
        (2e15, "2e+15"),
        (1e-12, "1e-12"),
    ])
    func formats(value: Double, text: String) {
        #expect(Calculation.format(value) == text)
    }
}
