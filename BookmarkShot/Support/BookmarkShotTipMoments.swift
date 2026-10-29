//
//  BookmarkShotTipMoments.swift
//  밑줄 (BookmarkShot)
//
//  팁을 부탁할 만한 순간 — 지금까지 담은 문장 수. 구절을 저장하고 책 화면으로 돌아온 직후에 본다.
//  얼마나 드물게 물을지는 LeeoKit 의 규칙(`LeeoTipAskPolicy`)이 정한다.
//

import Foundation
import LeeoKit

enum BookmarkShotTipMoments {
    /// 담은 문장 수. 큰 것부터.
    static let quotes = [500, 200, 100, 50, 20]

    /// 넘어선 순간, **인상적인 것부터**.
    static func reached(quotes count: Int) -> [LeeoTipMoment] {
        quotes.filter { count >= $0 }.map { threshold in
            LeeoTipMoment(id: "quotes.\(threshold)",
                          message: String(localized: "지금까지 문장 \(count)개를 담았어요",
                                          comment: "Tip ask card: total quotes saved so far"))
        }
    }
}
