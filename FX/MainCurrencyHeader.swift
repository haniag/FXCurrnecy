//
//  MainCurrencyHeader.swift
//  oumleh
//

import SwiftUI

/// The top of the main screen: which currency everything is quoted against,
/// and how much of it.
///
/// Laid out like the rows below it — flag, code and name on the left, the
/// amount on the right — and marked out by a terracotta edge rather than a
/// heavy rule. The amount is the one field the user types into; every row
/// below is worked out from it. To change the main currency, the user taps one
/// of those rows.
struct MainCurrencyHeader: View {
    let currency: Currency
    @Binding var text: String
    @FocusState.Binding var focusedCode: String?

    /// How wide the amount may get, measured, so a long amount can shrink to
    /// fit on one line.
    @State private var availableWidth: CGFloat = 200

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
            // The name keeps its room; a long amount shrinks instead.
            .layoutPriority(1)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Main currency: \(currency.name)")

            Spacer(minLength: 12)

            amountField
        }
        .foregroundStyle(Color.ink)
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        // Tapping anywhere on the row starts typing, not just on the number.
        .contentShape(.rect)
        .onTapGesture { focusedCode = currency.code }
        .overlay(alignment: .leading) {
            // The mark that sets the main currency apart from the rest.
            Rectangle().fill(Color.terracotta).frame(width: 5)
        }
        .overlay(alignment: .bottom) {
            // The same thin line as between the rows, lined up with theirs,
            // which the list runs a few points nearer the right edge.
            Rectangle().fill(Color.hairline).frame(height: 1)
                .padding(.leading, 20)
                .padding(.trailing, 16)
        }
    }

    private var amountField: some View {
        TextField("1", text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
            .tint(Color.ink)   // the caret
            .focused($focusedCode, equals: currency.code)
            .accessibilityLabel("Amount in \(currency.name)")
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                availableWidth = width
            }
    }

    /// The rows' amount size until the amount gets long, then smaller, so it
    /// stays on one line. Every SF Mono character is 0.6 of the font size wide,
    /// which makes the width easy to predict.
    private var fontSize: CGFloat {
        let characters = CGFloat(max(text.count, 1))
        let fitting = availableWidth / (characters * 0.62)
        return max(14, min(25, floor(fitting)))
    }
}

// MARK: - Previews

#Preview("Header") {
    @Previewable @State var amount = "1"
    @Previewable @FocusState var focusedCode: String?

    MainCurrencyHeader(
        currency: Currency(code: "USD", name: "US Dollar"),
        text: $amount,
        focusedCode: $focusedCode
    )
    .background(Color.paper)
}

/// Long enough that the amount has to shrink to stay on one line.
#Preview("Long amount") {
    @Previewable @State var amount = "1234567.89"
    @Previewable @FocusState var focusedCode: String?

    MainCurrencyHeader(
        currency: Currency(code: "JOD", name: "Jordanian Dinar"),
        text: $amount,
        focusedCode: $focusedCode
    )
    .background(Color.paper)
}
