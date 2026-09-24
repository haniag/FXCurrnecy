//
//  FlagIcon.swift
//  oumleh
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
    let countryCode: String
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
        if hasFlag {
            Image(countryCode)
                .resizable()
                // Fills the circle, trimming the left and right edges rather
                // than letterboxing a 7:5 flag into a square.
                .scaledToFill()
        } else {
            NeutralFlag(code: countryCode)
        }
    }

    /// False for currencies with no country behind them — the metals ("XAU"),
    /// the IMF's "XDR", the shared regional codes ("XOF") — which get a badge.
    private var hasFlag: Bool { UIImage(named: countryCode) != nil }
}

/// Fallback for currencies that aren't country based.
private struct NeutralFlag: View {
    let code: String

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemGray3)
                Text(code)
                    .font(.system(size: geo.size.height * 0.38, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview("Flags") {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            ForEach(Currency.starterList) { currency in
                FlagIcon(countryCode: currency.countryCode)
            }
            FlagIcon(countryCode: "ZZ")   // no such country: the fallback badge
        }
        // Larger, to check the vectors stay sharp when scaled up.
        HStack(spacing: 16) {
            ForEach(Currency.starterList) { currency in
                FlagIcon(countryCode: currency.countryCode, diameter: 84)
            }
        }
    }
    .padding()
}
