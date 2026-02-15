import SwiftUI

/// View для отображения логов из `LogService` с возможностью запуска API тестов.
struct DebugView: View {

    @StateObject private var logService = LogService.shared
    @State private var isTestRunning = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // API Tests Section
                VStack(spacing: 12) {
                    Text("API Tests")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top)

                    HStack(spacing: 12) {
                        Button {
                            runAuthFlowTest()
                        } label: {
                            Label("Auth Flow", systemImage: "person.badge.key.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isTestRunning)

                        Button {
                            runInvalidCredentialsTest()
                        } label: {
                            Label("Invalid Auth", systemImage: "xmark.shield.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isTestRunning)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .background(Color(uiColor: .secondarySystemBackground))

                Divider()

                // Logs Section
                if logService.messages.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "text.append")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Нет логов")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Запустите тест для просмотра логов")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        List {
                            ForEach(Array(logService.messages.enumerated()), id: \.offset) { index, message in
                                Text(message)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.vertical, 2)
                                    .textSelection(.enabled)
                                    .id(index)
                            }
                        }
                        .onChange(of: logService.messages.count) { _, newCount in
                            withAnimation {
                                proxy.scrollTo(newCount - 1, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Панель отладки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Назад", systemImage: "chevron.left")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        logService.clearLogs()
                    } label: {
                        Label("Очистить", systemImage: "trash")
                    }
                    .disabled(logService.messages.isEmpty)
                }
            }
            .overlay {
                if isTestRunning {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("Выполняется тест...")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .padding(32)
                        .background {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Test Methods

    private func runAuthFlowTest() {
        isTestRunning = true
        logService.clearLogs()

        Task {
            let test = AuthAPITest()
            await test.testFullAuthFlow()

            await MainActor.run {
                isTestRunning = false
            }
        }
    }

    private func runInvalidCredentialsTest() {
        isTestRunning = true
        logService.clearLogs()

        Task {
            let test = AuthAPITest()
            await test.testInvalidCredentials()

            await MainActor.run {
                isTestRunning = false
            }
        }
    }
}

#Preview {
    DebugView()
}
