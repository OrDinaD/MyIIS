//
//  BalloonsView.swift
//  MyIIS
//

import SwiftUI

// MARK: - Shake Gesture Support

extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name(rawValue: "deviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
    }
}

struct ShakeGestureModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
                action()
            }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(ShakeGestureModifier(action: action))
    }
}

// MARK: - Balloons Overlay

struct Balloon: Identifiable {
    let id = UUID()
    var xOffset: CGFloat
    let color: Color
    let scale: CGFloat
    let delay: Double
    let rotation: Double
    let zRotation: Double
}

struct BalloonsOverlayView: View {
    @Binding var isPresented: Bool
    @State private var balloons: [Balloon] = []
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isPresented {
                    ForEach(balloons) { balloon in
                        Image(systemName: "balloon.2.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80 * balloon.scale, height: 100 * balloon.scale)
                            .foregroundStyle(balloon.color.gradient)
                            .shadow(color: balloon.color.opacity(0.5), radius: 12, x: 0, y: 10)
                            .rotation3DEffect(.degrees(balloon.rotation), axis: (x: 0, y: 1, z: 0))
                            .rotationEffect(.degrees(balloon.zRotation))
                            .offset(x: balloon.xOffset, y: isAnimating ? -geometry.size.height - 200 : geometry.size.height + 200)
                            .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 4.5).delay(balloon.delay), value: isAnimating)
                    }
                }
            }
            .onChange(of: isPresented) { _, newValue in
                if newValue {
                    setupBalloons(width: geometry.size.width)
                    isAnimating = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isAnimating = true
                    }
                    
                    // Hide after animation finishes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) {
                        isPresented = false
                        isAnimating = false
                    }
                } else {
                    isAnimating = false
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func setupBalloons(width: CGFloat) {
        let colors: [Color] = [.red, .blue, .green, .orange, .purple, .pink, .yellow, .cyan]
        balloons = (0..<20).map { _ in
            Balloon(
                xOffset: CGFloat.random(in: -width/2...width/2),
                color: colors.randomElement() ?? .blue,
                scale: CGFloat.random(in: 0.6...1.5),
                delay: Double.random(in: 0...2.0),
                rotation: Double.random(in: -40...40),
                zRotation: Double.random(in: -20...20)
            )
        }
    }
}

// MARK: - Birthday Modifier

struct BirthdayBalloonsModifier: ViewModifier {
    let user: User?
    @State private var showBalloons = false
    @State private var hasShownForBirthday = false

    func body(content: Content) -> some View {
        content
            .overlay {
                BalloonsOverlayView(isPresented: $showBalloons)
            }
            .onShake {
                triggerBalloons()
            }
            .onAppear {
                checkBirthdayAndTrigger()
            }
            .onChange(of: user) { _, _ in
                checkBirthdayAndTrigger()
            }
    }

    private func checkBirthdayAndTrigger() {
        if !hasShownForBirthday, let user = user, isBirthday(user.birthDay) {
            triggerBalloons()
            hasShownForBirthday = true
        }
    }

    private func triggerBalloons() {
        showBalloons = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showBalloons = true
        }
    }

    private func isBirthday(_ dateString: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var parsedDate = formatter.date(from: dateString)
        
        if parsedDate == nil {
            formatter.dateFormat = "dd.MM.yyyy"
            parsedDate = formatter.date(from: dateString)
        }
        
        guard let date = parsedDate else { return false }
        
        let today = Date()
        let cal = Calendar.current
        return cal.component(.month, from: date) == cal.component(.month, from: today) &&
               cal.component(.day, from: date) == cal.component(.day, from: today)
    }
}

extension View {
    func withBirthdayBalloons(user: User?) -> some View {
        self.modifier(BirthdayBalloonsModifier(user: user))
    }
}