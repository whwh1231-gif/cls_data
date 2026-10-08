import AVFoundation
import SwiftUI

/// "내 소리" 녹음기. 녹음 → 다듬어 저장(CustomSound) → 바로 한 번 들려주기까지 맡는다.
final class VoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var hasSound = CustomSound.exists
    @Published var message = ""

    private var recorder: AVAudioRecorder?
    private let temp = FileManager.default.temporaryDirectory.appendingPathComponent("tadak-recording.wav")

    func toggle() {
        if isRecording {
            recorder?.stop()   // 끝나면 아래 audioRecorderDidFinishRecording 이 불린다
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted { self.start() } else { self.message = "설정 > 타닥에서 마이크를 허용해 주세요." }
                }
            }
        }
    }

    /// 파일 앱에서 고른 소리 파일을 내 소리로 쓴다
    func importFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()   // 다른 앱의 파일을 읽으려면 필요한 절차
        store(url, fromMic: false)
        if scoped { url.stopAccessingSecurityScopedResource() }
    }

    func delete() {
        CustomSound.delete()
        hasSound = false
        message = "내 소리를 지웠어요."
    }

    private func start() {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: CustomSound.sampleRate, AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
        ]
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let made = try AVAudioRecorder(url: temp, settings: settings)
            made.delegate = self
            guard made.record(forDuration: CustomSound.maxSeconds) else { throw CustomSound.Failure.unreadable }
            recorder = made
            isRecording = true
            message = "녹음 중이에요. 다 말했으면 다시 눌러 주세요. (최대 2초)"
        } catch {
            message = "녹음을 시작하지 못했어요."
            SoundEngine.shared.prepare()
        }
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.recorder = nil
            self.isRecording = false
            self.store(self.temp, fromMic: true)
        }
    }

    /// 다듬어 저장하고, 성공하면 내 소리를 선택한 뒤 한 번 들려준다
    private func store(_ source: URL, fromMic: Bool) {
        var saved = false
        do {
            try CustomSound.save(from: source, fromMic: fromMic)
            saved = true
            hasSound = true
            Prefs.switchType = .custom
            message = "저장했어요. 이제 키를 누를 때마다 이 소리가 나요."
        } catch CustomSound.Failure.tooQuiet {
            message = "소리가 너무 작아요. 더 큰 소리로 다시 해 주세요."
        } catch {
            message = fromMic ? "저장하지 못했어요. 다시 시도해 주세요." : "이 파일은 읽을 수 없어요. m4a, mp3, wav 파일로 해 주세요."
        }
        SoundEngine.shared.prepare()            // 녹음용으로 바꿨던 오디오 설정을 재생용으로 되돌림
        if saved { SoundEngine.shared.play(.down) }
    }
}
