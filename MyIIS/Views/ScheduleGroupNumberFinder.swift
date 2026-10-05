import SwiftUI

struct ScheduleGroupNumberFinder: View {
    @Bindable var viewModel: ScheduleServiceViewModel
    let onSelect: (StudyGroup) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model = ScheduleGroupNumberFinderModel()
    @State private var feedback = ScheduleNumberClickFeedback()
    @AppStorage("schedule.numberFinder.sound") private var soundEnabled = false
    @ScaledMetric(relativeTo: .largeTitle) private var digitSize = 64

    init(
        viewModel: ScheduleServiceViewModel,
        model: ScheduleGroupNumberFinderModel = ScheduleGroupNumberFinderModel(),
        onSelect: @escaping (StudyGroup) -> Void
    ) {
        self.viewModel = viewModel
        _model = State(initialValue: model)
        self.onSelect = onSelect
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                toolbar
                ScheduleObservedScrollView(threshold: .pastTop(45), onCrossThreshold: {
                    model.showResults()
                }, content: {
                    VStack(spacing: 24) {
                        digits(width: geometry.size.width - 40)
                            .padding(.top, 32)
                        explanation
                        digitPicker
                        resultHint
                        if model.areResultsVisible {
                            results
                                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 20)
                })

            }
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: model.areResultsVisible)
        .background(.black)
        .environment(\.colorScheme, .dark)
        .sensoryFeedback(.selection, trigger: model.digits)
        .sensoryFeedback(.selection, trigger: model.activePosition)
        .onChange(of: model.digits) { _, _ in playClick() }
        .onChange(of: model.activePosition) { _, _ in playClick() }
        .onChange(of: soundEnabled) { _, enabled in
            if enabled { feedback.prepare() } else { feedback.stop() }
        }
        .onChange(of: viewModel.groups) { _, groups in model.updateDirectory(groups) }
        .task {
            model.updateDirectory(viewModel.groups)
            if soundEnabled { feedback.prepare() }
        }
        .onDisappear { feedback.stop() }
        .accessibilityAction(.escape) { dismiss() }
    }

    private var toolbar: some View {
        HStack {
            Button {
                soundEnabled.toggle()
            } label: {
                Image(systemName: soundEnabled ? "speaker.wave.2" : "speaker.slash")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(ScheduleSearchCopy.text(soundEnabled ? "sound_off" : "sound_on"))
            Spacer()
            Button(ScheduleSearchCopy.text("reset")) {
                model.reset()
            }
            .disabled(!model.hasSelection)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").frame(width: 44, height: 44)
            }
            .accessibilityLabel(NSLocalizedString("common_close", comment: ""))
        }
        .font(.subheadline)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
    }

    private func digits(width: CGFloat) -> some View {
        HStack(spacing: 2) {
            ForEach(0 ..< 6, id: \.self) { position in
                let selected = model.digits[position] != nil
                Button {
                    model.activePosition = position
                } label: {
                    VStack(spacing: 12) {
                        Text(String(model.digits[position] ?? 0))
                            .font(.system(size: min(digitSize, width / 7), weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(selected ? .white : Color(white: 0.38))
                            .shadow(color: selected ? .white.opacity(0.5) : .clear, radius: 12)
                        Capsule()
                            .fill(model.activePosition == position ? .white : .clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(ScheduleSearchCopy.positionTitle(position))
                .accessibilityValue(model.digits[position].map(String.init) ?? ScheduleSearchCopy.text("any"))
                .accessibilityAddTraits(model.activePosition == position ? .isSelected : [])
                .accessibilityIdentifier("schedule.numberFinder.digit.\(position)")
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.digits)
    }

    private var explanation: some View {
        VStack(spacing: 8) {
            Text(ScheduleSearchCopy.positionTitle(model.activePosition))
                .font(.title3)
                .foregroundStyle(.white)
            Text(model.explanation)
                .font(.subheadline)
                .foregroundStyle(Color(white: 0.65))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var digitPicker: some View {
        Picker(ScheduleSearchCopy.positionTitle(model.activePosition), selection: Binding(
            get: { model.digits[model.activePosition] },
            set: { model.select($0) }
        )) {
            Text(ScheduleSearchCopy.text("any")).tag(Optional<Int>.none)
            if let selected = model.digits[model.activePosition], !model.options.contains(selected) {
                Text(String(selected)).tag(Optional(selected))
            }
            ForEach(model.options, id: \.self) { value in
                Text(model.optionTitle(value)).tag(Optional(value))
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 150)
        .id(model.activePosition)
        .accessibilityIdentifier("schedule.numberFinder.picker")
    }

    private var resultHint: some View {
        VStack(spacing: 8) {
            if viewModel.groups.isEmpty {
                ScheduleDirectoryStatus(viewModel: viewModel)
                    .accessibilityIdentifier("schedule.numberFinder.directoryStatus")
            } else {
                Text(String(format: ScheduleSearchCopy.text("count"), model.matches.count))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("schedule.numberFinder.count")
            }
            Text(ScheduleSearchCopy.text("directory_note"))
                .font(.caption)
                .foregroundStyle(Color(white: 0.65))
                .multilineTextAlignment(.center)
            if !viewModel.groups.isEmpty {
                Button { model.toggleResults() } label: {
                    Label(
                        ScheduleSearchCopy.text(model.areResultsVisible ? "hide_results" : "show_results"),
                        systemImage: model.areResultsVisible ? "chevron.up" : "chevron.down"
                    )
                        .font(.subheadline)
                        .frame(minHeight: 44)
                }
                .foregroundStyle(.white)
                .accessibilityIdentifier("schedule.numberFinder.toggleResults")
            }
        }
    }

    private var results: some View {
        VStack(spacing: 0) {
                if model.matches.isEmpty {
                    Text(ScheduleSearchCopy.text("no_matches"))
                        .foregroundStyle(.secondary)
                        .padding(24)
                }
                ForEach(model.matches, id: \.name) { group in
                    ScheduleGroupSearchRow(
                        group: group,
                        alias: viewModel.pinnedGroupAliases[group.name],
                        isAccountGroup: group.name == viewModel.accountGroupName,
                        onSelect: {
                            dismiss()
                            onSelect(group)
                        }
                    )
                    Divider().padding(.leading, 62)
                }
        }
        .background(Color(white: 0.08))
        .accessibilityIdentifier("schedule.numberFinder.results")
    }

    private func playClick() {
        if soundEnabled { feedback.play() }
    }
}
