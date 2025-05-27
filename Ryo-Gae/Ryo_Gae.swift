//
//  Ryo_Gae.swift
//  Ryo-Gae
//
//  Created by Guilherme Pereira on 5/28/25.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    // MARK: - Properties
    private let apiService = CurrencyAPIService()
    
    private static var lastFetchedEntry: SimpleEntry?
    private static var lastSuccessfulAPITimestamp: Date?

    private let veryRecentFetchThreshold: TimeInterval = 5 * 60 // 5 minutes

    // MARK: - TimelineProvider Protocol Methods
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(),
                    baseCurrency: "USD",
                    brlRate: 5.10,
                    jpyRate: 157.50,
                    lastUpdate: Date(),
                    errorMessage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        if context.isPreview {
             completion(SimpleEntry(date: Date(),
                                   baseCurrency: "USD",
                                   brlRate: 5.10,
                                   jpyRate: 157.50,
                                   lastUpdate: Date(),
                                   errorMessage: nil))
            return
        }

        if let cachedData = Provider.lastFetchedEntry {
            let entryForSnapshot = SimpleEntry(
                date: Date(),
                baseCurrency: cachedData.baseCurrency,
                brlRate: cachedData.brlRate,
                jpyRate: cachedData.jpyRate,
                lastUpdate: cachedData.lastUpdate,
                errorMessage: cachedData.errorMessage
            )
            completion(entryForSnapshot)
            return
        }
        
        Task {
            do {
                let apiResponse = try await apiService.fetchExchangeRates()
                let apiDataTimestamp = CurrencyAPIService.parseOpenExchangeRatesTimestamp(apiResponse.timestamp)
                
                let entry = SimpleEntry(date: Date(),
                                       baseCurrency: apiResponse.base,
                                       brlRate: apiResponse.rates["BRL"],
                                       jpyRate: apiResponse.rates["JPY"],
                                       lastUpdate: apiDataTimestamp,
                                       errorMessage: nil)
                
                Provider.lastFetchedEntry = entry
                Provider.lastSuccessfulAPITimestamp = apiDataTimestamp
                completion(entry)
            } catch {
                print("Snapshot fetch error: \(error.localizedDescription)")
                completion(SimpleEntry(date: Date(), baseCurrency: "N/A", brlRate: nil, jpyRate: nil, lastUpdate: nil, errorMessage: "Failed to load"))
            }
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let currentDate = Date()
        
        // --- Cache Check Logic ---
        if let lastAPIDataTimestamp = Provider.lastSuccessfulAPITimestamp,
           let cachedTimelineEntryData = Provider.lastFetchedEntry,
           let lastFetchAttemptTime = Provider.lastFetchedEntry?.date {

            // Create a Calendar instance and set its time zone to UTC for comparison
            var utcCalendar = Calendar.current
            utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)! // Set calendar to UTC

            // Get hour components in UTC
            let lastAPITimestampHourUTC = utcCalendar.component(.hour, from: lastAPIDataTimestamp)
            let currentHourUTC = utcCalendar.component(.hour, from: currentDate)
            // Also check day to handle midnight crossover
            let lastAPITimestampDayUTC = utcCalendar.component(.day, from: lastAPIDataTimestamp)
            let currentDayUTC = utcCalendar.component(.day, from: currentDate)

            if lastAPITimestampHourUTC == currentHourUTC &&
               lastAPITimestampDayUTC == currentDayUTC && // Ensure it's the same day in UTC
               currentDate.timeIntervalSince(lastFetchAttemptTime) < veryRecentFetchThreshold {
                
                print("Using cached data from current UTC hour. API data timestamp: \(lastAPIDataTimestamp).")
                
                let timelineEntry = SimpleEntry(
                    date: currentDate,
                    baseCurrency: cachedTimelineEntryData.baseCurrency,
                    brlRate: cachedTimelineEntryData.brlRate,
                    jpyRate: cachedTimelineEntryData.jpyRate,
                    lastUpdate: cachedTimelineEntryData.lastUpdate,
                    errorMessage: cachedTimelineEntryData.errorMessage
                )

                let nextSmartRefreshTime = getNextSmartRefreshTime(from: currentDate, using: utcCalendar)
                let timeline = Timeline(entries: [timelineEntry], policy: .after(nextSmartRefreshTime))
                completion(timeline)
                return
            }
        }
        // --- End Cache Check Logic ---
        
        Task {
            do {
                print("Fetching new data for timeline. Current time: \(currentDate)")
                let apiResponse = try await apiService.fetchExchangeRates()
                let apiDataTimestamp = CurrencyAPIService.parseOpenExchangeRatesTimestamp(apiResponse.timestamp)
                
                let newTimelineEntry = SimpleEntry(
                    date: currentDate,
                    baseCurrency: apiResponse.base,
                    brlRate: apiResponse.rates["BRL"],
                    jpyRate: apiResponse.rates["JPY"],
                    lastUpdate: apiDataTimestamp,
                    errorMessage: nil
                )
                
                Provider.lastFetchedEntry = newTimelineEntry
                Provider.lastSuccessfulAPITimestamp = apiDataTimestamp
                
                var utcCalendar = Calendar.current
                utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
                let nextSmartRefreshTime = getNextSmartRefreshTime(from: currentDate, using: utcCalendar)
                print("New data fetched. API data timestamp: \(apiDataTimestamp). Next timeline update: \(nextSmartRefreshTime)")
                
                let timeline = Timeline(entries: [newTimelineEntry], policy: .after(nextSmartRefreshTime))
                completion(timeline)
                
            } catch {
                print("Timeline fetch error: \(error.localizedDescription)")
                let errorMessageText = generateErrorMessage(from: error)
                
                let errorEntry = SimpleEntry(
                    date: currentDate,
                    baseCurrency: "N/A",
                    brlRate: nil,
                    jpyRate: nil,
                    lastUpdate: Provider.lastSuccessfulAPITimestamp,
                    errorMessage: errorMessageText
                )
                
                let nextRetryDate = currentDate.addingTimeInterval(15 * 60)
                let timeline = Timeline(entries: [errorEntry], policy: .after(nextRetryDate))
                completion(timeline)
            }
        }
    }

    // MARK: - Helper Functions
    // Pass the UTC-configured calendar to this helper
    private func getNextSmartRefreshTime(from date: Date, using calendar: Calendar) -> Date {
        // 'calendar' is already configured for UTC by the caller
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
        
        components.minute = 0
        components.second = 0
        components.nanosecond = 0
        
        guard let currentHourTopUTC = calendar.date(from: components) else {
            return date.addingTimeInterval(3600)
        }

        var nextFetchTargetHourUTC = currentHourTopUTC
        if date >= currentHourTopUTC {
            nextFetchTargetHourUTC = calendar.date(byAdding: .hour, value: 1, to: currentHourTopUTC)!
        }
        
        return nextFetchTargetHourUTC.addingTimeInterval(2 * 60) // 2 minutes past the target UTC hour
    }

    private func generateErrorMessage(from error: Error) -> String {
        if let urlError = error as? URLError, urlError.code == .userAuthenticationRequired {
            return "App ID error. Check Info.plist and API Service."
        } else if let decodingError = error as? DecodingError {
            print("Decoding Error: \(decodingError)")
            return "Data parsing error. Please try again."
        } else {
            return "Failed to update rates. Check connection."
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
    let startColor = Color(red: 0.1, green: 0.2, blue: 0.4)
    let endColor = Color(red: 0.05, green: 0.1, blue: 0.3)
    
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
                    Text(entry.baseCurrency ?? "USD")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("💱")
                        .font(.title)
                }
                .padding(.bottom, 4)
                
                Divider().overlay(Color.gray)
                
                RateView(currencySymbol: "🇧🇷", currencyCode: "BRL", rate: entry.brlRate)
                RateView(currencySymbol: "🇯🇵", currencyCode: "JPY", rate: entry.jpyRate)
                
                Spacer() // Pushes content up
                
                if let lastUpdate = entry.lastUpdate {
                    Text("Updated: \(lastUpdate, style: .time)")
                        .font(.caption2)
                        .foregroundColor(Color.white.opacity(0.9))
                } else {
                    Text("Updating...")
                        .font(.caption2)
                        .foregroundColor(Color.white.opacity(0.9))
                }
            }
        }
        .foregroundColor(.white) // Default text color for the content
        .containerBackground(for: .widget) {
            LinearGradient(
                gradient: Gradient(colors: [startColor, endColor]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
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
        .supportedFamilies([.systemSmall, .systemMedium]) // Add more if you design for them
    }
}

// Previews - Update to reflect new SimpleEntry structure
// The ConfigurationAppIntent extensions for smiley and starEyes are in your AppIntent.swift,
// or you might need to move/recreate them here if they were in Ryo_Gae.swift originally
// and accessible to the preview.
// Assuming ConfigurationAppIntent.smiley and .starEyes are available:

#Preview(as: .systemMedium) {
    Ryo_Gae()
} timeline: {
    SimpleEntry(date: .now, baseCurrency: "USD", brlRate: 5.10, jpyRate: 157.50, lastUpdate: .now, errorMessage: nil)
    SimpleEntry(date: .now, baseCurrency: "N/A", brlRate: nil, jpyRate: nil, lastUpdate: nil, errorMessage: "Preview Error")
}
