import Combine
import QuickLook
import SwiftUI

class SupportDocumentDownloader: ObservableObject {
    @Published var isDownloading = false
    @Published var downloadedFileURL: URL?
    @Published var errorMessage: String?

    func downloadFile(from url: URL, filename: String) async {
        DispatchQueue.main.async {
            self.isDownloading = true
            self.errorMessage = nil
            self.downloadedFileURL = nil
        }

        do {
            let (tempURL, response) = try await URLSession.shared.download(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    self.errorMessage = String(localized: "Ошибка при загрузке документа")
                    self.isDownloading = false
                }
                return
            }

            let documentsDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let destinationURL = documentsDirectory.appendingPathComponent(filename)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            DispatchQueue.main.async {
                self.downloadedFileURL = destinationURL
                self.isDownloading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = String(
                    format: String(localized: "Не удалось загрузить файл: %@"),
                    error.localizedDescription
                )
                self.isDownloading = false
            }
        }
    }
}

struct SupportView: View {
    @StateObject private var downloader = SupportDocumentDownloader()

    var body: some View {
        List {
            ForEach(SupportConfiguration.documentGroups) { group in
                Section(header: Text(group.groupName)) {
                    if let note = group.note {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(note)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    ForEach(group.items) { item in
                        Button {
                            Task {
                                let filename = item.url.lastPathComponent
                                await downloader.downloadFile(from: item.url, filename: filename)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text(item.title).font(.body).foregroundColor(.primary)
                                    Text(item.number).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Техническая поддержка")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if downloader.isDownloading {
                ZStack {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    VStack {
                        ProgressView()
                            .padding(.bottom, 8)
                        Text("Загрузка документа...")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(24)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 10)
                }
            }
        }
        .quickLookPreview($downloader.downloadedFileURL)
        .alert("Ошибка",
               isPresented: Binding(
                get: { downloader.errorMessage != nil },
                set: { if !$0 { downloader.errorMessage = nil } }
               ),
               presenting: downloader.errorMessage
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
    }
}
