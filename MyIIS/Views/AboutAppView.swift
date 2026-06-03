//
//  AboutAppView.swift
//  MyIIS
//
import SwiftUI

struct AboutAppView: View {
    @Environment(\.openURL) private var openURL
    @State private var selectedIcon = AppIconManager.currentIcon
    @State private var iconAlert: IconAlert?
    @State private var isUpdatingAcademicNotifications = false
    @AppStorage("enable_beta_sections") private var enableBetaSections = false
    @AppStorage(AcademicChangeNotificationService.enabledDefaultsKey) private var academicChangeNotificationsEnabled = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                versionSection
                academicNotificationsSection
                linksSection
                documentsSection
                if AppIconManager.supportsAlternateIcons && enableBetaSections {
                    appIconSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
        .background(
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
        )
        .navigationTitle(NSLocalizedString("about_title", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .hiddenNavigationBarBackground()
        .alert(item: $iconAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("Ок")))
        }
    }

    private var versionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(NSLocalizedString("about_section_version", comment: ""))

            Text(versionText)
                .font(.title2.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                .background(cardShape.fill(cardBackgroundColor))
                .overlay(cardShape.stroke(cardBorderColor, lineWidth: 1))
        }
    }

    private var academicNotificationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(NSLocalizedString("about_section_notifications", comment: ""))

            cardContainer {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "bell.badge.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("about_academic_notifications_title", comment: ""))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text(NSLocalizedString("about_academic_notifications_subtitle", comment: ""))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isUpdatingAcademicNotifications {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Toggle("", isOn: academicNotificationsBinding)
                            .labelsHidden()
                    }
                }
                .padding(.vertical, 12)
            }
        }
    }

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(NSLocalizedString("about_section_links", comment: ""))

            cardContainer {
                linkRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: NSLocalizedString("about_github", comment: "")
                ) {
                    openURL(AppAboutLinks.github)
                }

                divider

                linkRow(
                    icon: "paperplane",
                    title: NSLocalizedString("about_telegram", comment: "")
                ) {
                    openURL(AppAboutLinks.telegram)
                }
            }

            Text(NSLocalizedString("about_contact_me", comment: ""))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)
        }
    }

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(NSLocalizedString("about_section_documents", comment: ""))

            cardContainer {
                linkRow(
                    icon: "hand.raised.fill",
                    title: NSLocalizedString("about_privacy_policy", comment: "")
                ) {
                    openURL(AppAboutLinks.privacyPolicy)
                }

                divider

                linkRow(
                    icon: "doc.text.fill",
                    title: NSLocalizedString("about_terms", comment: "")
                ) {
                    openURL(AppAboutLinks.termsAndConditions)
                }
            }
        }
    }

    private var appIconSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Иконка приложения")

            LazyVGrid(columns: iconColumns, spacing: 12) {
                ForEach(AppIconOption.allCases) { option in
                    appIconButton(for: option)
                }
            }
        }
    }

    private var iconColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 92), spacing: 12)]
    }

    private var academicNotificationsBinding: Binding<Bool> {
        Binding(
            get: { academicChangeNotificationsEnabled },
            set: { newValue in
                Task { await setAcademicNotificationsEnabled(newValue) }
            }
        )
    }

    private var divider: some View {
        Divider()
            .overlay(Color.secondary.opacity(0.2))
            .padding(.leading, 48)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(cardShape.fill(cardBackgroundColor))
        .overlay(cardShape.stroke(cardBorderColor, lineWidth: 1))
    }

    private func linkRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 28)

                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func appIconButton(for option: AppIconOption) -> some View {
        Button {
            Task { await applyIcon(option) }
        } label: {
            VStack(spacing: 8) {
                AppIconPreview(option: option)
                    .frame(width: 62, height: 62)

                Text(option.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(.primary)

                Image(systemName: option == selectedIcon ? "checkmark.circle.fill" : "circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(option == selectedIcon ? Color.green : Color.secondary.opacity(0.45))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(cardShape.fill(cardBackgroundColor))
            .overlay(
                cardShape.stroke(
                    option == selectedIcon ? Color.green.opacity(0.45) : cardBorderColor,
                    lineWidth: option == selectedIcon ? 1.5 : 1
                )
            )
            .contentShape(cardShape)
        }
        .buttonStyle(.plain)
        .disabled(option == selectedIcon)
    }

    private func setAcademicNotificationsEnabled(_ enabled: Bool) async {
        guard enabled != academicChangeNotificationsEnabled else { return }
        isUpdatingAcademicNotifications = true
        defer { isUpdatingAcademicNotifications = false }

        if enabled {
            let didEnable = await AcademicChangeNotificationService.shared.enableFromUserAction()
            academicChangeNotificationsEnabled = didEnable

            if !didEnable {
                iconAlert = IconAlert(
                    title: NSLocalizedString("about_academic_notifications_denied_title", comment: ""),
                    message: NSLocalizedString("about_academic_notifications_denied_message", comment: "")
                )
            }
        } else {
            AcademicChangeNotificationService.shared.disableFromUserAction()
            academicChangeNotificationsEnabled = false
        }
    }

    private func applyIcon(_ option: AppIconOption) async {
        guard option != selectedIcon else { return }

        do {
            try await AppIconManager.setIcon(option)
            selectedIcon = option
        } catch {
            iconAlert = IconAlert(title: "Ошибка", message: "Не удалось изменить иконку приложения.")
        }
    }

    private var versionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(shortVersion)(\(buildNumber))"
    }

    private var cardBackgroundColor: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    private var cardBorderColor: Color {
        Color.white.opacity(0.08)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }
}

private struct AppIconPreview: View {
    let option: AppIconOption

    var body: some View {
        Image(option.previewAssetName)
            .resizable()
            .scaledToFill()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
    }
}

private struct IconAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private enum AppAboutLinks {
    static let github = URLFactory.require("https://github.com/OrDinaD/MyIIS")
    static let telegram = URLFactory.require("https://t.me/lokhotonkot")
    static let privacyPolicy = URLFactory.require("https://ordinad.github.io/MyIIS/static/privacy-policy/")
    static let termsAndConditions = URLFactory.require("https://ordinad.github.io/MyIIS/static/terms-and-conditions/")
}

#Preview {
    NavigationStack {
        AboutAppView()
    }
}
