import Foundation

/// 앱과 키보드가 함께 보는 설정 저장소 (App Group).
/// App Group이 없는 설치(무료 사이드로드 등)에서는 서로 공유가 안 되므로
/// 키보드 위쪽 바에서도 축·흡음재를 바꿀 수 있게 해 두었다.
enum Prefs {
    static let groupID = "group.com.woo.tadak"
    static let store = UserDefaults(suiteName: groupID) ?? .standard

    enum Key {
        static let switchType = "switchType"
        static let dampened = "dampened"
        static let soundOn = "soundOn"
        static let volume = "volume"
        static let hapticOn = "hapticOn"
        static let hapticStrength = "hapticStrength"
        static let keyUpSound = "keyUpSound"
        static let playInSilentMode = "playInSilentMode"
        static let customVersion = "customVersion"
    }

    static var switchType: SwitchType {
        get { SwitchType(rawValue: store.string(forKey: Key.switchType) ?? "") ?? .brown }
        set { store.set(newValue.rawValue, forKey: Key.switchType) }
    }
    static var dampened: Bool {
        get { store.bool(forKey: Key.dampened) }
        set { store.set(newValue, forKey: Key.dampened) }
    }
    /// "내 소리"를 새로 녹음하거나 지울 때마다 1씩 올라간다
    static var customVersion: Int {
        get { store.integer(forKey: Key.customVersion) }
        set { store.set(newValue, forKey: Key.customVersion) }
    }
    static var soundOn: Bool { store.object(forKey: Key.soundOn) as? Bool ?? true }
    static var volume: Double { store.object(forKey: Key.volume) as? Double ?? 0.8 }
    static var hapticOn: Bool { store.object(forKey: Key.hapticOn) as? Bool ?? true }
    static var hapticStrength: Double { store.object(forKey: Key.hapticStrength) as? Double ?? 1.0 }
    static var keyUpSound: Bool { store.object(forKey: Key.keyUpSound) as? Bool ?? true }
    static var playInSilentMode: Bool { store.bool(forKey: Key.playInSilentMode) }
}
