import AppKit
import Foundation

/// A persistent shell session running in the background.
/// The process stays alive across tab switches; only terminates when the app quits
/// or the user explicitly resets it.
@Observable
final class TerminalSession {

    // MARK: - Published state
    private(set) var isRunning = false
    
    // Callbacks for the UI
    @ObservationIgnored var onDataReceived: ((Data) -> Void)?
    @ObservationIgnored private var dataBuffer = Data()
    @ObservationIgnored private var isWebReady = false

    func webViewDidBecomeReady() {
        isWebReady = true
        if !dataBuffer.isEmpty {
            let pending = dataBuffer
            dataBuffer = Data()
            onDataReceived?(pending)
        }
        // Kick the shell with SIGWINCH so it redraws the prompt at the correct size.
        // This is needed because p10k / zsh draw the prompt on startup before the
        // web view exists; the buffer flush above replays that output, but sending
        // SIGWINCH forces a fresh prompt repaint once xterm.js is actually visible.
        let pid = process?.processIdentifier ?? 0
        if pid > 0 {
            kill(pid, SIGWINCH)
            // Send a second kick after fit() has had time to run and send the real cols/rows.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self, let pid = self.process?.processIdentifier, pid > 0 else { return }
                kill(pid, SIGWINCH)
            }
        }
    }
    
    // MARK: - Private
    @ObservationIgnored private var process: Process?
    @ObservationIgnored private var masterHandle: FileHandle?
    @ObservationIgnored private var masterFD: Int32 = -1

    // MARK: - Lifecycle

    init() {
        start()
    }

    func start() {
        guard !isRunning else { return }
        dataBuffer = Data()
        // A restarted shell reuses the already loaded web view.

        var master: Int32 = 0
        var slave: Int32 = 0
        var win = winsize(ws_row: 30, ws_col: 100, ws_xpixel: 0, ws_ypixel: 0)
        if openpty(&master, &slave, nil, nil, &win) == -1 {
            print("Failed to openpty")
            return
        }

        let mHandle = FileHandle(fileDescriptor: master, closeOnDealloc: true)
        let sHandle = FileHandle(fileDescriptor: slave, closeOnDealloc: true)

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: shell)
        p.arguments = ["-i", "-l"]
        p.standardInput = sHandle
        p.standardOutput = sHandle
        p.standardError = sHandle
        
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        p.environment = env

        p.terminationHandler = { [weak self] terminated in
            Task { @MainActor [weak self] in
                guard let self, self.process === terminated else { return }
                self.isRunning = false
            }
        }

        do {
            try p.run()
        } catch {
            print("Failed to start shell: \(error)")
            return
        }
        
        sHandle.closeFile()

        process = p
        masterHandle = mHandle
        masterFD = master
        isRunning = true

        mHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.isWebReady, let callback = self.onDataReceived {
                    callback(data)
                } else {
                    self.dataBuffer.append(data)
                }
            }
        }
    }

    func sendData(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        try? masterHandle?.write(contentsOf: data)
    }

    func resize(cols: Int, rows: Int) {
        guard masterFD >= 0 else { return }
        var winsz = winsize(ws_row: UInt16(rows), ws_col: UInt16(cols), ws_xpixel: 0, ws_ypixel: 0)
        ioctl(masterFD, UInt(TIOCSWINSZ), &winsz)
        // Signal the shell to re-query terminal size and redraw
        if let pid = process?.processIdentifier, pid > 0 {
            kill(pid, SIGWINCH)
        }
    }

    func reset() {
        dataBuffer = Data()
        masterHandle?.readabilityHandler = nil
        process?.terminate()
        process = nil
        masterHandle = nil
        masterFD = -1
        isRunning = false
        start()
    }

}

let terminalHTMLBase64 = "PCFETUNUWVBFIGh0bWw+CjxodG1sPgo8aGVhZD4KICAgIDxtZXRhIGNoYXJzZXQ9InV0Zi04IiAvPgogICAgPGxpbmsgcmVsPSJzdHlsZXNoZWV0IiBocmVmPSJ4dGVybS5jc3MiIC8+CiAgICA8c3R5bGU+CiAgICAgICAgYm9keSwgaHRtbCB7CiAgICAgICAgICAgIG1hcmdpbjogMDsKICAgICAgICAgICAgcGFkZGluZzogMDsKICAgICAgICAgICAgYmFja2dyb3VuZDogdHJhbnNwYXJlbnQ7CiAgICAgICAgICAgIG92ZXJmbG93OiBoaWRkZW47CiAgICAgICAgICAgIHdpZHRoOiAxMDAlOwogICAgICAgICAgICBoZWlnaHQ6IDEwMCU7CiAgICAgICAgfQogICAgICAgICN0ZXJtaW5hbC1jb250YWluZXIgewogICAgICAgICAgICBwb3NpdGlvbjogYWJzb2x1dGU7CiAgICAgICAgICAgIHRvcDogMDsKICAgICAgICAgICAgYm90dG9tOiAwOwogICAgICAgICAgICBsZWZ0OiAwOwogICAgICAgICAgICByaWdodDogMDsKICAgICAgICAgICAgb3ZlcmZsb3c6IGhpZGRlbjsKICAgICAgICB9CiAgICAgICAgLnh0ZXJtIHsKICAgICAgICAgICAgaGVpZ2h0OiAxMDAlOwogICAgICAgIH0KICAgICAgICAueHRlcm0tdmlld3BvcnQgewogICAgICAgICAgICBiYWNrZ3JvdW5kLWNvbG9yOiB0cmFuc3BhcmVudCAhaW1wb3J0YW50OwogICAgICAgICAgICBvdmVyZmxvdy15OiBhdXRvICFpbXBvcnRhbnQ7CiAgICAgICAgfQogICAgICAgIC54dGVybS12aWV3cG9ydDo6LXdlYmtpdC1zY3JvbGxiYXIgewogICAgICAgICAgICB3aWR0aDogNnB4OwogICAgICAgIH0KICAgICAgICAueHRlcm0tdmlld3BvcnQ6Oi13ZWJraXQtc2Nyb2xsYmFyLXRyYWNrIHsKICAgICAgICAgICAgYmFja2dyb3VuZDogdHJhbnNwYXJlbnQ7CiAgICAgICAgfQogICAgICAgIC54dGVybS12aWV3cG9ydDo6LXdlYmtpdC1zY3JvbGxiYXItdGh1bWIgewogICAgICAgICAgICBiYWNrZ3JvdW5kOiByZ2JhKDI1NSwgMjU1LCAyNTUsIDAuMik7CiAgICAgICAgICAgIGJvcmRlci1yYWRpdXM6IDNweDsKICAgICAgICB9CiAgICAgICAgLnh0ZXJtLXZpZXdwb3J0Ojotd2Via2l0LXNjcm9sbGJhci10aHVtYjpob3ZlciB7CiAgICAgICAgICAgIGJhY2tncm91bmQ6IHJnYmEoMjU1LCAyNTUsIDI1NSwgMC40KTsKICAgICAgICB9CiAgICA8L3N0eWxlPgo8L2hlYWQ+Cjxib2R5PgogICAgPGRpdiBpZD0idGVybWluYWwtY29udGFpbmVyIj48L2Rpdj4KICAgIDxzY3JpcHQgc3JjPSJ4dGVybS5qcyI+PC9zY3JpcHQ+CiAgICA8c2NyaXB0IHNyYz0ieHRlcm0tYWRkb24tZml0LmpzIj48L3NjcmlwdD4KICAgIDxzY3JpcHQ+CiAgICAgICAgdmFyIHRlcm0gPSBuZXcgVGVybWluYWwoewogICAgICAgICAgICBzY3JvbGxiYWNrOiA1MDAwLAogICAgICAgICAgICB0aGVtZTogewogICAgICAgICAgICAgICAgYmFja2dyb3VuZDogJyMwMDAwMDAwMCcsCiAgICAgICAgICAgICAgICBmb3JlZ3JvdW5kOiAnI0YxRjVGOScsCiAgICAgICAgICAgICAgICBjdXJzb3I6ICcjMzhCREY4JywKICAgICAgICAgICAgICAgIGN1cnNvckFjY2VudDogJyMwMDAwMDAnLAogICAgICAgICAgICAgICAgc2VsZWN0aW9uQmFja2dyb3VuZDogJ3JnYmEoNTYsIDE4OSwgMjQ4LCAwLjMpJywKICAgICAgICAgICAgICAgIGJsYWNrOiAnIzFFMjkzQicsCiAgICAgICAgICAgICAgICByZWQ6ICcjRUY0NDQ0JywKICAgICAgICAgICAgICAgIGdyZWVuOiAnIzEwQjk4MScsCiAgICAgICAgICAgICAgICB5ZWxsb3c6ICcjRjU5RTBCJywKICAgICAgICAgICAgICAgIGJsdWU6ICcjM0I4MkY2JywKICAgICAgICAgICAgICAgIG1hZ2VudGE6ICcjRUM0ODk5JywKICAgICAgICAgICAgICAgIGN5YW46ICcjMDZCNkQ0JywKICAgICAgICAgICAgICAgIHdoaXRlOiAnI0Y4RkFGQycsCiAgICAgICAgICAgICAgICBicmlnaHRCbGFjazogJyM2NDc0OEInLAogICAgICAgICAgICAgICAgYnJpZ2h0UmVkOiAnI0Y4NzE3MScsCiAgICAgICAgICAgICAgICBicmlnaHRHcmVlbjogJyMzNEQzOTknLAogICAgICAgICAgICAgICAgYnJpZ2h0WWVsbG93OiAnI0ZCQkYyNCcsCiAgICAgICAgICAgICAgICBicmlnaHRCbHVlOiAnIzYwQTVGQScsCiAgICAgICAgICAgICAgICBicmlnaHRNYWdlbnRhOiAnI0Y0NzJCNicsCiAgICAgICAgICAgICAgICBicmlnaHRDeWFuOiAnIzIyRDNFRScsCiAgICAgICAgICAgICAgICBicmlnaHRXaGl0ZTogJyNGRkZGRkYnCiAgICAgICAgICAgIH0sCiAgICAgICAgICAgIGZvbnRGYW1pbHk6ICciTWVzbG9MR1MgTkYiLCAiU0YgTW9ubyIsIE1lbmxvLCBNb25hY28sICJDYXNjYWRpYSBDb2RlIiwgIkZpcmEgQ29kZSIsICJKZXRCcmFpbnMgTW9ubyIsIG1vbm9zcGFjZScsCiAgICAgICAgICAgIGZvbnRTaXplOiAxMiwKICAgICAgICAgICAgbGluZUhlaWdodDogMS4yLAogICAgICAgICAgICBjdXJzb3JCbGluazogdHJ1ZSwKICAgICAgICAgICAgY3Vyc29yU3R5bGU6ICdibG9jaycsCiAgICAgICAgICAgIGFsbG93VHJhbnNwYXJlbmN5OiB0cnVlLAogICAgICAgICAgICBtYWNPcHRpb25Jc01ldGE6IHRydWUsCiAgICAgICAgICAgIHJpZ2h0Q2xpY2tTZWxlY3RzV29yZDogdHJ1ZQogICAgICAgIH0pOwogICAgICAgIHZhciBmaXRBZGRvbiA9IG5ldyBGaXRBZGRvbi5GaXRBZGRvbigpOwogICAgICAgIHRlcm0ubG9hZEFkZG9uKGZpdEFkZG9uKTsKICAgICAgICB0ZXJtLm9wZW4oZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3Rlcm1pbmFsLWNvbnRhaW5lcicpKTsKCiAgICAgICAgd2luZG93LndlYmtpdC5tZXNzYWdlSGFuZGxlcnMudGVybWluYWwucG9zdE1lc3NhZ2UoeyB0eXBlOiAicmVhZHkiIH0pOwoKICAgICAgICBmdW5jdGlvbiBkb0ZpdCgpIHsKICAgICAgICAgICAgdHJ5IHsKICAgICAgICAgICAgICAgIHZhciBlbCA9IGRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCd0ZXJtaW5hbC1jb250YWluZXInKTsKICAgICAgICAgICAgICAgIGlmICghZWwgfHwgZWwuY2xpZW50V2lkdGggPCA0MCB8fCBlbC5jbGllbnRIZWlnaHQgPCA0MCkgcmV0dXJuOwogICAgICAgICAgICAgICAgZml0QWRkb24uZml0KCk7CiAgICAgICAgICAgICAgICB0ZXJtLmZvY3VzKCk7CiAgICAgICAgICAgICAgICB0cnkgeyB0ZXJtLnNjcm9sbFRvQm90dG9tKCk7IH0gY2F0Y2goZSkge30KICAgICAgICAgICAgICAgIGlmICh0ZXJtLmNvbHMgPiAwICYmIHRlcm0ucm93cyA+IDApIHsKICAgICAgICAgICAgICAgICAgICB3aW5kb3cud2Via2l0Lm1lc3NhZ2VIYW5kbGVycy50ZXJtaW5hbC5wb3N0TWVzc2FnZSh7IHR5cGU6ICJyZXNpemUiLCBjb2xzOiB0ZXJtLmNvbHMsIHJvd3M6IHRlcm0ucm93cyB9KTsKICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfSBjYXRjaChlKSB7fQogICAgICAgIH0KCiAgICAgICAgZG9GaXQoKTsKICAgICAgICBzZXRUaW1lb3V0KGRvRml0LCA1MCk7CiAgICAgICAgc2V0VGltZW91dChkb0ZpdCwgMTUwKTsKICAgICAgICBzZXRUaW1lb3V0KGRvRml0LCAzMDApOwogICAgICAgIHNldFRpbWVvdXQoZG9GaXQsIDYwMCk7CgogICAgICAgIGNvbnN0IHJlc2l6ZU9ic2VydmVyID0gbmV3IFJlc2l6ZU9ic2VydmVyKCgpID0+IHsKICAgICAgICAgICAgZG9GaXQoKTsKICAgICAgICB9KTsKICAgICAgICByZXNpemVPYnNlcnZlci5vYnNlcnZlKGRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCd0ZXJtaW5hbC1jb250YWluZXInKSk7CgogICAgICAgIGRvY3VtZW50LmFkZEV2ZW50TGlzdGVuZXIoJ2NsaWNrJywgKCkgPT4gewogICAgICAgICAgICB0ZXJtLmZvY3VzKCk7CiAgICAgICAgfSk7CgogICAgICAgIHRlcm0ub25EYXRhKGUgPT4gewogICAgICAgICAgICB3aW5kb3cud2Via2l0Lm1lc3NhZ2VIYW5kbGVycy50ZXJtaW5hbC5wb3N0TWVzc2FnZSh7IHR5cGU6ICJkYXRhIiwgZGF0YTogZSB9KTsKICAgICAgICAgICAgdHJ5IHsgdGVybS5zY3JvbGxUb0JvdHRvbSgpOyB9IGNhdGNoKGVycikge30KICAgICAgICB9KTsKCiAgICAgICAgZnVuY3Rpb24gd3JpdGVEYXRhKGJhc2U2NCkgewogICAgICAgICAgICBjb25zdCBiaW5hcnkgPSBhdG9iKGJhc2U2NCk7CiAgICAgICAgICAgIGNvbnN0IGJ5dGVzID0gbmV3IFVpbnQ4QXJyYXkoYmluYXJ5Lmxlbmd0aCk7CiAgICAgICAgICAgIGZvciAobGV0IGkgPSAwOyBpIDwgYmluYXJ5Lmxlbmd0aDsgaSsrKSB7CiAgICAgICAgICAgICAgICBieXRlc1tpXSA9IGJpbmFyeS5jaGFyQ29kZUF0KGkpOwogICAgICAgICAgICB9CiAgICAgICAgICAgIHRlcm0ud3JpdGUoYnl0ZXMsICgpID0+IHsKICAgICAgICAgICAgICAgIHRyeSB7IHRlcm0uc2Nyb2xsVG9Cb3R0b20oKTsgfSBjYXRjaChlKSB7fQogICAgICAgICAgICB9KTsKICAgICAgICB9CgogICAgICAgIGZ1bmN0aW9uIGNsZWFyVGVybWluYWwoKSB7CiAgICAgICAgICAgIHRlcm0uY2xlYXIoKTsKICAgICAgICB9CiAgICA8L3NjcmlwdD4KPC9ib2R5Pgo8L2h0bWw+"
let terminalHTMLString = String(data: Data(base64Encoded: terminalHTMLBase64)!, encoding: .utf8)!