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
    @State private var previewURL: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                fileBadge

                VStack(spacing: 8) {
                    Text(file.title)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)

                    Text(file.url.lastPathComponent)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    if let fileSizeDescription {
                        Text(fileSizeDescription)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                VStack(spacing: 10) {
                    Button {
                        previewURL = file.url
                    } label: {
                        Label("Открыть предпросмотр", systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    ShareLink(
                        item: file.url,
                        preview: SharePreview(file.title)
                    ) {
                        Label("Сохранить", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Документ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common_close", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
        .quickLookPreview($previewURL)
    }

    private var fileBadge: some View {
        Image(systemName: fileIconName)
            .font(.system(size: 42, weight: .semibold))
            .foregroundStyle(.blue)
            .frame(width: 82, height: 82)
            .background(Color(.secondarySystemGroupedBackground), in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private var fileIconName: String {
        switch file.url.pathExtension.lowercased() {
        case "pdf":
            return "doc.richtext"
        case "xls", "xlsx", "csv":
            return "tablecells"
        case "jpg", "jpeg", "png", "heic":
            return "photo"
        default:
            return "doc"
        }
    }

    private var fileSizeDescription: String? {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: file.url.path),
            let size = attributes[.size] as? Int64
        else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
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
