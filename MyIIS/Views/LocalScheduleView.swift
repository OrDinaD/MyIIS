import SwiftUI
import UniformTypeIdentifiers

struct LocalScheduleView: View {
    @StateObject private var viewModel = LocalScheduleViewModel()
    @State private var isImporterPresented = false
    @State private var editingEvent: LocalScheduleDocument.Event?
    @State private var isMetadataEditorPresented = false
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        ServiceEndpointSection(
            title: viewModel.document?.title ?? NSLocalizedString("local_schedule_title", comment: ""),
            subtitle: NSLocalizedString("local_schedule_subtitle", comment: ""),
            icon: "calendar.badge.plus"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if let document = viewModel.document {
                    documentContent(document)
                } else {
                    emptyContent
                }
            }
            .padding(.vertical, 4)
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.importFile(at: url)
                }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .sheet(item: $editingEvent) { event in
            LocalScheduleEventEditorView(event: event) { updatedEvent in
                viewModel.upsert(updatedEvent)
            }
        }
        .sheet(isPresented: $isMetadataEditorPresented) {
            if let document = viewModel.document {
                LocalScheduleMetadataEditorView(document: document) { title, timeZone in
                    viewModel.updateMetadata(title: title, timeZone: timeZone)
                }
            }
        }
        .confirmationDialog(
            NSLocalizedString("local_schedule_delete_confirmation", comment: ""),
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("common_delete", comment: ""), role: .destructive) {
                viewModel.deleteDocument()
            }
            Button(NSLocalizedString("common_cancel", comment: ""), role: .cancel) {}
        }
        .alert(
            NSLocalizedString("common_error", comment: ""),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(NSLocalizedString("common_ok", comment: "")) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert(
            NSLocalizedString("local_schedule_ready", comment: ""),
            isPresented: Binding(
                get: { viewModel.noticeMessage != nil },
                set: { if !$0 { viewModel.noticeMessage = nil } }
            )
        ) {
            Button(NSLocalizedString("common_ok", comment: "")) {
                viewModel.noticeMessage = nil
            }
        } message: {
            Text(viewModel.noticeMessage ?? "")
        }
    }

    private var emptyContent: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("local_schedule_empty_description", comment: ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                isImporterPresented = true
            } label: {
                Label(
                    NSLocalizedString("local_schedule_import", comment: ""),
                    systemImage: "square.and.arrow.down"
                )
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)

            HStack {
                Button(NSLocalizedString("local_schedule_create_empty", comment: "")) {
                    viewModel.createEmpty()
                }
                .buttonStyle(.bordered)

                Button(NSLocalizedString("local_schedule_create_example", comment: "")) {
                    viewModel.createExample()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func documentContent(_ document: LocalScheduleDocument) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(document.title)
                    .font(.headline)
                Text(document.timeZone)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                Button {
                    isImporterPresented = true
                } label: {
                    Label(NSLocalizedString("local_schedule_replace", comment: ""), systemImage: "arrow.triangle.2.circlepath")
                }

                Button {
                    isMetadataEditorPresented = true
                } label: {
                    Label(NSLocalizedString("local_schedule_edit_settings", comment: ""), systemImage: "slider.horizontal.3")
                }

                if let url = viewModel.currentFileURL {
                    ShareLink(item: url) {
                        Label(NSLocalizedString("local_schedule_export", comment: ""), systemImage: "square.and.arrow.up")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    isDeleteConfirmationPresented = true
                } label: {
                    Label(NSLocalizedString("local_schedule_delete", comment: ""), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
        }

        if document.events.isEmpty {
            Text(NSLocalizedString("local_schedule_no_events", comment: ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
        } else {
            ForEach(viewModel.groupedEvents, id: \.date) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.dayTitle(group.date))
                        .font(.headline)

                    ForEach(group.events) { event in
                        LocalScheduleEventRow(event: event) {
                            editingEvent = event
                        } onDelete: {
                            viewModel.delete(event)
                        }
                    }
                }
            }
        }

        Button {
            editingEvent = viewModel.makeNewEvent()
        } label: {
            Label(NSLocalizedString("local_schedule_add_event", comment: ""), systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
    }
}

private struct LocalScheduleEventRow: View {
    let event: LocalScheduleDocument.Event
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 2) {
                    Text(event.startTime)
                    Text(event.endTime)
                        .foregroundStyle(.secondary)
                }
                .font(.caption.monospacedDigit())

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(event.isCancelled)

                    Text([event.type.localizedTitle, event.location?.nilIfBlank].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(NSLocalizedString("common_delete", comment: ""), role: .destructive, action: onDelete)
        }
    }
}

private struct LocalScheduleMetadataEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var timeZone: String
    let onSave: (String, String) -> Void

    init(document: LocalScheduleDocument, onSave: @escaping (String, String) -> Void) {
        _title = State(initialValue: document.title)
        _timeZone = State(initialValue: document.timeZone)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(NSLocalizedString("local_schedule_name", comment: ""), text: $title)
                TextField(NSLocalizedString("local_schedule_time_zone", comment: ""), text: $timeZone)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .navigationTitle(NSLocalizedString("local_schedule_settings", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common_cancel", comment: "")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("common_save", comment: "")) {
                        onSave(title, timeZone)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct LocalScheduleEventEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var event: LocalScheduleDocument.Event
    let onSave: (LocalScheduleDocument.Event) -> Void

    init(
        event: LocalScheduleDocument.Event,
        onSave: @escaping (LocalScheduleDocument.Event) -> Void
    ) {
        _event = State(initialValue: event)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("local_schedule_event_main", comment: "")) {
                    TextField(NSLocalizedString("local_schedule_event_title", comment: ""), text: $event.title)
                    TextField(
                        NSLocalizedString("local_schedule_event_short_title", comment: ""),
                        text: optionalBinding(\.shortTitle)
                    )
                    Picker(NSLocalizedString("local_schedule_event_type", comment: ""), selection: $event.type) {
                        ForEach(LocalScheduleEventType.allCases) { type in
                            Text(type.localizedTitle).tag(type)
                        }
                    }
                    Toggle(NSLocalizedString("local_schedule_event_cancelled", comment: ""), isOn: $event.isCancelled)
                }

                Section(NSLocalizedString("local_schedule_event_time", comment: "")) {
                    DatePicker(
                        NSLocalizedString("local_schedule_event_date", comment: ""),
                        selection: dateBinding,
                        displayedComponents: .date
                    )
                    DatePicker(
                        NSLocalizedString("local_schedule_event_start", comment: ""),
                        selection: timeBinding(\.startTime),
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        NSLocalizedString("local_schedule_event_end", comment: ""),
                        selection: timeBinding(\.endTime),
                        displayedComponents: .hourAndMinute
                    )
                }

                Section(NSLocalizedString("local_schedule_event_details", comment: "")) {
                    TextField(
                        NSLocalizedString("local_schedule_event_location", comment: ""),
                        text: optionalBinding(\.location)
                    )
                    TextField(
                        NSLocalizedString("local_schedule_event_teacher", comment: ""),
                        text: optionalBinding(\.teacher)
                    )
                    TextField(
                        NSLocalizedString("local_schedule_event_note", comment: ""),
                        text: optionalBinding(\.note),
                        axis: .vertical
                    )
                    .lineLimit(2 ... 5)
                }
            }
            .navigationTitle(NSLocalizedString("local_schedule_edit_event", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common_cancel", comment: "")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("common_save", comment: "")) {
                        onSave(event)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        LocalScheduleFormatting.timeComponents(from: event.startTime) != nil &&
        LocalScheduleFormatting.timeComponents(from: event.endTime) != nil
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: {
                LocalScheduleFormatting.dayFormatter.date(from: event.date) ?? .now
            },
            set: {
                event.date = LocalScheduleFormatting.dayFormatter.string(from: $0)
            }
        )
    }

    private func timeBinding(_ keyPath: WritableKeyPath<LocalScheduleDocument.Event, String>) -> Binding<Date> {
        Binding(
            get: {
                let components = LocalScheduleFormatting.timeComponents(from: event[keyPath: keyPath])
                return Calendar.current.date(
                    bySettingHour: components?.hour ?? 9,
                    minute: components?.minute ?? 0,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: {
                event[keyPath: keyPath] = $0.formatted(
                    .dateTime
                        .hour(.twoDigits(amPM: .omitted))
                        .minute(.twoDigits)
                        .locale(Locale(identifier: "en_US_POSIX"))
                )
            }
        )
    }

    private func optionalBinding(
        _ keyPath: WritableKeyPath<LocalScheduleDocument.Event, String?>
    ) -> Binding<String> {
        Binding(
            get: { event[keyPath: keyPath] ?? "" },
            set: { event[keyPath: keyPath] = $0.nilIfBlank }
        )
    }
}
