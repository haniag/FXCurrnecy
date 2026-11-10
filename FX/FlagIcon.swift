//
//  FlagIcon.swift
//  FX
//

import SwiftUI

/// A flat, circular flag for a currency.
///
/// The artwork is FlagKit's (MIT — see `Flags.xcassets/FlagKit-LICENSE.txt`),
/// vendored as SVGs in `Flags.xcassets` rather than added as a Swift package.
/// The package ships 21x15pt PNGs, which these 35pt circles would blow up
/// almost 3x; the SVGs are vectors, so they stay sharp at any size and there's
/// no dependency to manage.
///
/// Each flag keeps its natural 7:5 proportion and is cropped to a circle — the
/// same trick circular flag icon sets use.
struct FlagIcon: View {
    let currency: Currency
    var diameter: CGFloat = 25

    var body: some View {
        flag
            .frame(width: diameter, height: diameter)
            .clipShape(.circle)
            .overlay {
                Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var flag: some View {
        if let flagName {
            Image(flagName)
                .resizable()
                // Fills the circle, trimming the left and right edges rather
                // than letterboxing a 7:5 flag into a square.
                .scaledToFill()
        } else {
            NeutralFlag(code: currency.code)
        }
    }

    /// Nil for currencies with no country behind them — the metals ("XAU"),
    /// the IMF's "XDR", the shared regional codes ("XOF") — and for a country
    /// there's no artwork for. Those get a badge.
    private var flagName: String? {
        guard let country = currency.countryCode, UIImage(named: country) != nil else { return nil }
        return country
    }
}

/// Fallback for currencies that aren't country based: the currency's own
/// code, in full, so gold ("XAU") and silver ("XAG") don't both read "XA".
private struct NeutralFlag: View {
    let code: String

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemGray3)
                Text(code)
                    // Three letters across the circle, with room either side.
                    .font(.system(size: geo.size.height * 0.3, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, geo.size.width * 0.08)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

#if DEBUG

#Preview("Flags") {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            ForEach(Currency.starterList) { currency in
                FlagIcon(currency: currency)
            }
            // No country behind these: the badge, with the full code.
            FlagIcon(currency: Currency(code: "XAU", name: "Gold Ounce"))
            FlagIcon(currency: Currency(code: "BTC", name: "Bitcoin"))
        }
        // Larger, to check the vectors stay sharp when scaled up.
        HStack(spacing: 16) {
            ForEach(Currency.starterList) { currency in
                FlagIcon(currency: currency, diameter: 84)
            }
        }
    }
    .padding()
}

#endif
