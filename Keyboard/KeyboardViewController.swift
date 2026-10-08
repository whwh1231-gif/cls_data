import UIKit

/// 타닥 키보드 본체. 키를 누르면 [소리 → 진동 → 글자 입력] 순서로 처리한다.
final class KeyboardViewController: UIInputViewController {
    private let board = KeyboardView()
    private let switchButton = UIButton(type: .system)
    private let dampButton = UIButton(type: .system)
    private let notice = UILabel()
    private var heightConstraint: NSLayoutConstraint?

    private var composer = HangulComposer()
    private var korean = true
    private var page = Page.letters
    private var shift = ShiftState.off
    private var lastShiftTap = Date.distantPast
    private var repeatTimer: Timer?
    private var repeatTicks = 0

    // MARK: - 화면 구성

    override func viewDidLoad() {
        super.viewDidLoad()

        let bar = UIStackView(arrangedSubviews: [switchButton, notice, dampButton])
        bar.axis = .horizontal
        bar.spacing = 8
        bar.alignment = .center
        notice.font = .systemFont(ofSize: 11)
        notice.textColor = .secondaryLabel
        notice.textAlignment = .center
        notice.numberOfLines = 2
        notice.adjustsFontSizeToFitWidth = true
        notice.minimumScaleFactor = 0.7
        notice.setContentHuggingPriority(.defaultLow, for: .horizontal)
        notice.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        switchButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        dampButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        switchButton.addTarget(self, action: #selector(nextSwitch), for: .touchUpInside)
        dampButton.addTarget(self, action: #selector(toggleDamp), for: .touchUpInside)

        for sub in [bar, board] as [UIView] {
            sub.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(sub)
        }
        let height = view.heightAnchor.constraint(equalToConstant: 258)
        height.priority = UILayoutPriority(999)
        heightConstraint = height
        NSLayoutConstraint.activate([
            height,
            bar.topAnchor.constraint(equalTo: view.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            bar.heightAnchor.constraint(equalToConstant: 38),
            board.topAnchor.constraint(equalTo: bar.bottomAnchor),
            board.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            board.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            board.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
        ])

        board.onCreate = { [weak self] control in
            // 지구본 키: 길게 누르면 키보드 목록이 뜨는 시스템 기본 동작을 연결
            guard let self = self, control.key.action == .globe else { return }
            control.addTarget(self, action: #selector(self.handleInputModeList(from:with:)), for: .allTouchEvents)
        }
        board.onDown = { [weak self] in self?.keyDown($0) }
        board.onUp = { [weak self] control, inside in self?.keyUp(control, inside: inside) }
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        composer.reset()
        SoundEngine.shared.prepare()
        HapticEngine.shared.prepare()
        refreshBar()
        reload()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 화면 가장자리 키(ㅂ, ㅁ, ㅔ 등)가 늦게 눌리는 iOS 제스처 지연 해제
        view.window?.gestureRecognizers?.forEach { $0.delaysTouchesBegan = false }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopRepeat()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // ponytail: 폭으로 가로 모드를 추정. 아이패드 지원 시 사이즈 클래스 기준으로 교체.
        let target: CGFloat = view.bounds.width > 600 ? 206 : 258
        if heightConstraint?.constant != target { heightConstraint?.constant = target }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // 사용자가 커서를 옮겼다면 조합 중이던 글자를 놓아준다
        guard !composer.isEmpty, let before = textDocumentProxy.documentContextBeforeInput else { return }
        if !before.hasSuffix(composer.composing) { composer.reset() }
    }

    private func reload() {
        board.setRows(Layouts.rows(page: page, korean: korean, shift: shift, needsGlobe: needsInputModeSwitchKey))
    }

    // MARK: - 상단 바 (축 바꾸기 · 흡음재)

    private func refreshBar() {
        let current = Prefs.switchType
        let title = NSMutableAttributedString(string: "● ", attributes: [.foregroundColor: current.color])
        title.append(NSAttributedString(string: current.name, attributes: [.foregroundColor: UIColor.label]))
        switchButton.setAttributedTitle(title, for: .normal)
        dampButton.setTitle(Prefs.dampened ? "흡음재 켬" : "흡음재 끔", for: .normal)
        dampButton.tintColor = Prefs.dampened ? .systemBlue : .secondaryLabel
        if !hasFullAccess {
            notice.text = "설정에서 '전체 접근 허용'을 켜면\n소리와 진동이 나와요"
        } else if current == .custom, !CustomSound.exists {
            notice.text = "타닥 앱에서 먼저\n내 소리를 녹음해 주세요"
        } else {
            notice.text = ""
        }
    }

    @objc private func nextSwitch() {
        let all = SwitchType.allCases.filter { $0 != .custom || CustomSound.exists }   // 녹음이 없으면 내 소리는 건너뜀
        let index = all.firstIndex(of: Prefs.switchType) ?? 0
        Prefs.switchType = all[(index + 1) % all.count]
        refreshBar()
        feedback(.down)
    }

    @objc private func toggleDamp() {
        Prefs.dampened.toggle()
        refreshBar()
        feedback(.down)
    }

    private func feedback(_ kind: SoundEngine.Kind) {
        SoundEngine.shared.play(kind)
        HapticEngine.shared.down()
    }

    // MARK: - 키 입력

    private func keyDown(_ control: KeyControl) {
        let action = control.key.action
        feedback(action == .space || action == .enter ? .space : .down)

        switch action {
        case .jamo(let jamo):
            let old = composer.composing
            let done = composer.input(jamo)
            replace(old, with: done + composer.composing)
            releaseShift()
        case .text(let text):
            composer.reset()
            textDocumentProxy.insertText(text)
            releaseShift()
        case .space:
            composer.reset()
            textDocumentProxy.insertText(" ")
        case .enter:
            composer.reset()
            textDocumentProxy.insertText("\n")
        case .backspace:
            backspace()
            startRepeat()
        case .shift:
            let now = Date()
            if !korean, shift == .on, now.timeIntervalSince(lastShiftTap) < 0.35 {
                shift = .locked            // 영문에서 빠르게 두 번 = 대문자 고정
            } else {
                shift = shift == .off ? .on : .off
            }
            lastShiftTap = now
            reload()
        case .lang:
            composer.reset()
            korean.toggle()
            page = .letters
            shift = .off
            reload()
        case .page, .globe:
            break                          // 손을 뗄 때 처리 (keyUp)
        }
    }

    private func keyUp(_ control: KeyControl, inside: Bool) {
        stopRepeat()
        if Prefs.keyUpSound {
            let action = control.key.action
            SoundEngine.shared.play(action == .space || action == .enter ? .spaceUp : .up)
        }
        HapticEngine.shared.up()
        if inside, case .page(let target) = control.key.action {
            composer.reset()
            page = target
            shift = .off
            reload()
        }
    }

    /// 조합 중이던 글자(old)를 새 내용으로 바꿔 쓴다.
    private func replace(_ old: String, with new: String) {
        if new.hasPrefix(old) {            // 앞부분이 같으면 뒤만 덧붙인다 (깜빡임 방지)
            let rest = String(new.dropFirst(old.count))
            if !rest.isEmpty { textDocumentProxy.insertText(rest) }
            return
        }
        for _ in old { textDocumentProxy.deleteBackward() }
        if !new.isEmpty { textDocumentProxy.insertText(new) }
    }

    private func backspace() {
        if composer.isEmpty {
            textDocumentProxy.deleteBackward()
        } else {
            let old = composer.composing
            composer.backspace()
            replace(old, with: composer.composing)
        }
    }

    private func releaseShift() {
        if shift == .on {
            shift = .off
            reload()
        }
    }

    // MARK: - 지우기 키 길게 누르기

    private func startRepeat() {
        stopRepeat()
        repeatTicks = 0
        let timer = Timer(timeInterval: 0.08, target: self, selector: #selector(repeatTick),
                          userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        repeatTimer = timer
    }

    @objc private func repeatTick() {
        repeatTicks += 1
        guard repeatTicks > 5 else { return }   // 0.4초쯤 누르고 있으면 연속 삭제 시작
        backspace()
        SoundEngine.shared.play(.down)
    }

    private func stopRepeat() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}
