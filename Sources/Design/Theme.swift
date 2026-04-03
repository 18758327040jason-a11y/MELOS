import SwiftUI

// MARK: - Theme Design System

enum Theme {

    // MARK: - Palette (scheme-aware, accessed via environment)

    struct Palette {
        let scheme: ColorScheme

        var accent: Color { Color(hex: "4285F4") }
        var accentLight: Color { scheme == .dark ? Color(hex: "1A3A6B") : Color(hex: "D2E3FC") }
        var accentDark: Color { Color(hex: "1A73E8") }

        var bgPrimary: Color { scheme == .dark ? Color(hex: "121212") : Color(hex: "FFFFFF") }
        var bgSecondary: Color { scheme == .dark ? Color(hex: "1E1E1E") : Color(hex: "F8F9FA") }
        var bgTertiary: Color { scheme == .dark ? Color(hex: "2D2D2D") : Color(hex: "F1F3F4") }
        var bgElevated: Color { scheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "FFFFFF") }

        var textPrimary: Color { scheme == .dark ? Color(hex: "E8EAED") : Color(hex: "202124") }
        var textSecondary: Color { scheme == .dark ? Color(hex: "B4B7BB") : Color(hex: "5F6368") }
        var textTertiary: Color { scheme == .dark ? Color(hex: "80868B") : Color(hex: "9AA0A6") }

        var hover: Color { scheme == .dark ? Color(hex: "2D3A4F") : Color(hex: "E8F0FE") }
        var active: Color { scheme == .dark ? Color(hex: "1A3A6B") : Color(hex: "D2E3FC") }
        var divider: Color { scheme == .dark ? Color(hex: "3D3D3D") : Color(hex: "E8EAED") }

        var playing: Color { Color(hex: "1A73E8") }
        var progressBar: Color { scheme == .dark ? Color(hex: "3D3D3D") : Color(hex: "DADCE0") }
        var progressFill: Color { Color(hex: "4285F4") }

        var volumeIcon: Color { scheme == .dark ? Color(hex: "80868B") : Color(hex: "9AA0A6") }
        var volumeBar: Color { scheme == .dark ? Color(hex: "3D3D3D") : Color(hex: "DADCE0") }
        var volumeFill: Color { Color(hex: "4285F4") }

        static let qq = Color(hex: "31C34A")
        static let netease = Color(hex: "C20C0C")

        var error: Color { scheme == .dark ? Color(hex: "F28B82") : Color(hex: "EA4335") }
        var errorBg: Color { scheme == .dark ? Color(hex: "3D1A1A") : Color(hex: "FCE8E6") }

        static let success = Color(hex: "34A853")
    }

    struct FontSize {
        static let title: CGFloat = 22
        static let heading: CGFloat = 16
        static let body: CGFloat = 14
        static let caption: CGFloat = 12
        static let small: CGFloat = 11
    }

    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    struct Radius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let pill: CGFloat = 28
    }

    struct Sizes {
        static let albumArtSmall: CGFloat = 44
        static let albumArtLarge: CGFloat = 140
        static let sidebarWidth: CGFloat = 260
        static let playerBarHeight: CGFloat = 88
        static let miniPlayerHeight: CGFloat = 64
        static let rightPanelWidth: CGFloat = 320
        static let playButtonSmall: CGFloat = 32
        static let playButtonLarge: CGFloat = 52
    }

    struct Anim {
        static let fast = Animation.easeOut(duration: 0.15)
        static let medium = Animation.easeOut(duration: 0.2)
        static let slow = Animation.easeInOut(duration: 0.3)
    }
}

// MARK: - ThemeColors EnvironmentKey (auto-injected per view)

struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue: Theme.Palette = Theme.Palette(scheme: .light)
}

extension EnvironmentValues {
    var themeColors: Theme.Palette {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}

// MARK: - Themed Modifier (sets theme palette in env for all children)

struct Themed: ViewModifier {
    @AppStorage("darkModeOverride") var darkModeOverride: Bool?
    @Environment(\.colorScheme) var systemScheme

    var effectiveScheme: ColorScheme {
        switch darkModeOverride {
        case .some(true): return .dark
        case .some(false): return .light
        case nil: return systemScheme
        }
    }

    func body(content: Content) -> some View {
        content
            .environment(\.themeColors, Theme.Palette(scheme: effectiveScheme))
            .preferredColorScheme(effectiveScheme)
    }
}

extension View {
    func themed() -> some View {
        modifier(Themed())
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
