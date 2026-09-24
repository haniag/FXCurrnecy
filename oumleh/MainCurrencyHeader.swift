//
//  MainCurrencyHeader.swift
//  oumleh
//

import SwiftUI

/// The top of the main screen: which currency everything is quoted against,
/// and how much of it.
///
/// The amount is the one field the user types into; every row below is worked
/// out from it. To change the main currency, the user taps one of those rows.
struct MainCurrencyHeader: View {
    let currency: Currency
    @Binding var text: String
    @FocusState.Binding var focusedCode: String?

    /// How wide the amount line may get, measured, so a long amount can shrink
    /// to fit on one line.
    @State private var availableWidth: CGFloat = 350

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            nameLine
            amountLine
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            // The heavy rule between the main currency and the rest.
            Rectangle().fill(Color.ink).frame(height: 1.5)
        }
    }

    /// Flag and name, "US DOLLAR", above the amount.
    private var nameLine: some View {
        HStack(spacing: 8) {
            FlagIcon(countryCode: currency.countryCode, diameter: 20)
            Text(currency.name)
                .ledgerLabel()
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Main currency: \(currency.name)")
    }

    private var amountLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            TextField("1", text: $text)
                .keyboardType(.decimalPad)
                // As wide as what's typed, so the code sits right after it.
                .fixedSize()
                .focused($focusedCode, equals: currency.code)
                .accessibilityLabel("Amount in \(currency.name)")
            Text(currency.code)
                .accessibilityHidden(true)
        }
        .font(.headerAmount(size: fontSize))
        .foregroundStyle(Color.ink)
        .tint(Color.ink)   // the caret
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            availableWidth = width
        }
    }

    /// 50 points until the amount gets long, then smaller, so both "1 USD" and
    /// "1234567.89 USD" fit on one line. Every SF Mono character is 0.6 of the
    /// font size wide, which makes the width easy to predict.
    private var fontSize: CGFloat {
        let characters = CGFloat(max(text.count, 1) + currency.code.count)
        let fitting = (availableWidth - 14) / (characters * 0.62)
        return min(50, floor(fitting))
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

/// Long enough that the line has to shrink to stay on one line.
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
