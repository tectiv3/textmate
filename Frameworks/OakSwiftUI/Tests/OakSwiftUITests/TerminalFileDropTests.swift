import AppKit
import Testing
@testable import OakSwiftUI

@Test func terminalFileDropQuoting() {
    #expect(TerminalFileDrop.quote("/usr/bin/env") == "/usr/bin/env")
    #expect(TerminalFileDrop.quote("/tmp/a file (1).txt") == "/tmp/a\\ file\\ \\(1\\).txt")
    #expect(TerminalFileDrop.quote("/tmp/it's$HOME&;~*") == "/tmp/it\\'s\\$HOME\\&\\;\\~\\*")
    #expect(TerminalFileDrop.quote("/tmp/日本語 ファイル") == "/tmp/日本語\\ ファイル")
    #expect(TerminalFileDrop.quote("/tmp/a\nb") == nil)
    #expect(TerminalFileDrop.quote("/tmp/esc\u{1B}") == nil)
    #expect(TerminalFileDrop.quote("/tmp/del\u{7F}") == nil)
    let urls = [URL(fileURLWithPath: "/tmp/one"), URL(fileURLWithPath: "/tmp/two words")]
    #expect(TerminalFileDrop.text(for: urls) == "/tmp/one /tmp/two\\ words ")
    #expect(TerminalFileDrop.text(for: []) == nil)
    let mixed = [URL(fileURLWithPath: "/tmp/bad\nname"), URL(fileURLWithPath: "/tmp/good")]
    #expect(TerminalFileDrop.text(for: mixed) == "/tmp/good ")
    #expect(TerminalFileDrop.text(for: [URL(fileURLWithPath: "/tmp/bad\nname")]) == nil)
}

/// Each shell must turn the quoted text back into the exact original argument bytes.
@Test func terminalFileDropQuotingRoundTripsThroughShells() throws {
    let path = "/tmp/it's a \"file\" (1) $HOME `x` \\ & ; | < > * ? [a] {b,c} ~ ! # 日本語 cafe\u{301}"
    let quoted = try #require(TerminalFileDrop.quote(path))
    let shells = ["/bin/sh", "/bin/bash", "/bin/zsh", "/bin/dash", "/bin/ksh"].filter { FileManager.default.isExecutableFile(atPath: $0) }
    #expect(!shells.isEmpty)
    for shell in shells {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-c", "printf '%s' " + quoted]
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(data == Data(path.utf8), "\(shell)")
    }
}

@MainActor
@Test func terminalFileDropReadsOnlyFileURLs() {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("TextMate terminal drop \(UUID().uuidString)"))
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.writeObjects([URL(string: "https://example.com/file")! as NSURL])
    #expect(!TerminalFileDrop.canAccept(pasteboard))
    pasteboard.clearContents()
    pasteboard.writeObjects([URL(fileURLWithPath: "/tmp/dropped file") as NSURL])
    #expect(TerminalFileDrop.canAccept(pasteboard))
    #expect(TerminalFileDrop.text(for: TerminalFileDrop.fileURLs(from: pasteboard)) == "/tmp/dropped\\ file ")
}

@MainActor
@Test func terminalTabRenameOverridesShellTitle() async throws {
    _ = NSApplication.shared
    let controller = makeTerminalController()
    controller.startSession()
    defer { controller.stopSession() }
    let terminal = try #require(controller.terminal)
    controller.setTerminalTitle(source: terminal, title: "shell title")
    #expect(controller.sessionTitles == ["shell title"])
    controller.renameSession(at: 0, title: "  Build\u{07} server  ")
    #expect(controller.sessionTitles == ["Build server"])
    controller.setTerminalTitle(source: terminal, title: "later shell title")
    #expect(controller.sessionTitles == ["Build server"])
    controller.renameSession(at: 0, title: "   ")
    #expect(controller.sessionTitles == ["later shell title"])
    controller.renameSession(at: 5, title: "out of range")
    #expect(controller.sessionTitles == ["later shell title"])
}
