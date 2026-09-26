import Foundation
import Testing
@testable import Notch

@MainActor
struct LineBufferTests {
    private func strings(_ lines: [Data]) -> [String] {
        lines.map { String(decoding: $0, as: UTF8.self) }
    }

    @Test func aCompleteLineComesOut() {
        var buffer = LineBuffer()
        #expect(strings(buffer.append(Data("one\n".utf8))) == ["one"])
    }

    @Test func aLineSplitAcrossReadsIsJoined() {
        var buffer = LineBuffer()
        #expect(buffer.append(Data("{\"act".utf8)).isEmpty)
        #expect(strings(buffer.append(Data("ive\":false}\n".utf8))) == [#"{"active":false}"#])
    }

    @Test func severalLinesInOneReadAllComeOut() {
        var buffer = LineBuffer()
        #expect(strings(buffer.append(Data("a\nb\nc".utf8))) == ["a", "b"])
        #expect(strings(buffer.append(Data("\n".utf8))) == ["c"])
    }

    @Test func emptyLinesAreSkipped() {
        var buffer = LineBuffer()
        #expect(strings(buffer.append(Data("\n\nx\n".utf8))) == ["x"])
    }
}
