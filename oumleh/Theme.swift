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

    /// Background of every currency card.
    ///
    /// A hair darker than white, then made translucent. Both halves matter:
    /// the tint is what gives a card its edge once the gradient has run out
    /// and the screen behind it is plain white, and the translucency is what
    /// lets the top cards pick up the periwinkle they're sitting in.
    ///
    /// Translucent *white* can't do this. It's invisible against white, which
    /// is most of the screen now.
    static let currencyCard = Color(hex: 0xF1F3F8).opacity(0.75)

    /// Border of the currency the user is editing.
    static let currencySelection = Color(hex: 0x384EDF)

    /// Text on a currency card. Pinned, because the card colour is pinned too:
    /// left adaptive, it would turn white in dark mode and vanish.
    static let currencyCardText = Color(hex: 0x000000)
}

// MARK: - Background

extension LinearGradient {
    /// The screen behind everything: full-strength periwinkle at the very top,
    /// gone by roughly a third of the way down. Plain white from there on.
    ///
    /// The stops are that one colour mixed toward white along a smoothstep —
    /// full, 84%, 50%, 16%, none — which is gentle at *both* ends. That's the
    /// point of it: the colour holds near full strength across the top before
    /// it starts dropping, and it eases into white rather than arriving at it.
    ///
    /// An ease-out was tried first and gave up its colour far too early; a
    /// straight ramp holds on, but hitting white and stopping dead leaves a
    /// seam you can pick out across the screen, even though the white above
    /// and below it is identical — the eye reads the change in slope, not in
    /// colour. Smoothstep is the curve that does both.
    ///
    /// Pinned light values, like the card colours above — the cards' text is
    /// pinned black, so the whole screen is a light-mode design already.
    static let screen = LinearGradient(
        stops: [
            .init(color: Color(hex: 0x9FAAF2), location: 0.00),
            .init(color: Color(hex: 0xAEB7F4), location: 0.08),
            .init(color: Color(hex: 0xCFD5F9), location: 0.16),
            .init(color: Color(hex: 0xF0F2FD), location: 0.24),
            .init(color: Color(hex: 0xFFFFFF), location: 0.32),
            .init(color: Color(hex: 0xFFFFFF), location: 1.00),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Fonts

extension Font {
    /// San Francisco. `.system` resolves to SF on Apple platforms, so there's
    /// no font file to bundle. `.monospaced` is SF Mono, whose fixed-width
    /// digits keep the amounts from shifting sideways as every row re-renders
    /// while the user types.
    static let currencyCode = Font.system(size: 20, weight: .bold, design: .monospaced)

    /// The amount on a currency card.
    static let currencyAmount = Font.system(size: 20, weight: .bold, design: .monospaced)
}
