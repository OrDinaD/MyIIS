import SwiftUI

struct LocalScheduleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: LocalScheduleViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                LocalScheduleView(viewModel: viewModel)
                    .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(NSLocalizedString("local_schedule_edit_event", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("common_close", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
