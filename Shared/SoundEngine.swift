import AVFoundation

/// 타건음 재생기. 소리를 미리 메모리에 올려 두고 누르는 즉시 재생한다.
final class SoundEngine {
    static let shared = SoundEngine()
    /// rawValue 가 곧 소리 파일 이름의 끝부분 (예: red_o_down3.wav, red_o_spaceup.wav)
    enum Kind: String { case down, up, space, spaceUp = "spaceup" }

    private let engine = AVAudioEngine()
    private let players = (0..<6).map { _ in AVAudioPlayerNode() }   // 빠르게 칠 때 소리가 겹치도록 6개
    private var next = 0
    private var buffers: [String: [AVAudioPCMBuffer]] = [:]
    private var loaded = ""

    private init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
        for player in players {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
    }

    /// 키보드가 뜰 때 / 설정이 바뀔 때 호출
    func prepare() {
        let session = AVAudioSession.sharedInstance()
        if Prefs.playInSilentMode {
            try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])   // 무음 모드에서도, 음악과 섞여서
        } else {
            try? session.setCategory(.ambient, mode: .default, options: [])                              // 무음 스위치를 따름
        }
        try? session.setPreferredIOBufferDuration(0.005)
        try? session.setActive(true)
        load()
        if !engine.isRunning { try? engine.start() }
    }

    func play(_ kind: Kind) {
        guard Prefs.soundOn else { return }
        load()
        // 같은 종류의 녹음이 여러 개면 매번 무작위로 골라 기계적인 반복감을 줄인다
        guard let buffer = buffers[kind.rawValue]?.randomElement() else { return }
        if !engine.isRunning { try? engine.start() }
        guard engine.isRunning else { return }
        // 내 소리는 길어서 겹치면 시끄럽다 → 항상 같은 재생기를 써서 앞 소리를 끊고 새로 재생.
        // ponytail: 끊는 순간 '틱' 소리가 거슬리면 재생기 2개를 번갈아 쓰며 짧게 페이드아웃하도록 교체.
        let cutsPrevious = Prefs.switchType == .custom
        let player = cutsPrevious ? players[0] : players[next]
        if !cutsPrevious { next = (next + 1) % players.count }
        player.volume = Float(Prefs.volume)
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    /// 지금 선택된 축 + 흡음재 조합의 소리를 읽어 둔다. 이미 읽었으면 아무것도 안 함.
    /// down1, down2 ... 처럼 번호가 붙은 파일은 있는 만큼 전부 읽고, 번호가 없으면 그 파일 하나만 읽는다.
    private func load() {
        let type = Prefs.switchType
        let key = type == .custom
            ? "custom_\(Prefs.customVersion)"
            : type.rawValue + (Prefs.dampened ? "_d" : "_o")
        guard key != loaded else { return }
        var fresh: [String: [AVAudioPCMBuffer]] = [:]
        if type == .custom {
            // 내 소리: 누를 때만 재생 (뗄 때 소리 없음), 스페이스도 같은 소리
            if let buffer = read(CustomSound.url) { fresh = ["down": [buffer], "space": [buffer]] }
        } else {
            for name in ["down", "up", "space", "spaceup"] {
                var list: [AVAudioPCMBuffer] = []
                while let buffer = read(bundled("\(key)_\(name)\(list.count + 1)")) { list.append(buffer) }
                if list.isEmpty, let buffer = read(bundled("\(key)_\(name)")) { list.append(buffer) }
                fresh[name] = list
            }
        }
        buffers = fresh
        loaded = key
    }

    private func bundled(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "wav")
    }

    private func read(_ url: URL?) -> AVAudioPCMBuffer? {
        guard let url = url,
              let file = try? AVAudioFile(forReading: url),
              file.processingFormat.channelCount == 1, file.processingFormat.sampleRate == 44100,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil else { return nil }
        return buffer
    }
}
