import SwiftUI

struct DormitoryScratchRevealField: View {
    let title: String
    let value: String
    let isEnabled: Bool
    let lockedHint: String
    @Binding var isRevealed: Bool

    @State private var strokes: [[CGPoint]] = []
    @State private var activeStrokeIndex: Int?
    @State private var coveredCells: Set<Int> = []
    @State private var particles: [DormitoryScratchParticle] = []
    @State private var scratchPulse = 0

    private let brushWidth = 34.0
    private let coverageCellSize = 11.0
    private let revealCoverage = 0.54

    var body: some View {
        ZStack {
            revealedContent

            if !isRevealed {
                scratchSurface

                if !isEnabled {
                    lockedSurface
                }
            }
        }
        .frame(height: 112)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(.white.opacity(0.17), lineWidth: 1)
        }
        .sensoryFeedback(.selection, trigger: scratchPulse)
        .sensoryFeedback(.impact(weight: .medium), trigger: isRevealed)
        .animation(.snappy(duration: 0.28), value: isEnabled)
        .animation(.snappy(duration: 0.28), value: isRevealed)
        .accessibilityElement(children: .contain)
    }

    private var revealedContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.66))

            Text(verbatim: value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .foregroundStyle(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.white.opacity(0.13))
        .accessibilityHidden(!isRevealed)
    }

    private var lockedSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color(uiColor: .systemGray3))

            Label(lockedHint, systemImage: "lock.fill")
                .font(.caption.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.black.opacity(0.62))
                .padding(.horizontal, 20)
        }
    }

    private var scratchSurface: some View {
        GeometryReader { proxy in
            scratchLayer
                .compositingGroup()
                .overlay {
                    DormitoryScratchDustView(particles: particles)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            appendScratchPoint(drag.location, in: proxy.size)
                        }
                        .onEnded { _ in
                            activeStrokeIndex = nil
                        },
                    including: isEnabled ? .all : .none
                )
                .accessibilityLabel(
                    isEnabled ? dormitoryLocalized("dormitory_reveal_scratch") : lockedHint
                )
                .accessibilityAddTraits(isEnabled ? .isButton : [])
                .accessibilityAction {
                    guard isEnabled else { return }
                    revealField()
                }
        }
    }

    private var scratchLayer: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(uiColor: .systemGray3),
                            Color(uiColor: .systemGray5),
                            Color(uiColor: .systemGray2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack(spacing: 8) {
                Image(systemName: "hand.draw.fill")
                Text(dormitoryLocalized("dormitory_reveal_scratch"))
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.black.opacity(0.62))

            Canvas { context, _ in
                context.blendMode = .destinationOut
                for stroke in strokes where !stroke.isEmpty {
                    if stroke.count == 1, let point = stroke.first {
                        let radius = brushWidth / 2
                        let rect = CGRect(
                            x: point.x - radius,
                            y: point.y - radius,
                            width: brushWidth,
                            height: brushWidth
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(.white))
                        continue
                    }

                    var path = Path()
                    path.move(to: stroke[0])
                    for point in stroke.dropFirst() {
                        path.addLine(to: point)
                    }
                    context.stroke(
                        path,
                        with: .color(.white),
                        style: StrokeStyle(
                            lineWidth: brushWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
            }
        }
    }

    private func appendScratchPoint(_ rawPoint: CGPoint, in size: CGSize) {
        guard isEnabled, !isRevealed, size.width > 0, size.height > 0 else { return }

        let point = CGPoint(
            x: min(max(rawPoint.x, 0), size.width),
            y: min(max(rawPoint.y, 0), size.height)
        )
        let previousPoint: CGPoint?

        if let activeStrokeIndex, let previous = strokes[activeStrokeIndex].last {
            let segment = hypot(point.x - previous.x, point.y - previous.y)
            guard segment >= 1.5 else { return }
            strokes[activeStrokeIndex].append(point)
            previousPoint = previous
        } else {
            strokes.append([point])
            activeStrokeIndex = strokes.indices.last
            previousPoint = nil
        }

        let oldCoverageCount = coveredCells.count
        markCoverage(from: previousPoint ?? point, to: point, in: size)
        emitParticles(at: point, movingFrom: previousPoint)
        provideScratchFeedback(previousCount: oldCoverageCount)

        let columns = max(1, Int(ceil(size.width / coverageCellSize)))
        let rows = max(1, Int(ceil(size.height / coverageCellSize)))
        let coverage = Double(coveredCells.count) / Double(columns * rows)
        if coverage >= revealCoverage {
            revealField()
        }
    }

    private func markCoverage(from start: CGPoint, to end: CGPoint, in size: CGSize) {
        let columns = max(1, Int(ceil(size.width / coverageCellSize)))
        let rows = max(1, Int(ceil(size.height / coverageCellSize)))
        let distance = hypot(end.x - start.x, end.y - start.y)
        let sampleCount = max(1, Int(ceil(distance / (coverageCellSize * 0.45))))
        let brushRadius = brushWidth / 2

        for sample in 0...sampleCount {
            let progress = CGFloat(sample) / CGFloat(sampleCount)
            let point = CGPoint(
                x: start.x + (end.x - start.x) * progress,
                y: start.y + (end.y - start.y) * progress
            )
            let minColumn = max(0, Int(floor((point.x - brushRadius) / coverageCellSize)))
            let maxColumn = min(columns - 1, Int(floor((point.x + brushRadius) / coverageCellSize)))
            let minRow = max(0, Int(floor((point.y - brushRadius) / coverageCellSize)))
            let maxRow = min(rows - 1, Int(floor((point.y + brushRadius) / coverageCellSize)))

            for row in minRow...maxRow {
                for column in minColumn...maxColumn {
                    let cellCenter = CGPoint(
                        x: (CGFloat(column) + 0.5) * coverageCellSize,
                        y: (CGFloat(row) + 0.5) * coverageCellSize
                    )
                    let distanceToPoint = hypot(cellCenter.x - point.x, cellCenter.y - point.y)
                    if distanceToPoint <= brushRadius + coverageCellSize * 0.55 {
                        coveredCells.insert(row * columns + column)
                    }
                }
            }
        }
    }

    private func emitParticles(at point: CGPoint, movingFrom previousPoint: CGPoint?) {
        let direction = CGVector(
            dx: point.x - (previousPoint?.x ?? point.x - 1),
            dy: point.y - (previousPoint?.y ?? point.y)
        )
        let length = max(1, hypot(direction.dx, direction.dy))
        let normal = CGVector(dx: -direction.dy / length, dy: direction.dx / length)
        let now = Date()

        let newParticles = (0..<3).map { index in
            let side = index.isMultiple(of: 2) ? 1.0 : -1.0
            let spread = CGFloat.random(in: 18...42) * side
            return DormitoryScratchParticle(
                origin: point,
                velocity: CGVector(
                    dx: normal.dx * spread + CGFloat.random(in: -14...14),
                    dy: normal.dy * spread + CGFloat.random(in: -28 ... -8)
                ),
                createdAt: now,
                lifetime: Double.random(in: 0.42...0.72),
                size: CGFloat.random(in: 2.5...6.5),
                shade: index
            )
        }

        particles = Array((particles + newParticles).suffix(64))
    }

    private func provideScratchFeedback(previousCount: Int) {
        guard coveredCells.count / 7 > previousCount / 7 else { return }
        scratchPulse += 1
    }

    private func revealField() {
        guard !isRevealed else { return }
        withAnimation(.snappy(duration: 0.24)) {
            isRevealed = true
        }
    }
}

struct DormitoryScratchParticle: Identifiable {
    let id = UUID()
    let origin: CGPoint
    let velocity: CGVector
    let createdAt: Date
    let lifetime: Double
    let size: CGFloat
    let shade: Int
}

private struct DormitoryScratchDustView: View {
    let particles: [DormitoryScratchParticle]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: particles.isEmpty)) { timeline in
            Canvas { context, _ in
                for particle in particles {
                    draw(particle, at: timeline.date, in: &context)
                }
            }
        }
    }

    private func draw(
        _ particle: DormitoryScratchParticle,
        at date: Date,
        in context: inout GraphicsContext
    ) {
        let age = date.timeIntervalSince(particle.createdAt)
        guard age >= 0, age < particle.lifetime else { return }

        let progress = age / particle.lifetime
        let time = CGFloat(age)
        let position = CGPoint(
            x: particle.origin.x + particle.velocity.dx * time,
            y: particle.origin.y + particle.velocity.dy * time + 70 * time * time
        )
        let rect = CGRect(
            x: position.x - particle.size / 2,
            y: position.y - particle.size / 2,
            width: particle.size * 1.5,
            height: particle.size
        )
        let shades: [Color] = [
            Color(uiColor: .systemGray2),
            Color(uiColor: .systemGray4),
            Color(uiColor: .systemGray5)
        ]

        context.opacity = 1 - progress
        context.fill(
            Path(roundedRect: rect, cornerRadius: particle.size / 3),
            with: .color(shades[particle.shade % shades.count])
        )
    }
}
