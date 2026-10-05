import AVFAudio
import Foundation

/// A short, reusable PCM click. It uses the ambient category and respects silent mode.
@MainActor
final class ScheduleNumberClickFeedback {
    private var player: AVAudioPlayer?

    @discardableResult
    func prepare() -> Bool {
        guard player == nil else { return true }
        let sampleRate = 22_050
        let count = 441
        var samples = Data()
        for index in 0 ..< count {
            let phase = Double(index) / Double(sampleRate)
            let envelope = pow(1 - Double(index) / Double(count), 3)
            let wave = sin(2 * .pi * 1_400 * phase) * envelope * 0.18
            append(UInt16(bitPattern: Int16(wave * Double(Int16.max))), to: &samples)
        }
        var data = Data("RIFF".utf8)
        append(UInt32(36 + samples.count), to: &data)
        data.append(Data("WAVEfmt ".utf8))
        append(UInt32(16), to: &data)
        append(UInt16(1), to: &data)
        append(UInt16(1), to: &data)
        append(UInt32(sampleRate), to: &data)
        append(UInt32(sampleRate * 2), to: &data)
        append(UInt16(2), to: &data)
        append(UInt16(16), to: &data)
        data.append(Data("data".utf8))
        append(UInt32(samples.count), to: &data)
        data.append(samples)
        player = try? AVAudioPlayer(data: data)
        player?.prepareToPlay()
        return player != nil
    }

    func play() {
        guard let player else { return }
        player.currentTime = 0
        player.play()
    }

    func stop() {
        player?.stop()
    }

    private func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}
