//
//  CurrencyRowView.swift
//  oumleh
//

import SwiftUI

/// One currency card: flag, code, and the editable amount.
struct CurrencyRowView: View {
    let currency: Currency
    @Binding var text: String
    let isMain: Bool
    @FocusState.Binding var focusedCode: String?

    private var isFocused: Bool { focusedCode == currency.code }

    var body: some View {
        HStack(spacing: 14) {
            FlagIcon(countryCode: currency.countryCode)

            Text(currency.code)
                .font(.currencyCode)

            Spacer(minLength: 12)

            TextField("1.0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.currencyAmount)
                .focused($focusedCode, equals: currency.code)
                .accessibilityLabel("\(currency.name) amount")
        }
        .foregroundStyle(Color.currencyCardText)
        .tint(Color.currencySelection)   // the caret
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(Color.currencyCard, in: .rect(cornerRadius: 26))
        .overlay {
            // The row being typed into is marked by its border alone. The
            // animation is scoped to the border rather than the whole card, so
            // it can't interfere with the List's own drag animations.
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(Color.currencySelection, lineWidth: isFocused ? 2 : 0)
                .animation(.easeOut(duration: 0.15), value: isFocused)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(isMain ? "Main currency" : "")
    }
}

#Preview("Row") {
    @Previewable @State var amount = "3.01"
    @Previewable @FocusState var focusedCode: String?

    VStack(spacing: 14) {
        CurrencyRowView(
            currency: Currency(code: "USD", name: "US Dollar"),
            text: .constant("1"),
            isMain: true,
            focusedCode: $focusedCode
        )
        CurrencyRowView(
            currency: Currency(code: "ILS", name: "Israeli Shekel"),
            text: $amount,
            isMain: false,
            focusedCode: $focusedCode
        )
    }
    .padding(.horizontal, 16)
}
