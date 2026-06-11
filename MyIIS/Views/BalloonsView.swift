//
//  BalloonsView.swift
//  MyIIS
//

import SwiftUI
import SceneKit

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

// MARK: - 3D Balloons Overlay

struct TransparentSceneView: UIViewRepresentable {
    let scene: SCNScene

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        view.backgroundColor = .clear
        view.autoenablesDefaultLighting = true
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.scene = scene
    }
}

struct BalloonsOverlayView: View {
    @Binding var isPresented: Bool
    @State private var scene = SCNScene()

    var body: some View {
        ZStack {
            if isPresented {
                TransparentSceneView(scene: scene)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isPresented) { _, newValue in
            if newValue {
                setupScene()
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                    isPresented = false
                }
            }
        }
    }

    private func setupScene() {
        scene = SCNScene()
        scene.background.contents = UIColor.clear

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 12)
        scene.rootNode.addChildNode(cameraNode)

        // Add soft lighting for reflections
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.light?.intensity = 1500
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)

        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = UIColor(white: 0.4, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLightNode)

        let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemPink, .systemYellow, .systemTeal]

        for _ in 0..<30 {
            let balloon = createBalloonNode(color: colors.randomElement() ?? .systemBlue)
            
            let startX = Float.random(in: -7...7)
            let startY = Float.random(in: -15 ... -10)
            let startZ = Float.random(in: -5...2)
            balloon.position = SCNVector3(startX, startY, startZ)
            
            balloon.eulerAngles = SCNVector3(
                Float.random(in: -0.2...0.2),
                Float.random(in: -0.5...0.5),
                Float.random(in: -0.2...0.2)
            )
            
            scene.rootNode.addChildNode(balloon)
            
            let endY = CGFloat.random(in: 15...25)
            let duration = TimeInterval.random(in: 3.5...5.5)
            let delay = TimeInterval.random(in: 0...1.5)
            
            let moveUp = SCNAction.moveBy(x: CGFloat.random(in: -2...2), y: endY - CGFloat(startY), z: CGFloat.random(in: -1...1), duration: duration)
            moveUp.timingMode = .easeInEaseOut
            
            // Sway effect via custom action
            let sway = SCNAction.customAction(duration: duration) { node, elapsedTime in
                node.position.x += Float(sin(elapsedTime * 3)) * 0.02
            }
            
            let group = SCNAction.group([moveUp, sway])
            let sequence = SCNAction.sequence([SCNAction.wait(duration: delay), group, SCNAction.removeFromParentNode()])
            balloon.runAction(sequence)
        }
    }

    private func createBalloonNode(color: UIColor) -> SCNNode {
        let node = SCNNode()
        
        let sphere = SCNSphere(radius: 1.0)
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .physicallyBased
        material.roughness.contents = 0.2
        material.metalness.contents = 0.1
        material.clearCoat.contents = 1.0
        material.clearCoatRoughness.contents = 0.1
        sphere.materials = [material]
        
        let bodyNode = SCNNode(geometry: sphere)
        bodyNode.scale = SCNVector3(1, 1.25, 1)
        node.addChildNode(bodyNode)
        
        let cone = SCNCone(topRadius: 0.05, bottomRadius: 0.15, height: 0.25)
        cone.materials = [material]
        let knotNode = SCNNode(geometry: cone)
        knotNode.position = SCNVector3(0, -1.3, 0)
        node.addChildNode(knotNode)
        
        let randomScale = Float.random(in: 0.6...1.2)
        node.scale = SCNVector3(randomScale, randomScale, randomScale)
        
        return node
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