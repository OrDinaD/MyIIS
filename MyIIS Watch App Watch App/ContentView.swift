import SwiftUI

struct ContentView: View {
    @ObservedObject var receiver: WatchScheduleReceiver

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            NavigationStack {
                Group {
                    if let snapshot = receiver.snapshot {
                        scheduleList(snapshot, now: context.date)
                    } else {
                        emptyContent
                    }
                }
                .navigationTitle("watch_schedule_title")
            }
        }
    }

    private func scheduleList(_ snapshot: WatchScheduleSnapshot, now: Date) -> some View {
        let events = snapshot.upcomingEvents(at: now)
        return List {
            if let event = events.first {
                Section {
                    currentEventCard(event, now: now)
                }
            }

            if events.count > 1 {
                Section("watch_schedule_next") {
                    ForEach(events.dropFirst().prefix(8)) { event in
                        eventRow(event)
                    }
                }
            }

            Section {
                LabeledContent("watch_schedule_source", value: snapshot.groupName)
                LabeledContent(
                    "watch_schedule_updated",
                    value: snapshot.updatedAt.formatted(date: .abbreviated, time: .shortened)
                )
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func currentEventCard(_ event: WatchScheduleSnapshot.Event, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                event.isCurrent(at: now) ? "watch_schedule_now" : "watch_schedule_upcoming",
                systemImage: event.isCurrent(at: now) ? "clock.fill" : "calendar"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tint)

            Text(event.title)
                .font(.headline)
                .lineLimit(2)
                .privacySensitive()

            if let interval = event.interval() {
                HStack {
                    Text(event.isCurrent(at: now) ? "watch_schedule_ends_in" : "watch_schedule_starts_in")
                    Text(event.isCurrent(at: now) ? interval.end : interval.start, style: .timer)
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let location = event.location, !location.isEmpty {
                Label(location, systemImage: "mappin")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .privacySensitive()
            }
        }
        .padding(.vertical, 4)
    }

    private func eventRow(_ event: WatchScheduleSnapshot.Event) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(event.startTime)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .privacySensitive()
            }

            if let location = event.location, !location.isEmpty {
                Text(location)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .privacySensitive()
            }
        }
    }

    private var emptyContent: some View {
        VStack(spacing: 10) {
            Image(systemName: "applewatch.and.arrow.forward")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text("watch_schedule_no_data")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(receiver.connectionError ?? String(localized: "watch_schedule_open_iphone"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    ContentView(receiver: WatchScheduleReceiver())
}
