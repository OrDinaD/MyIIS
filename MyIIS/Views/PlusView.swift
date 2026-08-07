import StoreKit
import SwiftUI
import UIKit

struct PlusView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("enable_beta_sections") private var enableBetaSections = false
    @State private var purchaseManager = PurchaseManager.shared
    @State private var selectedIcon = AppIconManager.currentIcon
    @State private var updatingIcon: AppIconOption?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var isSupportSheetPresented = false
    @State private var alert: PlusAlert?

    private var hasPlusAccess: Bool {
        purchaseManager.hasPlus || enableBetaSections
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroCard
                purchaseCard
                featuresSection
                iconSection
                supportSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(NSLocalizedString("plus_title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .hiddenNavigationBarBackground()
        .task {
            await purchaseManager.prepare()
            selectedIcon = AppIconManager.currentIcon
        }
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
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.2),
            value: purchaseManager.hasPlus
        )
    }
}

private extension PlusView {
    var heroCard: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.17))
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 58, height: 58)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("MyIIS Plus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text(NSLocalizedString("plus_hero_subtitle", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)

                Label(
                    NSLocalizedString("plus_lifetime_badge", comment: ""),
                    systemImage: "infinity"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [.indigo, .purple, .pink.opacity(0.86)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: cardShape
        )
        .overlay(cardShape.stroke(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .purple.opacity(0.18), radius: 18, y: 10)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var purchaseCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if purchaseManager.hasPlus {
                accessStatus(
                    icon: "checkmark.seal.fill",
                    title: NSLocalizedString("plus_active_title", comment: ""),
                    message: NSLocalizedString("plus_active_message", comment: ""),
                    color: .green
                )
            } else if enableBetaSections {
                accessStatus(
                    icon: "hammer.fill",
                    title: NSLocalizedString("plus_beta_access_title", comment: ""),
                    message: NSLocalizedString("plus_beta_access_message", comment: ""),
                    color: .orange
                )
            } else if purchaseManager.isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(NSLocalizedString("plus_loading", comment: ""))
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            } else if let product = purchaseManager.plusProduct {
                Button {
                    Task { await purchase() }
                } label: {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }

                        Text(
                            String(
                                format: NSLocalizedString("plus_purchase_button_format", comment: ""),
                                product.displayPrice
                            )
                        )
                        .fontWeight(.semibold)

                        Spacer()

                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .tint(.indigo)
                .controlSize(.large)
                .disabled(isPurchasing || isRestoring)
            } else {
                accessStatus(
                    icon: "clock.badge.checkmark",
                    title: NSLocalizedString("plus_preparing_title", comment: ""),
                    message: NSLocalizedString("plus_preparing_message", comment: ""),
                    color: .indigo
                )

                Button(NSLocalizedString("plus_retry_store", comment: "")) {
                    Task { await purchaseManager.reload() }
                }
                .buttonStyle(.bordered)
                .disabled(purchaseManager.isLoading)
            }

            if !purchaseManager.hasPlus {
                Button {
                    Task { await restorePurchases() }
                } label: {
                    if isRestoring {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(NSLocalizedString("plus_restore", comment: ""))
                    }
                }
                .font(.subheadline.weight(.semibold))
                .disabled(isPurchasing || isRestoring)
            }

            Text(NSLocalizedString("plus_purchase_note", comment: ""))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardShape.fill(Color(uiColor: .secondarySystemGroupedBackground)))
        .overlay(cardShape.stroke(cardBorderColor, lineWidth: 1))
    }

}

private extension PlusView {
    var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: NSLocalizedString("plus_features_title", comment: ""),
                subtitle: NSLocalizedString("plus_features_subtitle", comment: "")
            )

            LazyVGrid(columns: featureColumns, spacing: 12) {
                ForEach(PlusFeature.allCases) { feature in
                    PlusFeatureCard(feature: feature)
                }
            }
        }
    }

    @ViewBuilder
    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: NSLocalizedString("plus_icons_title", comment: ""),
                subtitle: NSLocalizedString("plus_icons_subtitle", comment: "")
            )

            if AppIconManager.supportsAlternateIcons {
                if !hasPlusAccess {
                    Label {
                        Text(NSLocalizedString("plus_icons_locked_message", comment: ""))
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "lock.fill")
                    }
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.indigo.opacity(0.08))
                    )
                }

                LazyVGrid(columns: iconColumns, spacing: 12) {
                    ForEach(AppIconOption.allCases) { option in
                        iconButton(for: option)
                    }
                }
                .opacity(hasPlusAccess ? 1 : 0.58)
            } else {
                Label(
                    NSLocalizedString("plus_icons_unsupported", comment: ""),
                    systemImage: "iphone.slash"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardShape.fill(Color(uiColor: .secondarySystemGroupedBackground)))
            }
        }
    }

    private var supportSection: some View {
        Button {
            isSupportSheetPresented = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundStyle(.pink)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(NSLocalizedString("plus_support_title", comment: ""))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(NSLocalizedString("plus_support_subtitle", comment: ""))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .contentShape(cardShape)
        }
        .buttonStyle(.plain)
        .background(cardShape.fill(Color(uiColor: .secondarySystemGroupedBackground)))
        .overlay(cardShape.stroke(cardBorderColor, lineWidth: 1))
        .accessibilityHint(NSLocalizedString("plus_support_hint", comment: ""))
    }

    private func accessStatus(
        icon: String,
        title: String,
        message: String,
        color: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private func iconButton(for option: AppIconOption) -> some View {
        let isSelected = option == selectedIcon
        let isUpdating = option == updatingIcon

        return Button {
            Task { await applyIcon(option) }
        } label: {
            VStack(spacing: 8) {
                PlusAppIconPreview(option: option)
                    .frame(width: 64, height: 64)

                Text(option.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(.primary)

                if isUpdating {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            isSelected ? Color.green : Color.secondary.opacity(0.45)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(cardShape.fill(Color(uiColor: .secondarySystemGroupedBackground)))
            .overlay(
                cardShape.stroke(
                    isSelected ? Color.green.opacity(0.5) : cardBorderColor,
                    lineWidth: isSelected ? 1.5 : 1
                )
            )
            .contentShape(cardShape)
        }
        .buttonStyle(.plain)
        .disabled(!hasPlusAccess || updatingIcon != nil || isSelected)
        .accessibilityLabel(option.displayName)
        .accessibilityValue(
            isSelected ? NSLocalizedString("plus_icon_selected", comment: "") : ""
        )
        .accessibilityHint(NSLocalizedString("about_app_icon_accessibility_hint", comment: ""))
    }

}

private extension PlusView {
    func purchase() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            switch try await purchaseManager.purchasePlus() {
            case .purchased, .cancelled:
                break
            case .pending:
                alert = PlusAlert(
                    title: NSLocalizedString("plus_purchase_pending_title", comment: ""),
                    message: NSLocalizedString("plus_purchase_pending_message", comment: "")
                )
            }
        } catch {
            alert = PlusAlert(
                title: NSLocalizedString("common_error", comment: ""),
                message: NSLocalizedString("plus_purchase_error", comment: "")
            )
        }
    }

    private func restorePurchases() async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await purchaseManager.restorePurchases()
            alert = PlusAlert(
                title: purchaseManager.hasPlus
                    ? NSLocalizedString("plus_restore_success_title", comment: "")
                    : NSLocalizedString("plus_restore_empty_title", comment: ""),
                message: purchaseManager.hasPlus
                    ? NSLocalizedString("plus_restore_success_message", comment: "")
                    : NSLocalizedString("plus_restore_empty_message", comment: "")
            )
        } catch {
            alert = PlusAlert(
                title: NSLocalizedString("common_error", comment: ""),
                message: NSLocalizedString("plus_restore_error", comment: "")
            )
        }
    }

    private func applyIcon(_ option: AppIconOption) async {
        guard hasPlusAccess, option != selectedIcon, updatingIcon == nil else { return }
        updatingIcon = option
        defer { updatingIcon = nil }

        do {
            try await AppIconManager.setIcon(option)
            selectedIcon = AppIconManager.currentIcon
        } catch {
            alert = PlusAlert(
                title: NSLocalizedString("common_error", comment: ""),
                message: NSLocalizedString("about_app_icon_error_message", comment: "")
            )
        }
    }

    private var featureColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 148), spacing: 12)]
    }

    private var iconColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 96), spacing: 12)]
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }

    private var cardBorderColor: Color {
        Color.white.opacity(0.09)
    }
}

private struct PlusFeatureCard: View {
    let feature: PlusFeature

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: feature.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(feature.color)
                .frame(width: 34, height: 34)
                .background(feature.color.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            Text(feature.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(feature.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct PlusAppIconPreview: View {
    let option: AppIconOption

    var body: some View {
        Group {
            if let image = UIImage(named: option.previewAssetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [.indigo.opacity(0.85), .purple.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "app.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, y: 5)
    }
}

private enum PlusFeature: String, CaseIterable, Identifiable {
    case widgets
    case notifications
    case colors
    case icons
    case tabs
    case watch

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .widgets: return "rectangle.3.group.fill"
        case .notifications: return "bell.badge.fill"
        case .colors: return "paintpalette.fill"
        case .icons: return "app.badge.fill"
        case .tabs: return "rectangle.bottomthird.inset.filled"
        case .watch: return "applewatch"
        }
    }

    var color: Color {
        switch self {
        case .widgets: return .blue
        case .notifications: return .orange
        case .colors: return .pink
        case .icons: return .purple
        case .tabs: return .indigo
        case .watch: return .green
        }
    }

    var title: String {
        NSLocalizedString("plus_feature_\(rawValue)_title", comment: "")
    }

    var subtitle: String {
        NSLocalizedString("plus_feature_\(rawValue)_subtitle", comment: "")
    }
}

private struct PlusAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    NavigationStack {
        PlusView()
    }
}
