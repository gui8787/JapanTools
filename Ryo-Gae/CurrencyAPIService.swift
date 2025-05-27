//
//  CurrencyAPIService.swift
//  JapanTools
//
//  Created by Guilherme Pereira on 5/28/25.
//


import Foundation

class CurrencyAPIService {
    // Use a new key for Open Exchange Rates App ID from your Info.plist
    private let appID = Bundle.main.infoDictionary?["EXCHANGE_RATE_APP_ID"] as? String ?? "EXCHANGE_RATE_APP_ID"
    private let baseURL = "https://openexchangerates.org/api/latest.json"

    // Update the function to return the new response type
    func fetchExchangeRates() async throws -> OpenExchangeRatesResponse { // Base currency is fixed to USD on free plan
        guard appID != "YOUR_OPEN_EXCHANGE_RATES_APP_ID" && !appID.isEmpty else {
            throw URLError(.userAuthenticationRequired, userInfo: [NSLocalizedDescriptionKey: "Open Exchange Rates App ID not set. Please add it to your widget's Info.plist (key: OPEN_EXCHANGE_RATES_APP_ID) and update CurrencyAPIService.swift."])
        }

        // Construct URL for openexchangerates.org
        // Free plan is USD base only. If you have a paid plan, you could add '&base=YOUR_BASE_CURRENCY'
        let urlString = "\(baseURL)?app_id=\(appID)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL for Open Exchange Rates."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                // Attempt to decode error message if API provides structured errors
                // For now, generic error
                throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch data from Open Exchange Rates. Status: \(statusCode)"])
            }

            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(OpenExchangeRatesResponse.self, from: data)
            
            // OpenExchangeRates.org doesn't have a 'result: success' field in the same way.
            // Successful decoding and a 200 status code are primary indicators.
            // Some APIs might include an error object in the JSON for non-200 but parsable errors.
            // e.g., if apiResponse has an optional error field:
            // if let apiError = apiResponse.error { throw URLError(...) }

            return apiResponse
        } catch {
            print("Network request to Open Exchange Rates failed: \(error.localizedDescription)")
            // If decoding failed, error will be a DecodingError
            // If URLSession failed, it could be URLError, etc.
            throw error
        }
    }
    
    // New function to parse Unix timestamp
    static func parseOpenExchangeRatesTimestamp(_ timestamp: TimeInterval) -> Date {
        return Date(timeIntervalSince1970: timestamp)
    }

    // You can remove or comment out the old parseUTCDate if it's no longer needed
    /*
    static func parseUTCDate(_ dateString: String) -> Date? {
        // ... old implementation ...
    }
    */
}
