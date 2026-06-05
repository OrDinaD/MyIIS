import QuickLook
import SwiftUI

struct DormitoryPreviewFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let title: String
}

struct DormitoryFilePreviewSheet: View {
    let file: DormitoryPreviewFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            QuickLookPreview(url: file.url)
                .navigationTitle(file.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(NSLocalizedString("common_close", comment: "")) {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(
                            item: file.url,
                            preview: SharePreview(file.title)
                        ) {
                            Label("Сохранить", systemImage: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        context.coordinator.url = url
        uiViewController.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

struct DormitoryStatusTag: View {
    let status: String

    private var tint: Color {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized.contains("засел") {
            return .green
        }

        if normalized.contains("высел") {
            return .orange
        }

        if normalized.contains("отказ") || normalized.contains("отклон") {
            return .red
        }

        return .blue
    }

    var body: some View {
        Text(status)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
    }
}
