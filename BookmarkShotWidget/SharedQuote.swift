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

    /// 위젯은 Pro 다. 앱이 적어 둔 칸(0 무료 · 1 Plus · 2 Pro)을 읽는다 (→ 앱의 BookmarkShotEntitlement).
    /// 아직 한 번도 적히지 않았으면(업데이트 뒤 앱을 열기 전) 잠그지 않는다 — 먼저 쓰던 사람의 위젯이 갑자기 닫히지 않게.
    static var isLocked: Bool {
        guard let tier = defaults?.object(forKey: "entitlement.tier") as? Int else { return false }
        return tier < 2
    }

    /// 잠긴 위젯을 누르면 여는 주소. ⚠️ 앱의 BookmarkShotEntitlement.widgetPaywallURL 과 같은 값.
    static let paywallURL = URL(string: "bookmarkshot://paywall/widget")!

    static func load() -> [SharedQuote] {
        guard let defaults,
              let data = defaults.data(forKey: key),
              let quotes = try? JSONDecoder().decode([SharedQuote].self, from: data)
        else { return [] }
        return quotes
    }
}
