import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), lastMeetingDate: Date(), lastMeetingTitle: "Team Sync")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), lastMeetingDate: Date(), lastMeetingTitle: "Team Sync")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // In a real app, we'd fetch from shared UserDefaults or App Group
        let entry = SimpleEntry(date: Date(), lastMeetingDate: Date(), lastMeetingTitle: "Recent Meeting")
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let lastMeetingDate: Date
    let lastMeetingTitle: String
}

struct DonsNotesWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.blue)
                Text("Don's Notes")
                    .font(.caption)
                    .bold()
            }
            
            Spacer()
            
            Text("Last Meeting")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Text(entry.lastMeetingTitle)
                .font(.subheadline)
                .bold()
                .lineLimit(1)
            
            Text(entry.lastMeetingDate, style: .date)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Quick Record Button (Deep Link)
            Link(destination: URL(string: "donsnotes://record")!) {
                HStack {
                    Image(systemName: "record.circle")
                    Text("Record")
                }
                .font(.caption)
                .bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
    }
}

struct DonsNotesWidget: Widget {
    let kind: String = "DonsNotesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DonsNotesWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Record")
        .description("See your last meeting and start a new recording.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
