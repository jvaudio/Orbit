import AppKit
import Observation

@MainActor @Observable
final class AppAppearanceSettings {
    enum Mode: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    var mode: Mode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "orbit.appearance")
            apply()
        }
    }

    init() {
        mode = Mode(rawValue: UserDefaults.standard.string(forKey: "orbit.appearance") ?? "") ?? .system
    }

    func apply() {
        switch mode {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
