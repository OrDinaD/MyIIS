import SwiftUI

struct PinnedSchedulePicker: View {
    @Bindable var viewModel: ScheduleServiceViewModel
    let onSelect: () -> Void
    @State private var renamingGroup: String?
    @State private var alias = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let group = viewModel.accountGroupName, !group.isEmpty {
                    Button {
                        onSelect()
                        Task { await viewModel.openGroupSchedule(group) }
                    } label: {
                        Label(group, systemImage: "person.crop.circle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                    }
                }
                if !viewModel.pinnedGroupNames.isEmpty {
                    Text("schedule_pinned_groups")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ForEach(viewModel.pinnedGroupNames, id: \.self) { group in
                        Button {
                            onSelect()
                            Task { await viewModel.openGroupSchedule(group) }
                        } label: {
                            Label(viewModel.pinnedGroupMenuTitle(for: group), systemImage: "pin.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("pinnedGroup_\(group)")
                        .contextMenu { RenameButton() }
                        .renameAction {
                            alias = viewModel.pinnedGroupAlias(for: group) ?? ""
                            renamingGroup = group
                        }
                    }
                }
                if !viewModel.pinnedTeachers.isEmpty {
                    Text("schedule_pinned_teachers")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ForEach(viewModel.pinnedTeachers) { teacher in
                        Button {
                            onSelect()
                            Task { await viewModel.openPinnedTeacher(teacher) }
                        } label: {
                            Label(teacher.name, systemImage: "person.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(20)
        }
        .frame(idealWidth: 320, maxHeight: 420)
        .alert("schedule_group_alias_title", isPresented: Binding(
            get: { renamingGroup != nil },
            set: { if !$0 { renamingGroup = nil } }
        )) {
            TextField("schedule_group_alias_placeholder", text: $alias)
            Button("common_cancel", role: .cancel) { renamingGroup = nil }
            Button("common_save") {
                guard let group = renamingGroup else { return }
                viewModel.setPinnedGroupAlias(alias, for: group)
                renamingGroup = nil
            }
            if let group = renamingGroup, viewModel.pinnedGroupAlias(for: group) != nil {
                Button("schedule_group_alias_remove", role: .destructive) {
                    viewModel.setPinnedGroupAlias(nil, for: group)
                    renamingGroup = nil
                }
            }
        } message: {
            Text(renamingGroup ?? "")
        }
    }
}
