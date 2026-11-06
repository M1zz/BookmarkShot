//
//  BookmarkShotEntitlement.swift
//  밑줄 (BookmarkShot)
//
//  어느 칸(무료 · Plus · Pro)을 쓰는가, 그 칸이 무엇을 여는가. **앱과 위젯이 함께 읽는 한 줄.**
//
//   · 무료: 책 10권 · 문장 100개까지. 사진 한 장으로 긋고 모으는 모든 것, 검색 · 즐겨찾기 · 오늘의 문장,
//           카드 · 텍스트 공유, 문장 전체 내보내기(텍스트 · CSV)
//   · Plus: 책 · 문장 무제한
//   · Pro:  Plus 전부 + iCloud 동기화, 홈 화면 · 잠금화면 위젯
//
//  ⚠️ 절대 잠그지 않는 것: 이미 모은 책 · 문장 보기와 지우기, 내보내기, 접근성.
//     한도는 **새로 더할 때만** 막는다. 칸이 내려가도 기기 안의 기록은 그대로다.
//
//  StoreKit 은 여기 없다. 영수증은 앱의 `Purchases` 가 읽고 그 답을 App Group 에 한 줄로 적는다.
//  위젯은 그 한 줄만 읽는다 (→ BookmarkShotWidget/SharedQuote.swift 의 같은 키).
//

import Foundation
import StoreKit

/// 칸. 값이 클수록 더 많이 연다. Pro 는 Plus 를 전부 포함한다.
enum BookmarkShotTier: Int, Comparable, CaseIterable {
    case free = 0
    case plus = 1
    case pro = 2

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .free: String(localized: "무료")
        case .plus: String(localized: "밑줄 Plus")
        case .pro:  String(localized: "밑줄 Pro")
        }
    }
}

/// 값을 받고 여는 것. 페이월 · 설정 · 잠금 자리가 모두 이 목록만 읽는다.
enum BookmarkShotFeature: String, Identifiable, CaseIterable {
    case books
    case quotes
    case sync
    case widget

    var id: String { rawValue }

    /// 이 기능을 여는 가장 낮은 칸.
    var tier: BookmarkShotTier {
        switch self {
        case .books, .quotes: .plus
        case .sync, .widget:  .pro
        }
    }
}

enum BookmarkShotEntitlement {

    // MARK: - 무료 한도

    static let freeBooks = 10
    static let freeQuotes = 100

    // MARK: - 상품 ID
    //
    // ⚠️ App Store Connect · Products.storekit 과 글자 하나까지 같아야 한다.
    //    주 · 월 · 연 구독 여섯은 한 구독 그룹("밑줄")에 넣는다. Pro 가 위 단계라 서로 갈아탈 수 있다.

    private static let base = "com.leeo.bookmarkshot"

    static let plusWeeklyID   = base + ".plus.weekly"
    static let plusMonthlyID  = base + ".plus.monthly"
    static let plusYearlyID   = base + ".plus.yearly"
    static let plusLifetimeID = base + ".plus.lifetime"
    static let proWeeklyID    = base + ".pro.weekly"
    static let proMonthlyID   = base + ".pro.monthly"
    static let proYearlyID    = base + ".pro.yearly"
    static let proLifetimeID  = base + ".pro.lifetime"
    /// Plus 평생을 산 사람이 Pro 평생으로 올리는 값.
    static let upgradeID      = base + ".pro.upgrade"
    /// 구독 중인 사람의 졸업가 Pro 평생 (→ LeeoGraduation).
    static let graduateID     = base + ".pro.graduate"

    /// 개발자 응원 팁. 아무것도 열지 않는다 — `productIDs` · `tierByProduct` 에 넣지 않는다.
    static let tipProductIDs = [base + ".tip.small", base + ".tip.medium", base + ".tip.large"]

    /// 상품마다 여는 칸. 구독은 같은 칸의 평생과 같은 권한, 올리기 · 졸업은 Pro 평생이다.
    static let tierByProduct: [String: BookmarkShotTier] = [
        plusWeeklyID: .plus, plusMonthlyID: .plus, plusYearlyID: .plus, plusLifetimeID: .plus,
        proWeeklyID: .pro, proMonthlyID: .pro, proYearlyID: .pro, proLifetimeID: .pro,
        upgradeID: .pro, graduateID: .pro,
    ]

    /// 페이월이 불러올 상품. 스토어에 아직 없는 상품은 불러와지지 않고, 그 단추는 서지 않는다.
    static let productIDs: [String] = [
        plusWeeklyID, plusMonthlyID, plusYearlyID, plusLifetimeID,
        proWeeklyID, proMonthlyID, proYearlyID, proLifetimeID,
        upgradeID, graduateID,
    ]

    static var entitlementIDs: Set<String> { Set(tierByProduct.keys) }

    /// 자동 갱신 구독 (구독 졸업을 제안할 대상).
    static let subscriptionIDs: Set<String> = [
        plusWeeklyID, plusMonthlyID, plusYearlyID, proWeeklyID, proMonthlyID, proYearlyID,
    ]

    static let lifetimeIDs: Set<String> = [plusLifetimeID, proLifetimeID, upgradeID, graduateID]

    /// 가진 상품들이 여는 칸. 가장 높은 것.
    static func tier(owning productIDs: Set<String>) -> BookmarkShotTier {
        productIDs.compactMap { tierByProduct[$0] }.max() ?? .free
    }

    static func ownsLifetime(_ tier: BookmarkShotTier, in productIDs: Set<String>) -> Bool {
        productIDs.contains { lifetimeIDs.contains($0) && tierByProduct[$0] == tier }
    }

    // MARK: - 먼저 쓰던 사람

    /// 페이월이 생기기 전 마지막 빌드(1.0.4 빌드 5). 그때까지 받은 사람은 Pro 를 그대로 쓴다 —
    /// 이미 쓰던 동기화 · 위젯을 빼앗지 않는다.
    /// ⚠️ 페이월이 든 빌드의 번호는 이보다 커야 한다.
    static let lastBuildBeforePaywall = 5

    /// App Store 에서 처음 받은 빌드가 페이월 전인가.
    /// `originalAppVersion` 은 iOS 에서 빌드 번호다. 샌드박스 · Xcode 는 늘 "1.0" 을 돌려주므로 실제 App Store 만 본다.
    static func isEarlyReader() async -> Bool {
        guard case .verified(let app)? = try? await AppTransaction.shared,
              app.environment == .production,
              let build = Int(app.originalAppVersion.split(separator: ".").first ?? "") else { return false }
        return build <= lastBuildBeforePaywall
    }

    // MARK: - 위젯과 함께 쓰는 한 줄

    /// ⚠️ 위젯의 SharedQuote.swift 와 같은 키다.
    private static let tierKey = "entitlement.tier"

    static var defaults: UserDefaults { UserDefaults(suiteName: SharedQuoteStore.appGroupID) ?? .standard }

    /// 마지막으로 확인한 칸. **nil 은 '무료'가 아니라 '아직 App Store 에 묻지 않았다'** 이다.
    /// 그 차이를 잃으면 확인이 한 번 늦는 순간 산 사람이 잠긴다.
    static var cachedTier: BookmarkShotTier? {
        (defaults.object(forKey: tierKey) as? Int).flatMap(BookmarkShotTier.init(rawValue:))
    }

    /// `Purchases` 만 부른다.
    static func setTier(_ tier: BookmarkShotTier) {
        guard cachedTier != tier else { return }
        defaults.set(tier.rawValue, forKey: tierKey)
    }

    /// 잠긴 위젯을 누르면 여는 주소. ⚠️ 위젯의 SharedQuote.swift 와 같은 값.
    static let widgetPaywallURL = URL(string: "bookmarkshot://paywall/widget")!

    // MARK: - iCloud 동기화

    private static let syncKey = "sync.iCloud"

    /// 사용자가 동기화를 원하는가. 처음엔 켜 둔다 (지금까지 늘 켜져 있었다).
    static var wantsICloudSync: Bool {
        get { UserDefaults.standard.object(forKey: syncKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: syncKey) }
    }

    /// 이번 실행의 저장소를 iCloud 와 잇는가. 앱을 열 때 한 번 정한다.
    /// 아직 칸을 모르면 예전처럼 잇는다 — 업데이트 직후 먼저 쓰던 사람의 동기화가 끊기지 않게.
    static var opensWithICloud: Bool {
        guard wantsICloudSync else { return false }
        guard let tier = cachedTier else { return true }
        return tier == .pro
    }

    /// 이번 실행이 실제로 iCloud 와 이어졌는가 (CloudKit 을 못 열어 기기 안으로 열렸으면 false).
    static var launchedWithICloud = false
}
