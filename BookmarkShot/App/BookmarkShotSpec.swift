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
    static let developerEmail = "mizzking75@gmail.com"
    static let feedback = LeeoFeedbackConfig(containerIdentifier: "iCloud.com.Ysoup.FeedbackHub", appIdentifier: "com.leeo.bookmarkshot")
}
