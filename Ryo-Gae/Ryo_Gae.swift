//
//  Ryo_Gae.swift
//  Ryo-Gae
//
//  Created by Guilherme Pereira on 5/28/25.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    // Add the API service
    private let apiService = CurrencyAPIService()
    
    // Update placeholder to include example currency data
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(),
                    configuration: ConfigurationAppIntent(), // Keeps existing config
                    baseCurrency: "USD",
                    brlRate: 0.92,
                    jpyRate: 157.50,
                    lastUpdate: Date(),
                    errorMessage: nil)
    }
    
    // Update snapshot to fetch real data
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        // For previews, return placeholder data quickly
        if context.isPreview {
            return SimpleEntry(date: Date(),
                               configuration: configuration,
                               baseCurrency: "USD",
                               brlRate: 0.92,
                               jpyRate: 157.50,
                               lastUpdate: Date(),
                               errorMessage: nil)
        }
        
        // For actual snapshots, try to fetch live data
        do {
            let apiResponse = try await apiService.fetchExchangeRates()
            let lastUpdateDate = CurrencyAPIService.parseUTCDate(apiResponse.timeLastUpdateUTC)
            return SimpleEntry(date: Date(),
                               configuration: configuration,
                               baseCurrency: apiResponse.baseCode,
                               brlRate: apiResponse.conversionRates["BRL"],
                               jpyRate: apiResponse.conversionRates["JPY"],
                               lastUpdate: lastUpdateDate,
                               errorMessage: nil)
        } catch {
            print("Snapshot fetch error: \(error.localizedDescription)")
            return SimpleEntry(date: Date(),
                               configuration: configuration,
                               baseCurrency: "N/A",
                               brlRate: nil,
                               jpyRate: nil,
                               lastUpdate: nil,
                               errorMessage: "Failed to load snapshot")
        }
    }
    
    // Update timeline to fetch real data and schedule updates
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let currentDate = Date()
        do {
            let apiResponse = try await apiService.fetchExchangeRates()
            let lastUpdateDate = CurrencyAPIService.parseUTCDate(apiResponse.timeLastUpdateUTC)
            
            let entry = SimpleEntry(
                date: currentDate,
                configuration: configuration, // Pass along the existing configuration
                baseCurrency: apiResponse.baseCode,
                brlRate: apiResponse.conversionRates["BRL"],
                jpyRate: apiResponse.conversionRates["JPY"],
                lastUpdate: lastUpdateDate,
                errorMessage: nil
            )
            
            // Suggest next update (e.g., in 30 minutes).
            // ExchangeRate-API free tier updates daily, but widget can refresh UI.
            let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
            return Timeline(entries: [entry], policy: .after(nextUpdateDate))
            
        } catch {
            print("Timeline fetch error: \(error.localizedDescription)")
            let errorMessage: String
            if let urlError = error as? URLError, urlError.code == .userAuthenticationRequired {
                errorMessage = "API Key error. Check Ryo-Gae/CurrencyAPIService.swift"
            } else {
                errorMessage = "Failed to update rates. Check connection."
            }
            
            let errorEntry = SimpleEntry(
                date: currentDate,
                configuration: configuration,
                baseCurrency: "N/A",
                brlRate: nil,
                jpyRate: nil,
                lastUpdate: nil,
                errorMessage: errorMessage
            )
            
            // If fetching fails, try again in 5-15 minutes.
            let nextRetryDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            return Timeline(entries: [errorEntry], policy: .after(nextRetryDate))
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent

    // New fields for currency data
    let baseCurrency: String?
    let brlRate: Double?
    let jpyRate: Double?
    let lastUpdate: Date?
    let errorMessage: String?
}

struct Ryo_GaeEntryView : View {
    var entry: Provider.Entry

    var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                if let errorMessage = entry.errorMessage {
                    Text("⚠️ Error")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2) // Allow up to 2 lines for the error message
                } else {
                    HStack {
                        Text(entry.baseCurrency ?? "USD") // Default to USD if baseCurrency is nil
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        // You can still display the emoji from your AppIntent if you wish
                        Text(entry.configuration.favoriteEmoji)
                            .font(.title)
                    }
                    .padding(.bottom, 4)

                    Divider()

                    RateView(currencySymbol: "🇧🇷", currencyCode: "BRL", rate: entry.brlRate)
                    RateView(currencySymbol: "🇯🇵", currencyCode: "JPY", rate: entry.jpyRate)
                    
                    Spacer() // Pushes content up

                    if let lastUpdate = entry.lastUpdate {
                        Text("Updated: \(lastUpdate, style: .time)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Updating...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            //.containerBackground(.fill.tertiary, for: .widget) // Keep existing background
        }
}

// Helper view for displaying each rate
struct RateView: View {
    let currencySymbol: String
    let currencyCode: String
    let rate: Double?

    var body: some View {
        HStack {
            Text("\(currencySymbol) \(currencyCode):")
                .font(.callout)
            Spacer()
            Text(rate != nil ? String(format: "%.2f", rate!) : "N/A")
                .font(.callout.bold())
        }
    }
}

struct Ryo_Gae: Widget {
    let kind: String = "Ryo_Gae"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            Ryo_GaeEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Ryo-Gae") // You can update this
        .description("View live currency exchange rates.") // Update description
        .supportedFamilies([.systemSmall]) // Add more if you design for them
    }
}

// Previews - Update to reflect new SimpleEntry structure
// The ConfigurationAppIntent extensions for smiley and starEyes are in your AppIntent.swift,
// or you might need to move/recreate them here if they were in Ryo_Gae.swift originally
// and accessible to the preview.
// Assuming ConfigurationAppIntent.smiley and .starEyes are available:

extension ConfigurationAppIntent {
    // These might already be in your AppIntent.swift file
    // If not, and you want to use them for previews, define them here or ensure visibility.
    // For this example, I'm assuming they are accessible.
    // If they are fileprivate in AppIntent.swift, you might not be able to access them directly here
    // unless this preview code is also in AppIntent.swift or they are made internal/public.
    
    // For simplicity in preview, let's create them if not accessible
    // This is just for the #Preview macro to work.
    static var previewDefault: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "💱" // Default for preview
        return intent
    }
}

#Preview(as: .systemSmall) {
    Ryo_Gae()
} timeline: {
    SimpleEntry(date: .now, configuration: .previewDefault, baseCurrency: "USD", brlRate: 5.10, jpyRate: 157.50, lastUpdate: .now, errorMessage: nil)
    SimpleEntry(date: .now, configuration: .previewDefault, baseCurrency: "N/A", brlRate: nil, jpyRate: nil, lastUpdate: nil, errorMessage: "Preview Error")
}
