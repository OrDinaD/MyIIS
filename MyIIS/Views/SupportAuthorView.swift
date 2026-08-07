//
//  SupportAuthorView.swift
//  MyIIS
//
import SwiftUI

enum DonationConfiguration {
    /// Ссылка или deep link для перевода добровольного пожертвования через Беларусбанк.
    /// TODO: Заменить nil на реальную ссылку или deep link Беларусбанка (М-Банкинг / ERIP / QR / перевод на карту), когда реквизиты будут получены.
    static let belarusbankURL: URL? = nil
}

struct SupportAuthorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showNoticeAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                actionSection
                footer
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(NSLocalizedString("support_author_title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(NSLocalizedString("common_done", comment: "")) {
                    dismiss()
                }
            }
        }
        .alert(NSLocalizedString("support_author_title", comment: ""), isPresented: $showNoticeAlert) {
            Button(NSLocalizedString("common_ok", comment: ""), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("support_author_belarusbank_notice", comment: ""))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.pink, .pink.opacity(0.18))
                .accessibilityHidden(true)

            Text(NSLocalizedString("support_author_headline", comment: ""))
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            Text(NSLocalizedString("support_author_message", comment: ""))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(cardShape.fill(Color(uiColor: .secondarySystemGroupedBackground)))
        .overlay(cardShape.stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                if let url = DonationConfiguration.belarusbankURL {
                    openURL(url)
                } else {
                    showNoticeAlert = true
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "building.columns.fill")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white)

                    Text(NSLocalizedString("support_author_belarusbank_button", comment: ""))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.green)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var footer: some View {
        Label {
            Text(NSLocalizedString("support_author_footer", comment: ""))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }
}

#Preview {
    NavigationStack {
        SupportAuthorView()
    }
}
