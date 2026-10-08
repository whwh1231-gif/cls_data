import UIKit

enum Page { case letters, numbers, symbols }
enum ShiftState { case off, on, locked }

enum KeyAction: Equatable {
    case jamo(Character)     // 한글 자모 (조합 대상)
    case text(String)        // 영문·숫자·기호 (그대로 입력)
    case shift, backspace, space, enter, globe, lang
    case page(Page)
}

struct Key {
    let action: KeyAction
    let label: String        // "sf:이름" 이면 SF Symbol 아이콘
    var width: CGFloat = 1   // 1 = 화면 폭의 1/10

    /// 글자 키(밝은 색)인지 기능 키(어두운 색)인지
    var isLetter: Bool {
        switch action {
        case .jamo, .text, .space: return true
        default: return false
        }
    }
}

enum Layouts {
    static func rows(page: Page, korean: Bool, shift: ShiftState, needsGlobe: Bool) -> [[Key]] {
        let top: [[Key]]
        switch page {
        case .letters:
            let up = shift != .off
            let lines: [String] = korean
                ? [up ? "ㅃㅉㄸㄲㅆㅛㅕㅑㅒㅖ" : "ㅂㅈㄷㄱㅅㅛㅕㅑㅐㅔ", "ㅁㄴㅇㄹㅎㅗㅓㅏㅣ", "ㅋㅌㅊㅍㅠㅜㅡ"]
                : ["qwertyuiop", "asdfghjkl", "zxcvbnm"].map { up ? $0.uppercased() : $0 }
            let keys: [[Key]] = lines.map { line in
                line.map { ch in Key(action: korean ? KeyAction.jamo(ch) : KeyAction.text(String(ch)), label: String(ch)) }
            }
            let shiftIcon = shift == .locked ? "sf:capslock.fill" : (up ? "sf:shift.fill" : "sf:shift")
            top = [keys[0], keys[1],
                   [Key(action: .shift, label: shiftIcon, width: 1.5)] + keys[2]
                   + [Key(action: .backspace, label: "sf:delete.left", width: 1.5)]]
        case .numbers, .symbols:
            let lines = page == .numbers
                ? ["1234567890", "-/:;()₩&@\"", ".,?!'"]
                : ["[]{}#%^*+=", "_\\|~<>$£¥•", ".,?!'"]
            let keys: [[Key]] = lines.map { line in line.map { ch in Key(action: .text(String(ch)), label: String(ch)) } }
            let toggle = page == .numbers
                ? Key(action: .page(.symbols), label: "#+=", width: 1.5)
                : Key(action: .page(.numbers), label: "123", width: 1.5)
            top = [keys[0], keys[1],
                   [toggle] + keys[2].map { Key(action: $0.action, label: $0.label, width: 1.4) }
                   + [Key(action: .backspace, label: "sf:delete.left", width: 1.5)]]
        }

        var bottom = [page == .letters
            ? Key(action: .page(.numbers), label: "123", width: 1.25)
            : Key(action: .page(.letters), label: korean ? "가" : "ABC", width: 1.25)]
        if needsGlobe { bottom.append(Key(action: .globe, label: "sf:globe", width: 1.25)) }
        bottom.append(Key(action: .lang, label: "한/영", width: 1.25))
        let used = bottom.reduce(0) { $0 + $1.width } + 2.5
        bottom.append(Key(action: .space, label: korean ? "스페이스" : "space", width: 10 - used))
        bottom.append(Key(action: .enter, label: "sf:return", width: 2.5))
        return top + [bottom]
    }
}
