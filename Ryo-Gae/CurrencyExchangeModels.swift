//
//  CurrencyExchangeModels.swift
//  JapanTools
//
//  Created by Guilherme Pereira on 5/28/25.
//

import Foundation

// To decode the API response from ExchangeRate-API
struct APIResponse: Decodable {
    let result: String
    let baseCode: String // "base_code" in JSON
    let conversionRates: [String: Double] // "conversion_rates" in JSON
    let timeLastUpdateUTC: String // "time_last_update_utc" in JSON

    enum CodingKeys: String, CodingKey {
        case result
        case baseCode = "base_code"
        case conversionRates = "conversion_rates"
        case timeLastUpdateUTC = "time_last_update_utc"
    }
}
