import SwiftUI

struct ScheduleDirectoryStatus: View {
    @Bindable var viewModel: ScheduleServiceViewModel

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.isDirectoryLoading {
                ProgressView(ScheduleSearchCopy.text("loading_directory"))
            } else {
                Text(viewModel.errorMessage ?? ScheduleSearchCopy.text("no_directory"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(ScheduleSearchCopy.text("retry")) {
                    Task { await viewModel.loadDirectoryIfNeeded(force: true) }
                }
                .frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}
