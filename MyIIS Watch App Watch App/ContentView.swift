import SwiftUI

struct ContentView: View {
    @ObservedObject var receiver: WatchScheduleReceiver

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Group {
                    if let snapshot = receiver.snapshot {
                        scheduleFeed(snapshot, now: context.date)
                    } else {
                        emptyContent
                    }
                }
                .navigationTitle("watch_schedule_title")
            }
        }
    }

    // MARK: - Schedule Feed

    private func scheduleFeed(_ snapshot: WatchScheduleSnapshot, now: Date) -> some View {
        let active = snapshot.activeEvent(at: now)
        let daySections = snapshot.daySections(at: now)

        return List {
            // Active Hero Card if currently in class
            if let active {
                Section {
                    activeEventHeroCard(active, now: now)
                        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                }
            }

            if daySections.isEmpty && active == nil {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        Text("watch_widget_no_events")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }

            // Timeline Feed grouped by days
            ForEach(daySections) { section in
                let nonActiveEvents = section.events.filter { active?.id != $0.id }
                if !nonActiveEvents.isEmpty {
                    Section(header: Text(section.title).font(.footnote.weight(.semibold))) {
                        ForEach(nonActiveEvents) { event in
                            lessonRowCard(event, now: now)
                                .listRowInsets(EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2))
                        }
                    }
                }
            }

            // Footer metadata
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
        .listStyle(.carousel)
    }

    // MARK: - Active Hero Card (iPhone-styled with Accent Bar & Live Progress)

    // swiftlint:disable:next function_body_length
    private func activeEventHeroCard(_ event: WatchScheduleEvent, now: Date) -> some View {
        let interval = event.interval()

        return HStack(alignment: .top, spacing: 8) {
            // Vertical Accent Bar
            Capsule()
                .fill(event.accentColor)
                .frame(width: 4)
                .padding(.vertical, 2)

            // Content Body
            VStack(alignment: .leading, spacing: 4) {
                // Top status badges
                HStack(spacing: 4) {
                    Text("watch_schedule_now")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(event.accentColor.opacity(0.25)))
                        .foregroundStyle(event.accentColor)

                    if let type = event.lessonType, !type.isEmpty {
                        Text(type.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.quaternary))
                            .foregroundStyle(.secondary)
                    }

                    if let subgroup = event.subgroupBadge {
                        Text(subgroup)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.quaternary))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Trailing Teacher Avatar
                    teacherAvatarView(for: event, size: 28)
                }

                // Lesson Title
                Text(event.title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                // Time Range & Remaining Timer
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(event.accentColor)

                    Text("\(event.startTime) – \(event.endTime)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))

                    if let interval {
                        Spacer()
                        Text(interval.end, style: .timer)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                // Location & Teacher
                HStack(spacing: 4) {
                    if let location = event.shortLocation() {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    if let teacher = event.teacherName, !teacher.isEmpty {
                        Text("· \(teacher)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.trailing, 6)
        }
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.18))
        )
    }

    // MARK: - Lesson Row Card (Clean feed card with stripe & teacher photo)

    private func lessonRowCard(_ event: WatchScheduleEvent, now: Date) -> some View {
        HStack(alignment: .top, spacing: 7) {
            // Left Accent Bar (iPhone style)
            Capsule()
                .fill(event.accentColor)
                .frame(width: 3.5)
                .padding(.vertical, 4)

            // Details Column
            VStack(alignment: .leading, spacing: 3) {
                // Time Range & Badges
                HStack(alignment: .center, spacing: 4) {
                    Text("\(event.startTime) – \(event.endTime)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)

                    if let type = event.lessonType, !type.isEmpty {
                        Text(type.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(event.accentColor.opacity(0.2)))
                            .foregroundStyle(event.accentColor)
                    }

                    if let subgroup = event.subgroupBadge {
                        Text(subgroup)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Teacher avatar
                    teacherAvatarView(for: event, size: 22)
                }

                // Subject Title
                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                // Location and Teacher Name
                HStack(spacing: 4) {
                    if let location = event.shortLocation() {
                        Label(location, systemImage: "mappin")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let teacher = event.teacherName, !teacher.isEmpty {
                        Text("· \(teacher)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.trailing, 4)
        }
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.gray.opacity(0.12))
        )
    }

    // MARK: - Teacher Avatar View (Initials Badge for watchOS stability)

    @ViewBuilder
    private func teacherAvatarView(for event: WatchScheduleEvent, size: CGFloat) -> some View {
        avatarPlaceholder(for: event, size: size)
    }

    private func avatarPlaceholder(for event: WatchScheduleEvent, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(event.accentColor.opacity(0.2))
                .frame(width: size, height: size)

            if !event.teacherInitials.isEmpty {
                Text(event.teacherInitials)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(event.accentColor)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(event.accentColor)
            }
        }
    }

    // MARK: - Empty State

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
