//
//  LedgerRowView.swift
//  oumleh
//

import SwiftUI

/// One row of the list below the main currency: flag, code and name on the
/// left; the converted amount and the rate the other way on the right.
///
/// Read-only. Tapping a row makes it the main currency, but that's the list's
/// job; the row only draws.
struct LedgerRowView: View {
    let currency: Currency
    /// The converted amount, already formatted ("3.012"), or "—" with no rate.
    let amount: String
    /// "1 ILS = 0.332 USD", or nil while there's no rate to show.
    let inverseRate: String?

    var body: some View {
        HStack(spacing: 14) {
            FlagIcon(countryCode: currency.countryCode, diameter: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(currency.code)
                    .font(.rowCode)
                    .tracking(0.8)
                Text(currency.name)
                    .font(.footnote)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                Text(amount)
                    .font(.rowAmount)
                    .lineLimit(1)
                    // A very long amount shrinks rather than squeezing the name.
                    .minimumScaleFactor(0.6)
                if let inverseRate {
                    Text(inverseRate)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                }
            }
        }
        .foregroundStyle(Color.ink)
        .padding(.vertical, 16)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Rows") {
    VStack(spacing: 0) {
        LedgerRowView(
            currency: Currency(code: "ILS", name: "Israeli Shekel"),
            amount: "3.012",
            inverseRate: "1 ILS = 0.332 USD"
        )
        Rectangle().fill(Color.hairline).frame(height: 1)
        LedgerRowView(
            currency: Currency(code: "TRY", name: "Turkish Lira"),
            amount: "48.811",
            inverseRate: "1 TRY = 0.0205 USD"
        )
        Rectangle().fill(Color.hairline).frame(height: 1)
        // No rate yet: a dash, and no line underneath it.
        LedgerRowView(
            currency: Currency(code: "JOD", name: "Jordanian Dinar"),
            amount: "—",
            inverseRate: nil
        )
    }
    .padding(.horizontal, 20)
    .background(Color.paper)
}
