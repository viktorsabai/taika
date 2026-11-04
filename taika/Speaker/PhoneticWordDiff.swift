import Foundation

/// Слово эталона против того, что распознала Apple на его месте.
/// Стрелка у услышанного — словарный тон слова, которое узнала Apple, а не измеренная высота голоса.
struct PhoneticWordDiff: Equatable {
    enum Issue: Equatable, Hashable {
        case lostAspiration(onset: String)
        case addedAspiration(onset: String)
        case otherWord
        case missingSyllable(String)
        /// syllable — подпись слога, если в слове их несколько.
        case tone(syllable: String?, expected: Character, heard: Character)
    }

    let expected: String
    /// nil — на месте этого слова Apple ничего не услышала.
    let heard: String?
    let issues: [Issue]

    var isMatch: Bool { heard != nil && issues.isEmpty }

    var reasons: [String] {
        guard heard != nil else { return ["это слово не услышала"] }
        return issues.map { issue in
            switch issue {
            case .lostAspiration(let onset):
                return "без придыхания: \(onset) → \(onset.prefix(1))"
            case .addedAspiration(let onset):
                return "лишнее придыхание: \(onset.prefix(1)) → \(onset)"
            case .otherWord:
                return "Apple услышала другое слово"
            case .missingSyllable(let syllable):
                return "не хватает «\(syllable)»"
            case .tone(let syllable, let expected, let heard):
                let line = "тон \(heard), а нужен \(expected)"
                return syllable.map { "\($0): \(line)" } ?? line
            }
        }
    }

    // MARK: - Compare

    static func compare(expected: String, heard: String) -> [PhoneticWordDiff] {
        let exp = syllables(expected)
        let hrd = syllables(heard)
        guard !exp.isEmpty else { return [] }
        let match = align(exp, hrd)

        let words = expectedWords(expected)
        var out: [PhoneticWordDiff] = []
        for w in words.indices {
            let idx = exp.indices.filter { exp[$0].word == w }
            guard !idx.isEmpty else { continue }
            let display = words[w]
            let heardIdx = idx.compactMap { match[$0] }
            guard !heardIdx.isEmpty else {
                out.append(PhoneticWordDiff(expected: display, heard: nil, issues: []))
                continue
            }
            var issues: [Issue] = []
            for i in idx {
                guard let h = match[i] else {
                    issues.append(.missingSyllable(exp[i].text.filter { !arrows.contains($0) }))
                    continue
                }
                let label = idx.count > 1 ? exp[i].text.filter { !arrows.contains($0) } : nil
                issues.append(contentsOf: compareSyllable(exp[i], hrd[h], label: label))
            }
            var seen = Set<Issue>()
            issues = issues.filter { seen.insert($0).inserted }
            if issues.contains(.otherWord) {
                issues = [.otherWord]
            }
            out.append(PhoneticWordDiff(
                expected: display,
                heard: heardIdx.map { hrd[$0].text }.joined(separator: "-"),
                issues: issues
            ))
        }
        return out
    }

    // MARK: - Internals

    private struct Syllable {
        let text: String
        let key: String
        let tone: Character?
        let word: Int
    }

    private static let arrows: Set<Character> = ["→", "↓", "↘", "↑", "↗"]
    private static let aspiratedOnsets = ["пх", "тх", "кх", "чх"]
    private static let vowels: Set<Character> = ["а", "е", "и", "о", "у", "ы", "э", "ю", "я", "ё", "ɨ"]

    private static func expectedWords(_ phonetic: String) -> [String] {
        phonetic.split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !soundKey($0).isEmpty }
    }

    private static func syllables(_ phonetic: String) -> [Syllable] {
        var out: [Syllable] = []
        for (w, word) in expectedWords(phonetic).enumerated() {
            for piece in word.split(whereSeparator: { "-·".contains($0) }) {
                let text = String(piece).trimmingCharacters(in: .punctuationCharacters)
                let key = soundKey(text)
                guard !key.isEmpty else { continue }
                out.append(Syllable(text: text, key: key, tone: text.last(where: { arrows.contains($0) }), word: w))
            }
        }
        return out
    }

    /// Ключ звучания: снимаем разницу в записи, которая не меняет звук (сах/са, кхоб/кхоп, сиа/сие).
    static func soundKey(_ raw: String) -> String {
        var s = raw.lowercased().filter { $0.isLetter }
        s = s.replacingOccurrences(of: "ɨ", with: "ы")
            .replacingOccurrences(of: "і", with: "и")
            .replacingOccurrences(of: "ё", with: "е")
            .replacingOccurrences(of: "э", with: "е")
        s = s.replacingOccurrences(of: "ия", with: "иа")
            .replacingOccurrences(of: "ие", with: "иа")
        var collapsed = ""
        for ch in s {
            if let last = collapsed.last, last == ch, vowels.contains(ch) { continue }
            collapsed.append(ch)
        }
        s = collapsed
        if s.count > 1, s.last == "х", let prev = s.dropLast().last, vowels.contains(prev) {
            s.removeLast()
        }
        if let last = s.last, s.count > 1 {
            let finals: [Character: Character] = ["б": "п", "д": "т", "г": "к", "в": "у"]
            if let mapped = finals[last] {
                s.removeLast()
                s.append(mapped)
            }
        }
        return s
    }

    private static func aspirationIssue(expected a: String, heard b: String) -> Issue? {
        for onset in aspiratedOnsets {
            let plain = String(onset.prefix(1))
            if a.hasPrefix(onset), plain + a.dropFirst(onset.count) == b {
                return .lostAspiration(onset: onset)
            }
            if b.hasPrefix(onset), plain + b.dropFirst(onset.count) == a {
                return .addedAspiration(onset: onset)
            }
        }
        return nil
    }

    private static func compareSyllable(_ e: Syllable, _ h: Syllable, label: String?) -> [Issue] {
        var issues: [Issue] = []
        if e.key != h.key {
            if let asp = aspirationIssue(expected: e.key, heard: h.key) {
                issues.append(asp)
            } else {
                return [.otherWord]
            }
        }
        if let et = e.tone, let ht = h.tone, et != ht {
            issues.append(.tone(syllable: label, expected: et, heard: ht))
        }
        return issues
    }

    private static func substitutionCost(_ a: Syllable, _ b: Syllable) -> Double {
        if a.key == b.key { return 0 }
        if aspirationIssue(expected: a.key, heard: b.key) != nil { return 0.3 }
        let d = editDistance(Array(a.key), Array(b.key))
        if d <= max(1, max(a.key.count, b.key.count) / 3) { return 0.6 }
        return 1.0
    }

    /// Выравнивание по слогам: индекс услышанного слога для каждого слога эталона.
    private static func align(_ a: [Syllable], _ b: [Syllable]) -> [Int?] {
        let n = a.count, m = b.count
        var cost = Array(repeating: Array(repeating: 0.0, count: m + 1), count: n + 1)
        for i in 0...n { cost[i][0] = Double(i) }
        for j in 0...m { cost[0][j] = Double(j) }
        if n > 0, m > 0 {
            for i in 1...n {
                for j in 1...m {
                    cost[i][j] = min(
                        cost[i - 1][j - 1] + substitutionCost(a[i - 1], b[j - 1]),
                        cost[i - 1][j] + 1,
                        cost[i][j - 1] + 1
                    )
                }
            }
        }
        var result = [Int?](repeating: nil, count: n)
        var i = n, j = m
        while i > 0, j > 0 {
            if cost[i][j] == cost[i - 1][j - 1] + substitutionCost(a[i - 1], b[j - 1]) {
                result[i - 1] = j - 1
                i -= 1; j -= 1
            } else if cost[i][j] == cost[i - 1][j] + 1 {
                i -= 1
            } else {
                j -= 1
            }
        }
        return result
    }

    private static func editDistance(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        for i in 1...a.count {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return prev[b.count]
    }
}