//
//  CurrencyAPIService.swift
//  JapanTools
//
//  Created by Guilherme Pereira on 5/28/25.
//


// Ryo-Gae/CurrencyAPIService.swift

import Foundation

class CurrencyAPIService {
    private let apiKey = Bundle.main.infoDictionary?["EXCHANGE_RATE_API"] as? String ?? "EXCHANGE_RATE_API"
    private let baseURL = "https://v6.exchangerate-api.com/v6/"

    func fetchExchangeRates(baseCurrency: String = "USD") async throws -> APIResponse {
        guard apiKey != "EXCHANGE_RATE_API" && !apiKey.isEmpty else {
            throw URLError(.userAuthenticationRequired, userInfo: [NSLocalizedDescriptionKey: "API Key not set. Please add it to CurrencyAPIService.swift."])
        }

        let urlString = "\(baseURL)\(apiKey)/latest/\(baseCurrency)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                // You could try to decode error response from API if it provides one
                // For now, just a generic error
                throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch data. Status: \(statusCode)"])
            }

            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(APIResponse.self, from: data)
            
            guard apiResponse.result == "success" else {
                 // API itself reported an issue (e.g. invalid key, unknown base_code)
                throw URLError(.cannotParseResponse, userInfo: [NSLocalizedDescriptionKey: "API request not successful. Result: \(apiResponse.result)"])
            }
            return apiResponse
        } catch {
            print("Network request failed: \(error.localizedDescription)")
            throw error 
        }
    }
    
    static func parseUTCDate(_ dateString: String) -> Date? {
        let rfc1123Formatter = DateFormatter()
        rfc1123Formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z" // e.g., "Tue, 27 May 2025 00:00:01 +0000"
        rfc1123Formatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = rfc1123Formatter.date(from: dateString) {
            return date
        }
        // Fallback for standard ISO8601 if the above fails
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTimeZone]
        return isoFormatter.date(from: dateString)
    }
}
