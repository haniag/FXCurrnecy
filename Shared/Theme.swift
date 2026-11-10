//
//  Theme.swift
//  FX
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

    /// Text.
    static let ink = Color(hex: 0x1A1916)

    /// Names, captions and small labels. Still dark enough to read at small
    /// sizes on paper (about 5:1).
    static let inkSecondary = Color(hex: 0x6B665B)

    /// The thin lines between rows.
    static let hairline = Color(hex: 0x1A1916).opacity(0.14)

    /// The design's one accent: the edge of the main currency's row, and the
    /// checkmarks in the add sheet.
    static let terracotta = Color(hex: 0xB4462B)
}

// MARK: - Fonts
//
// San Francisco throughout: `.system` resolves to it on Apple platforms, so
// there's no font file to bundle. Numbers are SF Mono, whose fixed-width digits
// keep amounts from shifting sideways as they change.
//
// The sizes are the design's own rather than the system's text styles, so each
// one names the style it grows and shrinks with: at the default text size it's
// exactly the size below, and it follows the user's setting from there.

enum LedgerFont {
    /// A row's converted amount.
    case rowAmount
    /// The rates in the add sheet.
    case listRate
    /// A row's currency code, "ILS".
    case rowCode
    /// The add sheet's heading.
    case sheetTitle

    /// The size at the default text size.
    var size: CGFloat {
        switch self {
        case .rowAmount: 25
        case .listRate: 20
        case .rowCode: 14
        case .sheetTitle: 32
        }
    }

    var weight: Font.Weight {
        switch self {
        case .rowAmount, .listRate, .rowCode: .bold
        case .sheetTitle: .semibold
        }
    }

    var design: Font.Design {
        switch self {
        case .rowAmount, .listRate: .monospaced
        case .rowCode, .sheetTitle: .default
        }
    }

    /// The system style this one scales alongside.
    var textStyle: Font.TextStyle {
        switch self {
        case .rowAmount: .title2
        case .listRate: .title3
        case .rowCode: .footnote
        case .sheetTitle: .largeTitle
        }
    }
}

/// Applies a `LedgerFont` at the user's text size.
private struct ScaledLedgerFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let font: LedgerFont

    init(_ font: LedgerFont) {
        self.font = font
        _size = ScaledMetric(wrappedValue: font.size, relativeTo: font.textStyle)
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: font.weight, design: font.design))
    }
}

extension View {
    /// One of the design's own fonts, scaled with the user's text size.
    func ledgerFont(_ font: LedgerFont) -> some View {
        modifier(ScaledLedgerFont(font))
    }

    /// Small spaced capitals: "RATES AS OF 15:03".
    func ledgerLabel() -> some View {
        font(.caption2.weight(.semibold))
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundStyle(Color.inkSecondary)
    }
}
