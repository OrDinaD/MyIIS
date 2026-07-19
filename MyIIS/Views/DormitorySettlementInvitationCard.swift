import SwiftUI

struct DormitorySettlementInvitationCard: View {
    let application: DormitoryQueueApplication
    let onReveal: () -> Void

    var body: some View {
        Button(action: onReveal) {
            ZStack(alignment: .topTrailing) {
                DormitoryFacadePattern()

                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Image(systemName: "house.fill")
                            .font(.title2.weight(.bold))
                            .frame(width: 46, height: 46)
                            .background(.white.opacity(0.16), in: Circle())

                        Text(application.status)
                            .font(.system(.title, design: .rounded, weight: .bold))

                        Spacer(minLength: 8)

                        Image(systemName: "sparkles")
                            .font(.title3.weight(.bold))
                    }

                    Text(dormitoryLocalized("dormitory_reveal_invitation_body"))
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)

                    Label(
                        dormitoryLocalized("dormitory_reveal_invitation_action"),
                        systemImage: "key.horizontal.fill"
                    )
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(red: 0.02, green: 0.45, blue: 0.36))
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(.white, in: Capsule())

                    Text(
                        String(
                            format: dormitoryLocalized("dormitory_application_number"),
                            application.number
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                }
                .foregroundStyle(.white)
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.45, blue: 0.36),
                        Color(red: 0.02, green: 0.62, blue: 0.46),
                        Color(red: 0.04, green: 0.72, blue: 0.61)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: Color.green.opacity(0.18), radius: 20, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityHint(dormitoryLocalized("dormitory_reveal_invitation_hint"))
    }
}

#if DEBUG
#Preview("Заселён — узнать, куда") {
    ScrollView {
        DormitorySettlementInvitationCard(
            application: DormitorySettlementReveal.demo.application,
            onReveal: {}
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
#endif
