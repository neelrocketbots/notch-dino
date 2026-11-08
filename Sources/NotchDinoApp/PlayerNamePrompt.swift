import AppKit
import RaceCore

/// Player Name…: a small alert with a text field. The name is what nearby players see.
enum PlayerNamePrompt {
    /// The name to keep: the entry cleaned, or the current name when the entry is blank.
    static func resolve(_ entry: String, current: String) -> String {
        entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? current : RaceName.clean(entry)
    }

    /// Asks for a name; nil when cancelled.
    @MainActor static func ask(current: String) -> String? {
        let alert = NSAlert()
        alert.messageText = "Player Name"
        alert.informativeText = "Nearby players see this name when you race. Up to 12 characters."
        let field = NSTextField(string: current)
        field.frame = CGRect(x: 0, y: 0, width: 220, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return resolve(field.stringValue, current: current)
    }
}
