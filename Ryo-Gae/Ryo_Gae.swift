//
//  Ryo_Gae.swift
//  Ryo-Gae
//
//  Created by Guilherme Pereira on 5/28/25.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    // Add the API service
    private let apiService = CurrencyAPIService()
    
    // Update placeholder to include example currency data
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(),
                    baseCurrency: "USD",
                    brlRate: 0.92,
                    jpyRate: 157.50,
                    lastUpdate: Date(),
                    errorMessage: nil)
    }
    
    // Provides a sample entry for transient situations (e.g., quick look).
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        // For previews, return placeholder data quickly
        if context.isPreview {
            completion(SimpleEntry(date: Date(),
                                   baseCurrency: "USD",
                                   brlRate: 0.92,
                                   jpyRate: 157.50,
                                   lastUpdate: Date(),
                                   errorMessage: nil))
            return
        }
        
        // For actual snapshots, try to fetch live data
        Task {
            do {
                let apiResponse = try await apiService.fetchExchangeRates()
                let lastUpdateDate = CurrencyAPIService.parseOpenExchangeRatesTimestamp(apiResponse.timestamp)
                let entry = SimpleEntry(date: Date(),
                                        baseCurrency: apiResponse.base,
                                        brlRate: apiResponse.rates["BRL"],
                                        jpyRate: apiResponse.rates["JPY"],
                                        lastUpdate: lastUpdateDate,
                                        errorMessage: nil)
                completion(entry)
            } catch {
                print("Snapshot fetch error: \(error.localizedDescription)")
                let entry = SimpleEntry(date: Date(),
                                        baseCurrency: "N/A",
                                        brlRate: nil,
                                        jpyRate: nil,
                                        lastUpdate: nil,
                                        errorMessage: "Failed to load snapshot")
                completion(entry)
            }
        }
    }
    
    // Provides the timeline (current and future entries) for the widget.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        Task {
            let currentDate = Date()
            do {
                let apiResponse = try await apiService.fetchExchangeRates()
                let lastUpdateDate = CurrencyAPIService.parseOpenExchangeRatesTimestamp(apiResponse.timestamp)
                
                let entry = SimpleEntry(
                    date: currentDate,
                    baseCurrency: apiResponse.base,
                    brlRate: apiResponse.rates["BRL"],
                    jpyRate: apiResponse.rates["JPY"],
                    lastUpdate: lastUpdateDate,
                    errorMessage: nil
                )
                
                let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
                completion(timeline)
                
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
                    baseCurrency: "N/A",
                    brlRate: nil,
                    jpyRate: nil,
                    lastUpdate: nil,
                    errorMessage: errorMessage
                )
                
                let nextRetryDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
                let timeline = Timeline(entries: [errorEntry], policy: .after(nextRetryDate))
                completion(timeline)
            }
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date

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
                        Text("💱")
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
            .containerBackground(.fill.tertiary, for: .widget) // Keep existing background
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
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            Ryo_GaeEntryView(entry: entry)
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

#Preview(as: .systemSmall) {
    Ryo_Gae()
} timeline: {
    SimpleEntry(date: .now, baseCurrency: "USD", brlRate: 5.10, jpyRate: 157.50, lastUpdate: .now, errorMessage: nil)
    SimpleEntry(date: .now, baseCurrency: "N/A", brlRate: nil, jpyRate: nil, lastUpdate: nil, errorMessage: "Preview Error")
}
