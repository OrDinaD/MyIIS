//
//  AboutAppView.swift
//  MyIIS
//
import SwiftUI
import UIKit

struct AboutAppView: View {
    @Environment(\.openURL) private var openURL
    @State private var alert: AboutAlert?
    @State private var isUpdatingAcademicNotifications = false
    @State private var isSupportSheetPresented = false
    @AppStorage(AcademicChangeNotificationService.enabledDefaultsKey) private var academicChangeNotificationsEnabled = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                plusSection
                supportSection
                versionSection
                languageSection
                academicNotificationsSection
                linksSection
                documentsSection
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
        .sheet(isPresented: $isSupportSheetPresented) {
            NavigationStack {
                SupportAuthorView()
            }
        }
        .alert(item: $alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(NSLocalizedString("common_ok", comment: "")))
            )
        }
    }

    private var plusSection: some View {
        NavigationLink {
            PlusView()
        } label: {
            AboutPlusCard()
        }
        .buttonStyle(.plain)
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(NSLocalizedString("plus_support_title", comment: ""))

            cardContainer {
                linkRow(
                    icon: "heart.fill",
                    title: NSLocalizedString("plus_support_subtitle", comment: "")
                ) {
                    isSupportSheetPresented = true
                }
            }
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

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(NSLocalizedString("about_section_language", comment: ""))

            cardContainer {
                linkRow(
                    icon: "character.bubble.fill",
                    title: NSLocalizedString("about_app_language_title", comment: "")
                ) {
                    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                        return
                    }
                    openURL(settingsURL)
                }
                .accessibilityHint(NSLocalizedString("about_app_language_hint", comment: ""))
            }

            Text(NSLocalizedString("about_app_language_subtitle", comment: ""))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)
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
                        Toggle(
                            NSLocalizedString("about_academic_notifications_title", comment: ""),
                            isOn: academicNotificationsBinding
                        )
                        .labelsHidden()
                        .accessibilityHint(NSLocalizedString("about_academic_notifications_hint", comment: ""))
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

                divider

                linkRow(
                    icon: "star.fill",
                    title: NSLocalizedString("about_rate_app", comment: "Оценить приложение")
                ) {
                    openURL(AppAboutLinks.appStoreReview)
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

    private func setAcademicNotificationsEnabled(_ enabled: Bool) async {
        guard enabled != academicChangeNotificationsEnabled else { return }
        isUpdatingAcademicNotifications = true
        defer { isUpdatingAcademicNotifications = false }

        if enabled {
            let didEnable = await AcademicChangeNotificationService.shared.enableFromUserAction()
            academicChangeNotificationsEnabled = didEnable

            if !didEnable {
                alert = AboutAlert(
                    title: NSLocalizedString("about_academic_notifications_denied_title", comment: ""),
                    message: NSLocalizedString("about_academic_notifications_denied_message", comment: "")
                )
            }
        } else {
            AcademicChangeNotificationService.shared.disableFromUserAction()
            academicChangeNotificationsEnabled = false
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

private struct AboutPlusCard: View {
    @State private var purchaseManager = PurchaseManager.shared
    @AppStorage("enable_beta_sections") private var enableBetaSections = false

    private var hasPlusAccess: Bool {
        purchaseManager.hasPlus || enableBetaSections
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(hasPlusAccess ? .white.opacity(0.2) : Color.blue.opacity(0.12))

                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(hasPlusAccess ? .white : .blue)
            }
            .frame(width: 52, height: 52)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("MyIIS Plus")
                    .font(.headline)
                    .foregroundStyle(hasPlusAccess ? .white : .primary)

                Text(NSLocalizedString("plus_entry_subtitle", comment: ""))
                    .font(.footnote)
                    .foregroundStyle(hasPlusAccess ? .white.opacity(0.88) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(hasPlusAccess ? .white.opacity(0.7) : Color.secondary.opacity(0.5))
        }
        .padding(16)
        .background {
            if hasPlusAccess {
                AnimatedIridescentCardBackground()
                    .clipShape(cardShape)
            } else {
                cardShape.fill(Color(uiColor: .secondarySystemGroupedBackground))
            }
        }
        .overlay(
            cardShape.stroke(
                hasPlusAccess ? .white.opacity(0.2) : Color.blue.opacity(0.15),
                lineWidth: 1
            )
        )
        .contentShape(cardShape)
        .accessibilityElement(children: .combine)
        .accessibilityHint(NSLocalizedString("plus_entry_hint", comment: ""))
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }
}

private struct AnimatedIridescentCardBackground: View {
    var body: some View {
        TimelineView(.animation(paused: false)) { timeline in
            let time = timeline.date.timeIntervalSince1970
            let angle = Angle(radians: time.truncatingRemainder(dividingBy: 8.0) / 8.0 * .pi * 2)

            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.32, blue: 0.85),
                    Color(red: 0.38, green: 0.18, blue: 0.78),
                    Color(red: 0.15, green: 0.52, blue: 0.76),
                    Color(red: 0.48, green: 0.16, blue: 0.65)
                ],
                startPoint: UnitPoint(
                    x: 0.5 + 0.5 * cos(angle.radians),
                    y: 0.5 + 0.5 * sin(angle.radians)
                ),
                endPoint: UnitPoint(
                    x: 0.5 - 0.5 * cos(angle.radians),
                    y: 0.5 - 0.5 * sin(angle.radians)
                )
            )
        }
    }
}

private struct AboutAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private enum AppAboutLinks {
    static let github = URLFactory.require("https://github.com/OrDinaD/MyIIS")
    static let telegram = URLFactory.require("https://t.me/lokhotonkot")
    static let privacyPolicy = URLFactory.require("https://ordinad.github.io/MyIIS/static/privacy-policy/")
    static let termsAndConditions = URLFactory.require("https://ordinad.github.io/MyIIS/static/terms-and-conditions/")
    static let appStoreReview = URLFactory.require("https://apps.apple.com/app/id6779668761?action=write-review")
}

#Preview {
    NavigationStack {
        AboutAppView()
    }
}
