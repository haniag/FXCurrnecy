//
//  Theme.swift
//  oumleh
//
//  The app's own colours, kept in one place so they're easy to find and change.
//

import SwiftUI

extension Color {
    /// Build a colour from a 0xRRGGBB literal, so colours can be written the
    /// same way they're specified.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Ledger design
//
// Paper, ink and thin rules, like a printed rates table. The values are pinned
// light rather than adaptive, and the app keeps itself in light mode to match
// (see `ContentView`).

extension Color {
    /// The screen behind everything: warm paper rather than white.
    static let paper = Color(hex: 0xF4F1E8)

    /// Text, and the heavy rule under the main currency.
    static let ink = Color(hex: 0x1A1916)

    /// Names, captions and small labels. Still dark enough to read at small
    /// sizes on paper (about 5:1).
    static let inkSecondary = Color(hex: 0x6B665B)

    /// The thin lines between rows.
    static let hairline = Color(hex: 0x1A1916).opacity(0.14)

    /// The design's one accent: the checkmarks in the add sheet.
    static let terracotta = Color(hex: 0xB4462B)
}

// MARK: - Fonts
//
// San Francisco throughout: `.system` resolves to it on Apple platforms, so
// there's no font file to bundle. Numbers are SF Mono, whose fixed-width digits
// keep amounts from shifting sideways as they change.

extension Font {
    /// The main currency's amount and code, "1 USD", in SF Mono Bold. The size
    /// is a parameter because the line shrinks to fit a long amount on one line.
    static func headerAmount(size: CGFloat = 50) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }

    /// A row's converted amount.
    static let rowAmount = Font.system(size: 25, weight: .bold, design: .monospaced)

    /// The rates in the add sheet.
    static let listRate = Font.system(size: 20, weight: .bold, design: .monospaced)

    /// A row's currency code, "ILS".
    static let rowCode = Font.system(size: 14, weight: .bold)
}

extension View {
    /// Small spaced capitals: "RATES AS OF 15:03", and the main currency's
    /// name above its amount.
    func ledgerLabel() -> some View {
        font(.caption2.weight(.semibold))
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundStyle(Color.inkSecondary)
    }
}
