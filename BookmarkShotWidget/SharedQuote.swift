//
//  SharedQuote.swift
//  BookmarkShotWidget
//
//  위젯 타깃용 App Group 공유 저장소 (읽기 전용).
//  ⚠️ 앱 타깃의 SharedQuoteStore.swift 와 SharedQuote/appGroupID/key 정의가 동일해야 한다.
//

import Foundation

struct SharedQuote: Codable, Hashable {
    var text: String
    var bookTitle: String
    var author: String
    var pageLabel: String?
    var isFavorite: Bool
}

enum SharedQuoteStore {

    static let appGroupID = "group.com.leeo.bookmarkshot"
    private static let key = "shared_quotes"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func load() -> [SharedQuote] {
        guard let defaults,
              let data = defaults.data(forKey: key),
              let quotes = try? JSONDecoder().decode([SharedQuote].self, from: data)
        else { return [] }
        return quotes
    }
}
