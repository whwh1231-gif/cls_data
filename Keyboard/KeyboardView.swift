import UIKit

/// 키 1개. 터치 영역은 칸 전체(틈 없음)이고, 눈에 보이는 키캡은 그 안쪽에 그린다.
final class KeyControl: UIControl {
    var key: Key { didSet { render() } }
    private let cap = UIView()
    private let label = UILabel()
    private let icon = UIImageView()

    private static let letterColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.42, alpha: 1) : .white }
    private static let functionColor = UIColor {
        $0.userInterfaceStyle == .dark ? UIColor(white: 0.27, alpha: 1) : UIColor(red: 0.67, green: 0.70, blue: 0.74, alpha: 1)
    }

    init(key: Key) {
        self.key = key
        super.init(frame: .zero)
        cap.isUserInteractionEnabled = false
        cap.layer.cornerRadius = 5
        cap.layer.shadowColor = UIColor.black.cgColor
        cap.layer.shadowOpacity = 0.3
        cap.layer.shadowRadius = 0
        cap.layer.shadowOffset = CGSize(width: 0, height: 1)
        addSubview(cap)
        label.textAlignment = .center
        label.textColor = .label
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        cap.addSubview(label)
        icon.contentMode = .center
        icon.tintColor = .label
        cap.addSubview(icon)
        render()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isHighlighted: Bool { didSet { paint() } }

    override func layoutSubviews() {
        super.layoutSubviews()
        cap.frame = bounds.insetBy(dx: 3, dy: 5)
        label.frame = cap.bounds.insetBy(dx: 2, dy: 0)
        icon.frame = cap.bounds
    }

    private func render() {
        if key.label.hasPrefix("sf:") {
            let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
            icon.image = UIImage(systemName: String(key.label.dropFirst(3)), withConfiguration: config)
            label.text = nil
        } else {
            icon.image = nil
            label.text = key.label
            label.font = .systemFont(ofSize: key.isLetter && key.action != .space ? 23 : 15)
        }
        paint()
    }

    private func paint() {
        // 누르고 있는 동안에는 글자 키 ↔ 기능 키 색을 맞바꿔 눌린 느낌을 준다
        cap.backgroundColor = key.isLetter != isHighlighted ? Self.letterColor : Self.functionColor
    }
}

/// 키 배열 전체. 행마다 폭 합계가 10이 안 되면 가운데 정렬한다.
final class KeyboardView: UIView {
    var onCreate: ((KeyControl) -> Void)?
    var onDown: ((KeyControl) -> Void)?
    var onUp: ((KeyControl, _ inside: Bool) -> Void)?
    private var rows: [[KeyControl]] = []

    func setRows(_ keys: [[Key]]) {
        if keys.map({ $0.count }) == rows.map({ $0.count }) {
            // 모양이 같으면(Shift, 한/영 전환) 글자만 갈아 끼운다 → 누르고 있던 키가 끊기지 않음
            for (r, row) in keys.enumerated() {
                for (c, key) in row.enumerated() { rows[r][c].key = key }
            }
        } else {
            rows.joined().forEach { $0.removeFromSuperview() }
            rows = keys.map { row in
                row.map { key in
                    let control = KeyControl(key: key)
                    control.addTarget(self, action: #selector(down(_:)), for: .touchDown)
                    control.addTarget(self, action: #selector(upInside(_:)), for: .touchUpInside)
                    control.addTarget(self, action: #selector(upOutside(_:)), for: [.touchUpOutside, .touchCancel])
                    addSubview(control)
                    onCreate?(control)
                    return control
                }
            }
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !rows.isEmpty else { return }
        let unit = bounds.width / 10
        let height = bounds.height / CGFloat(rows.count)
        for (r, row) in rows.enumerated() {
            let total = row.reduce(0) { $0 + $1.key.width }
            var x = (10 - total) / 2 * unit
            for control in row {
                let width = control.key.width * unit
                control.frame = CGRect(x: x, y: CGFloat(r) * height, width: width, height: height)
                x += width
            }
        }
    }

    @objc private func down(_ sender: KeyControl) { onDown?(sender) }
    @objc private func upInside(_ sender: KeyControl) { onUp?(sender, true) }
    @objc private func upOutside(_ sender: KeyControl) { onUp?(sender, false) }
}
