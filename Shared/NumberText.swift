//
//  NumberText.swift
//  FX
//

import Foundation

/// Turning typed text into amounts, and amounts back into text.
///
/// Shared by the app and its widget so both print a number the same way.
/// Every function takes its locale or separators as a parameter, defaulting to
/// the user's, so the tests can check other locales without changing the
/// simulator's.
nonisolated enum NumberText {

    private static var localDecimalSeparator: String { Locale.current.decimalSeparator ?? "." }
    private static var localGroupingSeparator: String { Locale.current.groupingSeparator ?? "," }

    /// What the Arabic keyboard types for a decimal point and for thousands.
    private static let arabicDecimalSeparator: Character = "٫"
    private static let arabicGroupingSeparator: Character = "٬"

    // MARK: - Reading

    /// Keep digits and at most one decimal separator.
    ///
    /// Digits stay as they were typed, so a field filled in from an Arabic
    /// keyboard shows "١٢٫٥" rather than changing under the user's thumb;
    /// `parse` is what reads them. Anything that merely counts as a number to
    /// Unicode, like "½" or "①", is dropped: it has no place value.
    static func sanitize(_ text: String,
                         decimalSeparator: String = localDecimalSeparator,
                         groupingSeparator: String = localGroupingSeparator) -> String {
        var result = ""
        var hasSeparator = false
        for character in text.replacingOccurrences(of: groupingSeparator, with: "") {
            if digitValue(of: character) != nil {
                result.append(character)
            } else if character == "." || character == "," || character == arabicDecimalSeparator,
                      !hasSeparator {
                hasSeparator = true
                result.append(decimalSeparator)
            }
        }
        return result
    }

    /// The amount behind a piece of sanitized text, or nil if there isn't one.
    ///
    /// Digits from any script are read by value: `Decimal(string:)` only
    /// understands 0–9, and would make "١٢" nil — which the app then shows as
    /// a zero in every row.
    static func parse(_ text: String,
                      decimalSeparator: String = localDecimalSeparator,
                      groupingSeparator: String = localGroupingSeparator) -> Decimal? {
        var normalized = ""
        for character in text.replacingOccurrences(of: groupingSeparator, with: "") {
            if let digit = digitValue(of: character) {
                normalized.append(String(digit))
            } else if String(character) == decimalSeparator || character == arabicDecimalSeparator {
                normalized.append(".")
            } else if character == arabicGroupingSeparator {
                continue
            } else {
                normalized.append(character)
            }
        }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// 0–9 for a decimal digit in any script ("7", "٧", "७"), nil otherwise.
    private static func digitValue(of character: Character) -> Int? {
        guard character.unicodeScalars.count == 1,
              character.unicodeScalars.first?.properties.numericType == .decimal
        else { return nil }
        return character.wholeNumberValue
    }

    // MARK: - Writing

    /// For rows the user isn't editing: grouped, e.g. "1,234.5".
    static func displayText(_ amount: Decimal, locale: Locale = .current) -> String {
        format(amount, grouped: true, smallBelow: smallAmountThreshold, locale: locale)
    }

    /// For the row the user is editing: no grouping, so it stays re-parseable.
    static func editText(_ amount: Decimal, locale: Locale = .current) -> String {
        format(amount, grouped: false, smallBelow: smallAmountThreshold, locale: locale)
    }

    /// For rates rather than amounts. Up to 3 decimal places like everything
    /// else, except below 1, where 3 significant digits stop a small rate from
    /// rounding away: 1 TRY shows as 0.0205 USD rather than 0.02, and 1 LBP
    /// as 0.0000112 rather than 0.
    static func rateText(_ rate: Decimal, locale: Locale = .current) -> String {
        format(rate, grouped: true, smallBelow: 1, locale: locale)
    }

    /// Amounts keep 3 decimal places down to here. Below it those 3 places
    /// hold one digit at best and nothing at worst — 1 LBP is 0.0000112 USD,
    /// which would print as "0" — so the amount switches to 3 significant
    /// digits instead.
    private static let smallAmountThreshold: Decimal = 0.01

    private static func format(_ value: Decimal,
                               grouped: Bool,
                               smallBelow threshold: Decimal,
                               locale: Locale) -> String {
        let isSmall = value != 0 && abs(value) < threshold
        return value.formatted(
            .number
                .precision(isSmall ? .significantDigits(1...3) : .fractionLength(0...3))
                .grouping(grouped ? .automatic : .never)
                .locale(locale)
        )
    }
}
