import Foundation
import Testing
@testable import Notch

@MainActor
struct CalculatorModelTests {
    private func type(_ keys: [CalculatorModel.Key], into model: CalculatorModel) {
        keys.forEach(model.press)
    }

    @Test func theKeypadBuildsAnExpressionWithALiveResult() {
        let model = CalculatorModel()
        type([.digit(1), .digit(2), .op("×"), .open, .digit(3), .op("+"), .digit(4), .close], into: model)
        #expect(model.expression == "12×(3+4)")
        #expect(model.result == 84)
    }

    @Test func equalsKeepsItInHistoryAndContinuesFromTheResult() {
        let model = CalculatorModel()
        type([.digit(9), .op("÷"), .digit(4), .equals], into: model)
        #expect(model.expression == "2.25")
        #expect(model.history.first?.expression == "9÷4")
        #expect(model.lastResult == 2.25)
        type([.op("×"), .digit(4), .equals], into: model)
        #expect(model.expression == "9")
    }

    @Test func equalsOnAnIncompleteExpressionDoesNothing() {
        let model = CalculatorModel()
        type([.digit(5), .op("+"), .equals], into: model)
        #expect(model.expression == "5+")
        #expect(model.history.isEmpty)
    }

    @Test func equalsTwiceDoesNotRepeatInHistory() {
        let model = CalculatorModel()
        type([.digit(2), .op("+"), .digit(2), .equals, .equals], into: model)
        #expect(model.history.count == 1)
    }

    @Test func largeResultsContinueWithoutGrouping() {
        let model = CalculatorModel()
        model.expression = "1000×1000"
        model.commit()
        #expect(model.expression == "1000000")
    }

    @Test func clearAndBackspace() {
        let model = CalculatorModel()
        type([.digit(1), .digit(2), .backspace], into: model)
        #expect(model.expression == "1")
        type([.clear, .backspace], into: model)
        #expect(model.expression == "")
    }

    @Test func historyKeepsTheLatestFew() {
        let model = CalculatorModel()
        for n in 1...(CalculatorModel.historyLength + 2) {
            model.expression = "\(n)+0"
            model.commit()
        }
        #expect(model.history.count == CalculatorModel.historyLength)
        #expect(model.history.first?.result == Double(CalculatorModel.historyLength + 2))
    }

    @Test func usingAnEarlierResult() {
        let model = CalculatorModel()
        model.expression = "6×7"
        model.commit()
        model.expression = "1+1"
        model.use(model.history[0])
        #expect(model.expression == "42")
    }

    @Test func calculatorIsAButtonWithATallPage() {
        let model = NotchViewModel(geometry: .previewHardware, settings: .ephemeral())
        #expect(model.calculator.tab?.style == .button)
        model.expand()
        model.select(tab: model.calculator)
        #expect(model.isTall)
    }
}
