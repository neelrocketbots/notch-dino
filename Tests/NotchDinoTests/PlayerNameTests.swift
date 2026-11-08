import Testing
@testable import NotchDinoApp

@Suite struct PlayerNameTests {
    @Test func anEmptyEntryKeepsTheCurrentName() {
        #expect(PlayerNamePrompt.resolve("   \n", current: "Neel") == "Neel")
    }

    @Test func entriesAreCleanedTo12Characters() {
        #expect(PlayerNamePrompt.resolve(" Ana\n", current: "Neel") == "Ana")
        #expect(PlayerNamePrompt.resolve("Bartholomew-Jones", current: "Neel") == "Bartholomew-")
        #expect(PlayerNamePrompt.resolve("A\u{202E}na", current: "Neel") == "Ana")
    }

    @Test func thePrivacyPaneLinkIsLocalNetwork() {
        #expect(AppDelegate.localNetworkSettings.absoluteString
                == "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork")
    }
}
