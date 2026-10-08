import AVFoundation

/// "내 소리" - 사용자가 직접 녹음한 키보드 소리.
/// 녹음은 앱에서만 할 수 있고(아이폰은 키보드에 마이크를 허용하지 않음),
/// 다듬은 파일을 공유 폴더에 두면 키보드가 읽어서 재생한다.
enum CustomSound {
    static let maxSeconds: TimeInterval = 2
    static let sampleRate: Double = 44100

    enum Failure: Error { case tooQuiet, unreadable }

    /// 앱과 키보드가 함께 보는 공유 폴더. 앱 그룹이 막힌 설치 방식에서는 nil.
    static var sharedFolder: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Prefs.groupID)
    }

    /// 공유 폴더가 없으면 앱 자기 폴더에 저장한다. (앱 안 미리듣기는 되지만 키보드에서는 못 읽음)
    static var url: URL? {
        let folder = sharedFolder ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return folder?.appendingPathComponent("custom.wav")
    }

    static var exists: Bool {
        guard let url = url else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// 녹음 원본(fromMic: true) 또는 가져온 소리 파일(m4a, mp3, wav 등)을 다듬어 저장한다.
    static func save(from source: URL, fromMic: Bool) throws {
        let file = try AVAudioFile(forReading: source)
        let format = file.processingFormat
        // 노래처럼 긴 파일을 골라도 메모리가 터지지 않게 앞 30초만 읽는다 (어차피 2초만 씀)
        let frames = min(file.length, Int64(30 * format.sampleRate))
        guard frames > 0,
              let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)) else {
            throw Failure.unreadable
        }
        try file.read(into: input)
        guard let channel = input.floatChannelData?[0] else { throw Failure.unreadable }
        var samples = Array(UnsafeBufferPointer(start: channel, count: Int(input.frameLength)))
        samples = resampled(samples, from: format.sampleRate, to: sampleRate)   // 음성 메모(48kHz) 등 → 44.1kHz
        guard let cut = trimmed(samples, sampleRate: sampleRate, fromMic: fromMic) else { throw Failure.tooQuiet }

        guard let url = url,
              let mono = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let output = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: AVAudioFrameCount(cut.count)),
              let target = output.floatChannelData?[0] else { throw Failure.unreadable }
        for (index, value) in cut.enumerated() { target[index] = value }
        output.frameLength = AVAudioFrameCount(cut.count)

        try? FileManager.default.removeItem(at: url)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: sampleRate, AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
        ]
        do {   // 블록이 끝나면 파일이 닫혀서 키보드가 바로 읽을 수 있다
            let out = try AVAudioFile(forWriting: url, settings: settings)
            try out.write(from: output)
        }
        Prefs.customVersion += 1   // 키보드에게 "새 녹음이니 다시 읽어라" 신호
    }

    static func delete() {
        if let url = url { try? FileManager.default.removeItem(at: url) }
        Prefs.customVersion += 1
    }

    /// 샘플레이트 변환. 이걸 안 하면 48kHz 파일이 느리고 낮은 소리로 재생된다.
    /// ponytail: 직선 보간. 목소리·효과음에는 충분하고, 음악급 품질이 필요해지면 AVAudioConverter 로 교체.
    static func resampled(_ samples: [Float], from: Double, to: Double) -> [Float] {
        guard from != to, from > 0, samples.count > 1 else { return samples }
        let count = Int(Double(samples.count) * to / from)
        return (0..<count).map { i in
            let position = Double(i) * from / to
            let index = min(Int(position), samples.count - 2)
            let fraction = Float(position - Double(index))
            return samples[index] * (1 - fraction) + samples[index + 1] * fraction
        }
    }

    /// 앞뒤 무음을 잘라 누르자마자 소리가 나게 하고, 음량을 맞춘다. 소리가 거의 없으면 nil.
    static func trimmed(_ input: [Float], sampleRate: Double, fromMic: Bool) -> [Float]? {
        var samples = input
        // 녹음 버튼을 누르는 '톡' 소리가 섞이는 맨 앞·맨 뒤 0.1초는 버린다
        let edge = Int(0.1 * sampleRate)
        if fromMic, samples.count > edge * 4 { samples = Array(samples[edge..<(samples.count - edge)]) }

        let peak = samples.reduce(Float(0)) { max($0, abs($1)) }
        guard peak > 0.02,
              let first = samples.firstIndex(where: { abs($0) > peak * 0.05 }),
              let last = samples.lastIndex(where: { abs($0) > peak * 0.03 }) else { return nil }
        let start = max(0, first - Int(0.004 * sampleRate))
        let end = min(samples.count, last + Int(0.04 * sampleRate), start + Int(maxSeconds * sampleRate))
        var out = samples[start..<end].map { $0 * 0.9 / peak }

        let fadeIn = min(out.count, Int(0.003 * sampleRate))     // 시작이 '틱' 하고 튀지 않게
        for i in 0..<fadeIn { out[i] *= Float(i) / Float(fadeIn) }
        let fadeOut = min(out.count, Int(0.02 * sampleRate))     // 끝이 뚝 끊기지 않게
        for i in 0..<fadeOut { out[out.count - 1 - i] *= Float(i) / Float(fadeOut) }
        return out
    }
}
