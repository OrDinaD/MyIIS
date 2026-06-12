//
//  SupportAuthorView.swift
//  MyIIS
//
import StoreKit
import SwiftUI

struct SupportAuthorView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                productSection
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

    @ViewBuilder
    private var productSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("support_author_products_title", comment: ""))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            if #available(iOS 17.0, *) {
                StoreView(ids: SupportAuthorProduct.allProductIDs)
                    .productViewStyle(.regular)
                    .padding(.vertical, 6)
                    .background(cardShape.fill(Color(uiColor: .secondarySystemGroupedBackground)))
                    .overlay(cardShape.stroke(Color.white.opacity(0.08), lineWidth: 1))
            } else {
                unavailablePurchasesView
            }
        }
    }

    private var unavailablePurchasesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(NSLocalizedString("support_author_unavailable_title", comment: ""), systemImage: "creditcard.trianglebadge.exclamationmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

            Text(NSLocalizedString("support_author_unavailable_message", comment: ""))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardShape.fill(Color(uiColor: .secondarySystemGroupedBackground)))
        .overlay(cardShape.stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var footer: some View {
        Label {
            Text(NSLocalizedString("support_author_footer", comment: ""))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 4)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }
}

private enum SupportAuthorProduct: String, CaseIterable {
    case coffee = "myiis.tip.coffee"
    case lunch = "myiis.tip.lunch"
    case generous = "myiis.tip.generous"

    static var allProductIDs: [String] {
        allCases.map(\.rawValue)
    }
}

#Preview {
    NavigationStack {
        SupportAuthorView()
    }
}
