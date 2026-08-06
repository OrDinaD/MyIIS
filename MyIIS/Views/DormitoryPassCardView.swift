import PassKit
import SwiftUI

// MARK: - Dormitory Pass Data

struct DormitoryPassData: Equatable {
    var dormitoryNumber: String
    var roomNumber: String
    var lastName: String
    var firstName: String
    var middleName: String
    var faculty: String
    var group: String
    var validUntil: String
    var photoURL: URL?

    static var defaultSample: DormitoryPassData {
        DormitoryPassData(
            dormitoryNumber: "5",
            roomNumber: "401 - а",
            lastName: "Василевский",
            firstName: "Владислав",
            middleName: "Валерьевич",
            faculty: "ФИТУ",
            group: "428503",
            validUntil: "30.06.2025",
            photoURL: nil
        )
    }
}

// MARK: - PassKit Button Wrapper

struct PKAddPassButtonRepresentable: UIViewRepresentable {
    var addPassAction: () -> Void

    func makeUIView(context: Context) -> PKAddPassButton {
        let button = PKAddPassButton(addPassButtonStyle: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.buttonTapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: PKAddPassButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(addPassAction: addPassAction)
    }

    final class Coordinator: NSObject {
        let addPassAction: () -> Void

        init(addPassAction: @escaping () -> Void) {
            self.addPassAction = addPassAction
        }

        @objc func buttonTapped() {
            addPassAction()
        }
    }
}

// MARK: - PassKit Sheet View Controller Representable

struct PKAddPassesViewControllerRepresentable: UIViewControllerRepresentable {
    let pass: PKPass
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> PKAddPassesViewController {
        guard let controller = PKAddPassesViewController(pass: pass) else {
            fatalError("Could not create PKAddPassesViewController")
        }
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PKAddPassesViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    final class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            controller.dismiss(animated: true) {
                self.onDismiss()
            }
        }
    }
}

// MARK: - Dormitory Pass Card View

struct DormitoryPassCardView: View {
    let passData: DormitoryPassData
    let onAddToWallet: () -> Void

    private var timesNewRomanFontName: String {
        "Times New Roman"
    }

    var body: some View {
        VStack(spacing: 14) {
            // Заголовок
            HStack {
                Label("Пропуск в общежитие", systemImage: "person.badge.shield.checkmark.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }

            // Корпус карт-бланка пропуска в общежитие
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.96, green: 0.92, blue: 0.62))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.85), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 6) {
                    // Заголовок и комната
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ОБЩЕЖИТИЕ № \(passData.dormitoryNumber)")
                            .font(.custom(timesNewRomanFontName, size: 20).weight(.bold))
                            .foregroundStyle(.black)

                        Text("КОМНАТА № \(passData.roomNumber)")
                            .font(.custom(timesNewRomanFontName, size: 18).weight(.bold))
                            .foregroundStyle(.black)
                    }

                    // ФИО
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ф. \(passData.lastName)")
                            .font(.custom(timesNewRomanFontName, size: 17).weight(.bold))
                            .foregroundStyle(.black)

                        Text("И. \(passData.firstName)")
                            .font(.custom(timesNewRomanFontName, size: 17).weight(.bold))
                            .foregroundStyle(.black)

                        Text("О. \(passData.middleName)")
                            .font(.custom(timesNewRomanFontName, size: 17).weight(.bold))
                            .foregroundStyle(.black)
                    }
                    .padding(.top, 2)

                    // Факультет и Группа
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ФАКУЛЬТЕТ \(passData.faculty.uppercased())")
                            .font(.custom(timesNewRomanFontName, size: 16).weight(.bold))
                            .foregroundStyle(.black)

                        Text("ГРУППА \(passData.group)")
                            .font(.custom(timesNewRomanFontName, size: 16).weight(.bold))
                            .foregroundStyle(.black)
                    }
                    .padding(.top, 2)

                    // Срок действия
                    Text("ДЕЙСТВИТЕЛЬНО ДО \(passData.validUntil)")
                        .font(.custom(timesNewRomanFontName, size: 15).weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.top, 2)

                    Spacer(minLength: 12)

                    // Подпись и штамп
                    HStack(alignment: .bottom) {
                        // Фото студента
                        ZStack {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 92, height: 112)
                                .overlay(Rectangle().stroke(Color.black, lineWidth: 1.2))

                            if let photoURL = passData.photoURL {
                                AsyncImage(url: photoURL) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 90, height: 110)
                                            .clipped()
                                    default:
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 42))
                                            .foregroundStyle(.gray)
                                    }
                                }
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 42))
                                    .foregroundStyle(.gray)
                            }
                        }

                        Spacer()

                        // Печать М.П. и подпись начальника студгородка
                        VStack(alignment: .trailing, spacing: 4) {
                            ZStack(alignment: .bottomTrailing) {
                                // Сине-фиолетовый штамп "Студенческий городок"
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(red: 0.15, green: 0.25, blue: 0.70).opacity(0.75), lineWidth: 1.5)
                                    .frame(width: 116, height: 38)
                                    .overlay(
                                        VStack(spacing: 1) {
                                            Text("СТУДЕНЧЕСКИЙ")
                                                .font(.custom(timesNewRomanFontName, size: 9).weight(.bold))
                                            Text("ГОРОДОК")
                                                .font(.custom(timesNewRomanFontName, size: 8).weight(.bold))
                                        }
                                        .foregroundStyle(Color(red: 0.15, green: 0.25, blue: 0.70).opacity(0.8))
                                    )
                                    .rotationEffect(.degrees(-7))
                                    .offset(x: -8, y: -10)

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("М.П.")
                                        .font(.custom(timesNewRomanFontName, size: 14).weight(.bold))
                                        .foregroundStyle(.black)

                                    Text("Начальник студгородка")
                                        .font(.custom(timesNewRomanFontName, size: 13).weight(.bold))
                                        .foregroundStyle(.black)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(0.72, contentMode: .fit)

            // Кнопка сохранения в Apple Wallet
            PKAddPassButtonRepresentable {
                onAddToWallet()
            }
            .frame(height: 48)
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
