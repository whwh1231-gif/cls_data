import UIKit

/// 키 터치 진동. 축마다 정해 둔 HapticProfile에 사용자가 고른 세기를 곱해 울린다.
final class HapticEngine {
    static let shared = HapticEngine()
    private var generators: [Int: UIImpactFeedbackGenerator] = [:]

    private func generator(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        if let made = generators[style.rawValue] { return made }
        let made = UIImpactFeedbackGenerator(style: style)
        generators[style.rawValue] = made
        return made
    }

    private func fire(_ style: UIImpactFeedbackGenerator.FeedbackStyle, _ intensity: CGFloat) {
        guard Prefs.hapticOn else { return }
        let strength = min(1, max(0, intensity * CGFloat(Prefs.hapticStrength)))
        let g = generator(style)
        g.impactOccurred(intensity: strength)
        g.prepare()   // 다음 진동이 늦지 않게 미리 깨워 둠
    }

    func prepare() { generator(Prefs.switchType.haptic.down).prepare() }

    func down() {
        let p = Prefs.switchType.haptic
        fire(p.down, p.downIntensity)
    }

    func up() {
        let p = Prefs.switchType.haptic
        if let style = p.up { fire(style, p.upIntensity) }
    }
}
