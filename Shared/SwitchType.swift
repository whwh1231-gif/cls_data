import UIKit

/// 키 하나를 눌렀다 뗄 때의 진동 설정
struct HapticProfile {
    let down: UIImpactFeedbackGenerator.FeedbackStyle
    let downIntensity: CGFloat          // 0...1
    var up: UIImpactFeedbackGenerator.FeedbackStyle? = nil
    var upIntensity: CGFloat = 0
}

/// 스위치(축) 종류. rawValue가 곧 소리 파일 이름의 앞부분이다. (예: red_o_down1.wav)
enum SwitchType: String, CaseIterable, Identifiable {
    case red, brown, black, blue, cream, lavender
    case custom   // 내 소리: 직접 녹음한 파일 (CustomSound)

    var id: String { rawValue }

    var name: String {
        switch self {
        case .red: return "적축"
        case .brown: return "갈축"
        case .black: return "흑축"
        case .blue: return "청축"
        case .cream: return "크림축"
        case .lavender: return "아크 라벤더"
        case .custom: return "내 소리"
        }
    }

    var summary: String {
        switch self {
        case .red: return "리니어 · 가볍고 사각사각한 타건감"
        case .brown: return "택타일 · 도각도각 정갈한 걸림"
        case .black: return "묵직한 리니어 · 쫀득하고 정숙함"
        case .blue: return "클릭 · 경쾌하고 또렷한 찰칵"
        case .cream: return "커스텀 리니어 · 낮고 깊은 도각"
        case .lavender: return "커스텀 택타일 · 또렷한 팝핑"
        case .custom: return "직접 녹음한 소리 · 누를 때마다 재생"
        }
    }

    var color: UIColor {
        switch self {
        case .red: return UIColor(red: 0.78, green: 0.26, blue: 0.23, alpha: 1)
        case .brown: return UIColor(red: 0.54, green: 0.35, blue: 0.24, alpha: 1)
        case .black: return UIColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1)
        case .blue: return UIColor(red: 0.18, green: 0.44, blue: 0.82, alpha: 1)
        case .cream: return UIColor(red: 0.85, green: 0.80, blue: 0.71, alpha: 1)
        case .lavender: return UIColor(red: 0.48, green: 0.36, blue: 0.84, alpha: 1)
        case .custom: return UIColor(red: 0.88, green: 0.32, blue: 0.54, alpha: 1)
        }
    }

    /// 축마다 다른 손맛. 여기 숫자만 바꾸면 진동 느낌이 바뀐다.
    var haptic: HapticProfile {
        switch self {
        case .red:      return HapticProfile(down: .light, downIntensity: 0.60)
        case .brown:    return HapticProfile(down: .medium, downIntensity: 0.65)
        case .black:    return HapticProfile(down: .heavy, downIntensity: 0.75)
        case .blue:     return HapticProfile(down: .rigid, downIntensity: 0.95, up: .light, upIntensity: 0.45)
        case .cream:    return HapticProfile(down: .soft, downIntensity: 0.95)
        case .lavender: return HapticProfile(down: .rigid, downIntensity: 0.65, up: .soft, upIntensity: 0.35)
        case .custom:   return HapticProfile(down: .medium, downIntensity: 0.70)
        }
    }
}
