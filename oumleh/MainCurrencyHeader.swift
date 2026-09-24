//
//  MainCurrencyHeader.swift
//  oumleh
//

import SwiftUI

/// The top of the main screen: which currency everything is quoted against,
/// and how much of it.
///
/// The name above the amount is a menu for picking a different main currency.
/// The amount is the one field the user types into; every row below is worked
/// out from it.
struct MainCurrencyHeader: View {
    let currency: Currency
    /// The whole list, offered in the menu.
    let choices: [Currency]
    @Binding var text: String
    @FocusState.Binding var focusedCode: String?
    let onChoose: (Currency) -> Void

    /// How wide the amount line may get, measured, so a long amount can shrink
    /// to fit on one line.
    @State private var availableWidth: CGFloat = 350

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            picker
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

    private var picker: some View {
        Menu {
            ForEach(choices) { choice in
                Button {
                    onChoose(choice)
                } label: {
                    if choice == currency {
                        Label("\(choice.name) (\(choice.code))", systemImage: "checkmark")
                    } else {
                        Text("\(choice.name) (\(choice.code))")
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                FlagIcon(countryCode: currency.countryCode, diameter: 20)
                Text(currency.name)
                    .ledgerLabel()
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.inkSecondary)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .accessibilityLabel("Main currency: \(currency.name)")
        .accessibilityHint("Choose a different main currency")
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
        choices: Currency.starterList,
        text: $amount,
        focusedCode: $focusedCode,
        onChoose: { _ in }
    )
    .background(Color.paper)
}

/// Long enough that the line has to shrink to stay on one line.
#Preview("Long amount") {
    @Previewable @State var amount = "1234567.89"
    @Previewable @FocusState var focusedCode: String?

    MainCurrencyHeader(
        currency: Currency(code: "JOD", name: "Jordanian Dinar"),
        choices: Currency.starterList,
        text: $amount,
        focusedCode: $focusedCode,
        onChoose: { _ in }
    )
    .background(Color.paper)
}
