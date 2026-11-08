import Foundation
import Testing
@testable import NotchDinoApp

@Suite struct PackagingTests {
    private var script: String {
        get throws {
            let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            return try String(contentsOf: root.appendingPathComponent("scripts/build-app.sh"), encoding: .utf8)
        }
    }

    @Test func theAppAdvertisesTheSameBonjourTypeTheCodeUses() throws {
        #expect(try script.contains("<array><string>\(RaceBonjour.type)</string></array>"))
    }

    @Test func theAppIsAMenuBarAppThatExplainsLocalNetworkAndIsSigned() throws {
        let s = try script
        #expect(s.contains("<key>LSUIElement</key><true/>"))
        #expect(s.contains("<key>NSLocalNetworkUsageDescription</key>"))
        #expect(s.contains("<key>CFBundleIdentifier</key>"))
        #expect(s.contains("codesign --force --sign -"))
    }

    @Test func theAppCarriesItsIcon() throws {
        let s = try script
        #expect(s.contains("<key>CFBundleIconFile</key><string>AppIcon</string>"))
        #expect(s.contains("cp scripts/icon/AppIcon.icns \"$APP/Contents/Resources/AppIcon.icns\""))
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("scripts/icon/AppIcon.icns").path))
    }

    @Test func theReadmeSaysHowToBuildTheApp() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let readme = try String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8)
        #expect(readme.contains("scripts/build-app.sh     # Notch Dino.app in .build/app (ad-hoc signed); needed for racing"))
    }
}
