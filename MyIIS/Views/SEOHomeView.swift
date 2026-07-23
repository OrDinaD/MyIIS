import SwiftUI

struct SEOHomeView: View {
    @StateObject private var lmsService = LMSService.shared
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard

                    if let message = lmsService.errorMessage {
                        refreshStatusCard(message)
                    }

                    if lmsService.isLoggedIn {
                        if lmsService.courses.isEmpty {
                            if lmsService.isLoading {
                                ProgressView("Загрузка курсов...")
                                    .padding()
                            } else {
                                Text("Нет доступных курсов")
                                    .foregroundStyle(.secondary)
                                    .padding()
                            }
                        } else {
                            coursesList
                        }
                    } else {
                        loginCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("СЭО")
            .navigationBarTitleDisplayMode(.large)
            .glassNavigationBar()
            .hiddenNavigationBarBackground()
            .task {
                await lmsService.checkSession()
            }
            .refreshable {
                await lmsService.refreshCourses(force: true)
            }
            .alert("Ошибка", isPresented: $showingError) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func refreshStatusCard(_ message: String) -> some View {
        GlassCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.title3)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 8) {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Повторить") {
                        Task {
                            await lmsService.refreshCourses(force: true)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .disabled(lmsService.isLoading)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
        }
    }

    private var headerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Система электронного обучения")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)

                        Text("Доступ к лекциям, заданиям и тестам на базе Moodle.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if lmsService.isLoggedIn {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Вы авторизованы")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Button(role: .destructive) {
                            lmsService.logout()
                        } label: {
                            Text("Выйти")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
        }
    }

    private var loginCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                Text("Требуется авторизация")
                    .font(.headline)

                Text("Для входа используются те же данные, что и для личного кабинета ИИС БГУИР.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    Task {
                        do {
                            try await lmsService.login()
                        } catch {
                            errorMessage = error.localizedDescription
                            showingError = true
                        }
                    }
                } label: {
                    HStack {
                        if lmsService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Войти через ИИС")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundColor(.white)
                    .font(.headline)
                }
                .disabled(lmsService.isLoading)
                .padding(.top, 8)
            }
            .padding(16)
        }
    }

    private var coursesList: some View {
        LazyVStack(spacing: 12) {
            ForEach(lmsService.courses) { course in
                NavigationLink(destination: LMSCourseDetailView(course: course)) {
                    GlassCard {
                        HStack(spacing: 16) {
                            if let bgUrl = course.backgroundUrl {
                                CachedAsyncImage(
                                    url: bgUrl,
                                    maxPixelSize: 240
                                ) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.accentColor.opacity(0.2)
                                        .overlay(Image(systemName: "book.fill").foregroundStyle(Color.accentColor))
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            } else {
                                Color.accentColor.opacity(0.2)
                                    .frame(width: 80, height: 80)
                                    .overlay(Image(systemName: "book.fill").foregroundStyle(Color.accentColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(course.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(3)

                                if !course.teachers.isEmpty {
                                    Text(course.teachersString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    SEOHomeView()
}
