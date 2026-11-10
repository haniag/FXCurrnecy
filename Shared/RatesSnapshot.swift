//
//  RatesSnapshot.swift
//  FX
//

import Foundation

/// A set of rates and the moment the service struck them.
///
/// The time travels with the rates rather than being noted when the reply
/// lands: a feed can hand back figures quoted hours earlier, and "updated just
/// now" over yesterday's numbers would be a lie.
nonisolated struct RatesSnapshot: Sendable, Codable {
    /// Units of each currency per 1 USD.
    let rates: [String: Decimal]
    /// When the service quoted them — not when we asked.
    let quotedAt: Date
}
