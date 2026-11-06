//
//  BookmarkShotSpec.swift
//  밑줄 (BookmarkShot)
//
//  LeeoKit 통합 계약 — 앱 이름/개발자 이메일/피드백 CloudKit 설정.
//

import Foundation
import LeeoKit

enum BookmarkShotSpec: LeeoAppSpec {
    static let appName = "밑줄"
    static let developerEmail = "leeo@kakao.com"
    static let feedback = LeeoFeedbackConfig(containerIdentifier: "iCloud.com.Ysoup.FeedbackHub", appIdentifier: "com.leeo.bookmarkshot")

    /// 법적·지원 링크 — docs/ 의 GitHub Pages. 앱이 보이는 언어의 페이지를 연다
    /// (한국어는 루트, 다른 언어는 docs/<언어>/ — 예: …/BookmarkShot/de/privacy.html). 계정을 만들지 않는다.
    static var legal: LeeoLegalConfig {
        LeeoLegalConfig(privacyURL: pageURL("privacy.html"), supportURL: pageURL("support.html"))
    }

    private static func pageURL(_ page: String) -> URL {
        let base = "https://m1zz.github.io/BookmarkShot/"
        let language = Bundle.main.preferredLocalizations.first ?? "en"
        let folder = language == "ko" ? "" : "\(language)/"
        return URL(string: base + folder + page) ?? URL(string: base + page)!
    }

    /// App Store 앱 ID — 리뷰 남기기·친구에게 소개하기 링크.
    static let appStoreID: String? = "6792787106"

    /// 수익모델 — 무료 다운로드 + 무료 · Plus · Pro. 칸마다 주 · 월 · 연 구독과 평생.
    /// 무엇이 어느 칸에서 열리는지는 `BookmarkShotFeature.tier` 한 곳, 상품은 `BookmarkShotEntitlement` 에 있다.
    static let monetization = LeeoMonetization.freemiumSubscription(
        LeeoSubscriptionConfig(
            productIDs: BookmarkShotEntitlement.productIDs,
            // 자체 약관이 없으므로 애플 표준 사용권 계약(EULA)을 건다. 구독을 파는 앱의 심사 필수 항목이다.
            termsURL: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!,
            entitlementIDs: BookmarkShotEntitlement.entitlementIDs,
            gate: LeeoGatePolicy(
                // 한도는 새로 더할 때만 막는다. 이미 모은 것은 보기 · 지우기 · 내보내기 모두 그대로다.
                freeLimits: [Gate.books: BookmarkShotEntitlement.freeBooks,
                             Gate.quotes: BookmarkShotEntitlement.freeQuotes],
                proOnly: [Gate.sync, Gate.widget]),
            // 위젯과 함께 쓰는 통. 권한 캐시가 여기 적힌다.
            cacheSuiteName: SharedQuoteStore.appGroupID,
            // 개발자 응원하기(팁) — 소모성 셋. 기능을 열지 않는다.
            tipJar: LeeoTipJarConfig(productIDs: BookmarkShotEntitlement.tipProductIDs)))

    /// 게이트 열쇠말. `BookmarkShotFeature` 의 rawValue 와 같다.
    enum Gate {
        static let books = BookmarkShotFeature.books.rawValue
        static let quotes = BookmarkShotFeature.quotes.rawValue
        static let sync = BookmarkShotFeature.sync.rawValue
        static let widget = BookmarkShotFeature.widget.rawValue
    }

    /// 금고가 위젯과 함께 쓰는 공유 컨테이너도 백업한다.
    static let appGroups = ["group.com.leeo.bookmarkshot"]

    /// 익명 사용 통계 → FeedbackHub. 없으면 bootstrap 이 스냅샷·app_open 을 건너뛴다.
    static let analytics: any LeeoAnalytics = LeeoUsageAnalytics(spec: BookmarkShotSpec.self)
}
