//
//  NumberTextTests.swift
//  FXTests
//

import Foundation
import Testing
@testable import FX

/// Reading typed text and printing amounts. Locales and separators are passed
/// in, so these don't depend on how the simulator happens to be set up.
struct NumberTextTests {

    private let english = Locale(identifier: "en_US")

    // MARK: - Reading

    @Test func keepsDigitsAndOneSeparator() {
        #expect(NumberText.sanitize("12.5", decimalSeparator: ".", groupingSeparator: ",") == "12.5")
        #expect(NumberText.sanitize("1.2.3", decimalSeparator: ".", groupingSeparator: ",") == "1.23")
        #expect(NumberText.sanitize("1,234.5", decimalSeparator: ".", groupingSeparator: ",") == "1234.5")
        #expect(NumberText.sanitize("abc 7 $", decimalSeparator: ".", groupingSeparator: ",") == "7")
    }

    @Test func writesTheLocalesOwnSeparator() {
        #expect(NumberText.sanitize("12.5", decimalSeparator: ",", groupingSeparator: ".") == "125")
        #expect(NumberText.sanitize("12,5", decimalSeparator: ",", groupingSeparator: ".") == "12,5")
    }

    @Test func dropsNumbersWithNoPlaceValue() {
        #expect(NumberText.sanitize("1½①2", decimalSeparator: ".", groupingSeparator: ",") == "12")
    }

    /// The bug this guards: an Arabic keyboard's digits used to be kept by
    /// `sanitize` and then read as nothing, so every row showed 0.
    @Test func readsArabicDigits() {
        let typed = NumberText.sanitize("١٢٫٥", decimalSeparator: "٫", groupingSeparator: "٬")
        #expect(typed == "١٢٫٥")
        #expect(NumberText.parse(typed, decimalSeparator: "٫", groupingSeparator: "٬") == Decimal(string: "12.5"))
    }

    @Test func readsArabicDigitsOnAnEnglishPhone() {
        let typed = NumberText.sanitize("١٢٫٥", decimalSeparator: ".", groupingSeparator: ",")
        #expect(NumberText.parse(typed, decimalSeparator: ".", groupingSeparator: ",") == Decimal(string: "12.5"))
    }

    @Test func readsEuropeanSeparators() {
        #expect(NumberText.parse("12,5", decimalSeparator: ",", groupingSeparator: ".") == Decimal(string: "12.5"))
    }

    @Test func emptyTextIsNoAmount() {
        #expect(NumberText.parse("", decimalSeparator: ".", groupingSeparator: ",") == nil)
    }

    // MARK: - Writing

    @Test func amountsKeepThreeDecimalPlaces() {
        #expect(NumberText.displayText(Decimal(string: "1234.5")!, locale: english) == "1,234.5")
        #expect(NumberText.displayText(Decimal(string: "0.8721")!, locale: english) == "0.872")
        #expect(NumberText.displayText(0, locale: english) == "0")
    }

    /// The other bug: 1 LBP in USD used to print as "0".
    @Test func tinyAmountsDoNotRoundAway() {
        let oneLBPInUSD = Decimal(1) / Decimal(89500)
        #expect(NumberText.displayText(oneLBPInUSD, locale: english) == "0.0000112")
        #expect(NumberText.editText(oneLBPInUSD, locale: english) == "0.0000112")
        #expect(NumberText.displayText(Decimal(string: "0.00614")!, locale: english) == "0.00614")
    }

    @Test func editTextHasNoGrouping() {
        #expect(NumberText.editText(Decimal(string: "1234567.5")!, locale: english) == "1234567.5")
    }

    @Test func smallRatesKeepThreeSignificantDigits() {
        #expect(NumberText.rateText(Decimal(string: "0.02049")!, locale: english) == "0.0205")
        #expect(NumberText.rateText(Decimal(string: "3.6725")!, locale: english) == "3.672")
    }

    @Test func whatIsPrintedCanBeReadBack() {
        let arabic = Locale(identifier: "ar_SA")
        let printed = NumberText.editText(Decimal(string: "1234.5")!, locale: arabic)
        let read = NumberText.parse(
            printed,
            decimalSeparator: arabic.decimalSeparator ?? ".",
            groupingSeparator: arabic.groupingSeparator ?? ","
        )
        #expect(read == Decimal(string: "1234.5"))
    }
}
