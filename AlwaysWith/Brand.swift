import SwiftUI

extension Color {
    static let brandAccent = Color(red: 0x2F / 255, green: 0x6F / 255, blue: 0xE0 / 255)
    static let brandAccentDark = Color(red: 0x1F / 255, green: 0x57 / 255, blue: 0xC4 / 255)
    static let brandAccentTint = Color(red: 0x2F / 255, green: 0x6F / 255, blue: 0xE0 / 255).opacity(0.12)
    static let brandSuccess = Color(red: 0x1F / 255, green: 0x9D / 255, blue: 0x57 / 255)
    static let brandSidebarBackground = Color(red: 0xFC / 255, green: 0xFB / 255, blue: 0xFA / 255)
    static let brandToolbarBackground = Color(red: 0xEC / 255, green: 0xEC / 255, blue: 0xEC / 255)
    static let brandHairline = Color.black.opacity(0.09)
    static let brandTertiaryLabel = Color(red: 0x9A / 255, green: 0x9A / 255, blue: 0x9E / 255)
}

extension Font {
    static func nunitoExtraBold(size: CGFloat) -> Font {
        Font.custom("Nunito-ExtraBold", size: size)
    }

    static func nunitoSemiBold(size: CGFloat) -> Font {
        Font.custom("Nunito-SemiBold", size: size)
    }

    static func nunitoBold(size: CGFloat) -> Font {
        Font.custom("Nunito-Bold", size: size)
    }
}
