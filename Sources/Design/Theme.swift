import SwiftUI

// MARK: - Design System

enum Theme {
    // MARK: - Colors

    struct Palette {
        // Accent
        static let accent = Color(hex: "4285F4")        // Google Blue
        static let accentLight = Color(hex: "D2E3FC")
        static let accentDark = Color(hex: "1A73E8")

        // Backgrounds
        static let bgPrimary = Color(hex: "FFFFFF")
        static let bgSecondary = Color(hex: "F8F9FA")
        static let bgTertiary = Color(hex: "F1F3F4")
        static let bgElevated = Color(hex: "FFFFFF")

        // Text
        static let textPrimary = Color(hex: "202124")
        static let textSecondary = Color(hex: "5F6368")
        static let textTertiary = Color(hex: "9AA0A6")

        // Interactive
        static let hover = Color(hex: "E8F0FE")
        static let active = Color(hex: "D2E3FC")
        static let divider = Color(hex: "E8EAED")

        // Playback
        static let playing = Color(hex: "1A73E8")
        static let progressBar = Color(hex: "DADCE0")
        static let progressFill = Color(hex: "4285F4")

        // Volume
        static let volumeIcon = Color(hex: "9AA0A6")
        static let volumeBar = Color(hex: "DADCE0")
        static let volumeFill = Color(hex: "4285F4")

        // Platform
        static let qq = Color(hex: "31C34A")
        static let netease = Color(hex: "C20C0C")

        // Error
        static let error = Color(hex: "EA4335")
        static let errorBg = Color(hex: "FCE8E6")

        // Success
        static let success = Color(hex: "34A853")
    }

    // MARK: - Font Sizes

    struct FontSize {
        static let title: CGFloat = 22
        static let heading: CGFloat = 16
        static let body: CGFloat = 14
        static let caption: CGFloat = 12
        static let small: CGFloat = 11
    }

    // MARK: - Spacing (8pt grid)

    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    struct Radius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let pill: CGFloat = 28
    }

    // MARK: - Sizes

    struct Sizes {
        static let albumArtSmall: CGFloat = 44
        static let albumArtLarge: CGFloat = 140
        static let sidebarWidth: CGFloat = 260
        static let playerBarHeight: CGFloat = 88
        static let playButtonSmall: CGFloat = 32
        static let playButtonLarge: CGFloat = 52
    }

    // MARK: - Transitions

    struct Anim {
        static let fast = Animation.easeOut(duration: 0.15)
        static let medium = Animation.easeOut(duration: 0.2)
        static let slow = Animation.easeInOut(duration: 0.3)
    }
}
