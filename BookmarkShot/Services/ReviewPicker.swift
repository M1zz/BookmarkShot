//
//  ReviewPicker.swift
//  밑줄 (BookmarkShot)
//
//  다시 만나기: 하루에 문장 세 개를 고른다. 같은 날에는 늘 같은 세 개 (화면 · 알림이 같은 답).
//  '더 자주' 로 둔 문장은 더 자주, '덜 자주' 는 드물게 나온다. 모음(태그)을 고르면 그 안에서만 고른다.
//

import Foundation

enum ReviewPicker {

    /// 하루에 다시 만나는 문장 수
    static let perDay = 3

    /// `date` 의 문장들. `round` 를 올리면 같은 날의 다른 묶음.
    static func picks(from quotes: [Quote], on date: Date = .now, round: Int = 0, tag: String? = nil) -> [Quote] {
        let pool = quotes
            .filter { tag == nil || $0.tags.contains(tag!) }
            .sorted { $0.createdAt < $1.createdAt }   // 순서가 정해져야 같은 날 같은 답이 나온다
        guard !pool.isEmpty else { return [] }

        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        var random = SeededRandom(seed: UInt64(day) &* 1_000_003 &+ UInt64(round))
        var candidates = pool
        var picked: [Quote] = []
        while picked.count < min(perDay, pool.count) {
            let total = candidates.reduce(0) { $0 + weight($1) }
            var roll = Int(random.next() % UInt64(total))
            let index = candidates.firstIndex { roll -= weight($0); return roll < 0 } ?? 0
            picked.append(candidates.remove(at: index))
        }
        return picked
    }

    /// 덜 자주 1 · 보통 3 · 더 자주 6
    private static func weight(_ quote: Quote) -> Int {
        switch quote.reviewBias {
        case ..<0: 1
        case 1...: 6
        default: 3
        }
    }
}

/// 같은 씨앗이면 같은 수열 (SplitMix64).
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
