//
//  SharedQuoteStore.swift
//  책갈피샷
//
//  앱과 위젯이 함께 읽는 App Group 공유 저장소.
//  앱에서 스크랩이 바뀔 때마다 가벼운 스냅샷(텍스트/책/즐겨찾기)을 써두면
//  위젯이 이를 읽어 "오늘의 문장"을 홈·잠금화면에 띄운다.
//
//  ⚠️ 위젯 타깃에도 동일한 정의(SharedQuote, appGroupID, key)가 복제되어 있다.
//     두 정의는 반드시 같은 App Group / key 를 써야 서로 통신된다.
//

import Foundation
import WidgetKit

/// 위젯에 넘길 최소 스냅샷 (이미지 등 무거운 데이터는 제외)
struct SharedQuote: Codable, Hashable {
    var text: String
    var bookTitle: String
    var author: String
    var pageLabel: String?
    var isFavorite: Bool
}

enum SharedQuoteStore {

    static let appGroupID = "group.com.leeo.bookmarkshot"
    static let widgetKind = "DailyQuoteWidget"
    private static let key = "shared_quotes"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// SwiftData 모델 배열 → 공유 스냅샷 저장 + 위젯 새로고침
    static func save(from quotes: [Quote]) {
        let mapped = quotes.map { quote in
            SharedQuote(
                text: quote.text,
                bookTitle: quote.book?.title ?? "",
                author: quote.book?.author ?? "",
                pageLabel: quote.pageLabel,
                isFavorite: quote.isFavorite
            )
        }
        save(mapped)
    }

    static func save(_ quotes: [SharedQuote]) {
        guard let defaults, let data = try? JSONEncoder().encode(quotes) else { return }
        defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func load() -> [SharedQuote] {
        guard let defaults,
              let data = defaults.data(forKey: key),
              let quotes = try? JSONDecoder().decode([SharedQuote].self, from: data)
        else { return [] }
        return quotes
    }
}
