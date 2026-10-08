import Foundation

/// 두벌식 한글 조합기.
/// 자모를 하나씩 넣으면 "지금 조합 중인 글자"(composing)를 관리하고,
/// 조합이 끝나 확정된 글자는 input()의 반환값으로 돌려준다.
struct HangulComposer {
    private static let chos = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
    private static let jungs = Array("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ")
    /// 0번은 "받침 없음" 자리
    private static let jongs = Array(" ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ")

    private static let vowelPairs: [String: Character] = [
        "ㅗㅏ": "ㅘ", "ㅗㅐ": "ㅙ", "ㅗㅣ": "ㅚ", "ㅜㅓ": "ㅝ", "ㅜㅔ": "ㅞ", "ㅜㅣ": "ㅟ", "ㅡㅣ": "ㅢ",
    ]
    private static let finalPairs: [String: Character] = [
        "ㄱㅅ": "ㄳ", "ㄴㅈ": "ㄵ", "ㄴㅎ": "ㄶ", "ㄹㄱ": "ㄺ", "ㄹㅁ": "ㄻ", "ㄹㅂ": "ㄼ",
        "ㄹㅅ": "ㄽ", "ㄹㅌ": "ㄾ", "ㄹㅍ": "ㄿ", "ㄹㅎ": "ㅀ", "ㅂㅅ": "ㅄ",
    ]
    /// 겹모음·겹받침 → (앞, 뒤) 로 되돌리는 표
    private static let splits: [Character: (Character, Character)] = {
        var table: [Character: (Character, Character)] = [:]
        for (pair, joined) in vowelPairs.merging(finalPairs, uniquingKeysWith: { a, _ in a }) {
            let parts = Array(pair)
            table[joined] = (parts[0], parts[1])
        }
        return table
    }()

    private var cho: Character?
    private var jung: Character?
    private var jong: Character?

    var isEmpty: Bool { cho == nil && jung == nil }

    /// 화면에 보이는 조합 중 글자 (없으면 빈 문자열, 있으면 항상 1글자)
    var composing: String {
        guard let jung = jung else { return cho.map { String($0) } ?? "" }
        guard let cho = cho,
              let c = Self.chos.firstIndex(of: cho),
              let v = Self.jungs.firstIndex(of: jung) else { return String(jung) }
        let t = jong.flatMap { Self.jongs.firstIndex(of: $0) } ?? 0
        return String(UnicodeScalar(0xAC00 + (c * 21 + v) * 28 + t)!)
    }

    mutating func reset() { self = HangulComposer() }

    /// 자모 1개 입력. 이번 입력으로 확정된 글자(없으면 "")를 돌려준다.
    mutating func input(_ jamo: Character) -> String {
        Self.jungs.contains(jamo) ? vowel(jamo) : consonant(jamo)
    }

    /// 조합 중인 글자에서 자모 하나를 지운다. (닭 → 달 → 다 → ㄷ → 없음)
    mutating func backspace() {
        if let last = jong {
            jong = Self.splits[last]?.0
        } else if let last = jung {
            jung = Self.splits[last]?.0
        } else {
            cho = nil
        }
    }

    private mutating func consonant(_ c: Character) -> String {
        if cho != nil, jung != nil {
            if let last = jong {
                if let joined = Self.finalPairs["\(last)\(c)"] {   // 달 + ㄱ → 닭
                    jong = joined
                    return ""
                }
            } else if Self.jongs.contains(c) {                     // 가 + ㄴ → 간
                jong = c
                return ""
            }
        }
        // 그 외에는 지금 글자를 확정하고 새 초성으로 시작
        let done = composing
        reset()
        cho = c
        return done
    }

    private mutating func vowel(_ v: Character) -> String {
        if let last = jong {
            // 받침을 다음 글자의 초성으로 넘긴다: 달 + ㅣ → 다리, 닭 + ㅣ → 달기
            let split = Self.splits[last]
            jong = split?.0
            let done = composing
            reset()
            cho = split?.1 ?? last
            jung = v
            return done
        }
        if let last = jung {
            if let joined = Self.vowelPairs["\(last)\(v)"] {       // 오 + ㅏ → 와
                jung = joined
                return ""
            }
            let done = composing
            reset()
            jung = v
            return done
        }
        jung = v                                                    // ㄱ + ㅏ → 가
        return ""
    }
}
