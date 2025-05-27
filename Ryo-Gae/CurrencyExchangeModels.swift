//
//  CurrencyExchangeModels.swift
//  JapanTools
//
//  Created by Guilherme Pereira on 5/28/25.
//

import Foundation

// To decode the API response from openexchangerates.org
struct OpenExchangeRatesResponse: Decodable {
    let disclaimer: String?
    let license: String?
    let timestamp: TimeInterval // Unix timestamp (Int, but TimeInterval is good for Date conversion)
    let base: String
    let rates: [String: Double]
}
