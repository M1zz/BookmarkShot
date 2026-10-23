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

    /// 수익모델 — 인앱 결제가 없는 완전 무료 앱.
    static let monetization = LeeoMonetization.free

    /// 익명 사용 통계 → FeedbackHub. 없으면 bootstrap 이 스냅샷·app_open 을 건너뛴다.
    static let analytics: any LeeoAnalytics = LeeoUsageAnalytics(spec: BookmarkShotSpec.self)
}
