import SwiftUI
import UniformTypeIdentifiers

/// 앱 본체 화면: 스위치 선택 · 미리 쳐보기 · 소리/진동 설정 · 키보드 추가 안내
struct ContentView: View {
    @AppStorage(Prefs.Key.switchType, store: Prefs.store) private var switchRaw = SwitchType.brown.rawValue
    @AppStorage(Prefs.Key.dampened, store: Prefs.store) private var dampened = false
    @AppStorage(Prefs.Key.soundOn, store: Prefs.store) private var soundOn = true
    @AppStorage(Prefs.Key.volume, store: Prefs.store) private var volume = 0.8
    @AppStorage(Prefs.Key.hapticOn, store: Prefs.store) private var hapticOn = true
    @AppStorage(Prefs.Key.hapticStrength, store: Prefs.store) private var hapticStrength = 1.0
    @AppStorage(Prefs.Key.keyUpSound, store: Prefs.store) private var keyUpSound = true
    @AppStorage(Prefs.Key.playInSilentMode, store: Prefs.store) private var playInSilentMode = false
    @State private var testText = ""
    @StateObject private var voice = VoiceRecorder()
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    ForEach(SwitchType.allCases) { item in
                        switchCard(item)
                    }
                    voiceCard
                    tryCard
                    settingsCard
                    guideCard
                    licenseCard
                }
                .padding(16)
            }
            .background(Color.black)
            .navigationTitle("타닥")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { SoundEngine.shared.prepare() }
        .onChange(of: playInSilentMode) { _ in SoundEngine.shared.prepare() }
        .onChange(of: dampened) { _ in preview() }
    }

    // MARK: - 조각들

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("기계식 스위치 선택").font(.title2.bold())
                Text("스위치를 눌러 타건음을 들어보세요.").font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            Toggle("흡음재", isOn: $dampened).fixedSize()
        }
        .padding(.bottom, 4)
    }

    private func switchCard(_ item: SwitchType) -> some View {
        let selected = item.rawValue == switchRaw
        let locked = item == .custom && !voice.hasSound      // 녹음 전에는 고를 수 없음
        return Button {
            guard !locked else { return }
            switchRaw = item.rawValue
            preview()
        } label: {
            HStack(spacing: 14) {
                Keycap(color: Color(uiColor: item.color))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name).font(.headline).foregroundColor(.white)
                    Text(locked ? "아래에서 먼저 녹음해 주세요" : item.summary)
                        .font(.footnote).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").font(.title3).foregroundColor(.blue)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color(white: selected ? 0.06 : 0.12)))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.blue, lineWidth: selected ? 2 : 0))
        }
        .buttonStyle(.plain)
        .opacity(locked ? 0.55 : 1)
    }

    private var voiceCard: some View {
        card("내 소리 녹음") {
            Text("'냐옹'처럼 짧게 녹음하거나, 이미 있는 소리 파일을 가져오면 키를 누를 때마다 그 소리가 나요. 빠르게 치면 앞 소리를 끊고 새로 재생합니다.")
                .font(.footnote).foregroundColor(.secondary)
            HStack(spacing: 10) {
                Button(voice.isRecording ? "녹음 끝내기" : (voice.hasSound ? "다시 녹음" : "녹음 시작")) {
                    voice.toggle()
                }
                .buttonStyle(.borderedProminent)
                .tint(voice.isRecording ? .red : .blue)
                Button("파일에서 가져오기") { showFilePicker = true }
                    .buttonStyle(.bordered)
                    .disabled(voice.isRecording)
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.audio]) { result in
                if case .success(let url) = result { voice.importFile(url) }
            }
            Text("음성 메모는 공유 → '파일에 저장'으로 옮겨 두면 고를 수 있어요. 긴 파일은 소리가 시작되는 곳부터 2초만 씁니다.")
                .font(.caption).foregroundColor(.secondary)
            if voice.hasSound && !voice.isRecording {
                HStack(spacing: 10) {
                    Button("들어보기") {
                        switchRaw = SwitchType.custom.rawValue
                        preview()
                    }
                    .buttonStyle(.bordered)
                    Button("삭제", role: .destructive) {
                        voice.delete()
                        if switchRaw == SwitchType.custom.rawValue { switchRaw = SwitchType.brown.rawValue }
                    }
                    .buttonStyle(.bordered)
                }
            }
            if !voice.message.isEmpty {
                Text(voice.message).font(.footnote)
            }
            if CustomSound.sharedFolder == nil {
                Text("지금 설치 방식에서는 앱과 키보드가 파일을 함께 쓰지 못해, 키보드에서는 내 소리가 나지 않아요. (정식 서명으로 설치하면 해결)")
                    .font(.footnote).foregroundColor(.orange)
            }
        }
    }

    private var tryCard: some View {
        card("여기에 쳐보세요") {
            TextField("키보드를 타닥으로 바꾸고 입력해 보세요", text: $testText, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    private var settingsCard: some View {
        card("소리와 진동") {
            Toggle("타건음", isOn: $soundOn)
            HStack {
                Image(systemName: "speaker.fill").foregroundColor(.secondary)
                Slider(value: $volume, in: 0.1...1)
                Image(systemName: "speaker.wave.3.fill").foregroundColor(.secondary)
            }
            Toggle("키에서 손 뗄 때도 소리", isOn: $keyUpSound)
            Toggle("무음 모드에서도 재생", isOn: $playInSilentMode)
            Divider()
            Toggle("터치 진동(햅틱)", isOn: $hapticOn)
            HStack {
                Text("약").foregroundColor(.secondary)
                Slider(value: $hapticStrength, in: 0.3...1)
                Text("강").foregroundColor(.secondary)
            }
        }
    }

    private var guideCard: some View {
        card("키보드 추가 방법") {
            Text("1. 설정 → 일반 → 키보드 → 키보드 → 새로운 키보드 추가")
            Text("2. 목록에서 '타닥' 선택")
            Text("3. 타닥을 다시 눌러 '전체 접근 허용' 켜기")
            Text("소리와 진동은 '전체 접근 허용'이 켜져 있어야 작동합니다. 입력한 내용은 어디에도 전송하지 않습니다.")
                .font(.footnote).foregroundColor(.secondary)
            Button("설정 열기") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var licenseCard: some View {
        card("오픈소스 고지") {
            DisclosureGroup("타건음 출처와 라이선스") {
                Text(licenseNotice).font(.caption2).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(white: 0.12)))
    }

    /// 지금 설정대로 한 번 '눌렀다 떼는' 소리와 진동을 들려준다
    private func preview() {
        SoundEngine.shared.play(.down)
        HapticEngine.shared.down()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            SoundEngine.shared.play(.up)
            HapticEngine.shared.up()
        }
    }
}

/// 스위치 색을 보여주는 작은 키캡 그림
struct Keycap: View {
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13).fill(Color(white: 0.93))
            RoundedRectangle(cornerRadius: 8).fill(color).brightness(-0.12).frame(width: 36, height: 34).offset(y: 3)
            RoundedRectangle(cornerRadius: 6).fill(color).frame(width: 27, height: 24).offset(y: -1)
        }
        .frame(width: 54, height: 54)
    }
}

/// 타건음 녹음의 출처 고지 (MIT 라이선스는 앱 안에 저작권·허가 문구를 싣도록 요구한다)
private let licenseNotice = """
타건음은 아래 오픈소스 프로젝트에 포함된 실제 스위치 녹음을 잘라 음량을 맞춘 것입니다.

Mechvibes - Copyright (c) 2021 Hai Nguyen
kbsim - Copyright (c) Thomas Lai

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""
