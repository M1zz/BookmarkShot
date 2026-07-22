//
//  Book.swift
//  밑줄
//
//  CloudKit 동기화 규칙: 모든 프로퍼티는 기본값 또는 옵셔널, 관계는 옵셔널이어야 함.
//

import Foundation
import SwiftData

@Model
final class Book {
    var title: String = ""
    var author: String = ""
    var isbn: String?
    @Attribute(.externalStorage) var coverImageData: Data?
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Quote.book)
    var quotes: [Quote]? = []

    init(title: String = "", author: String = "", isbn: String? = nil, coverImageData: Data? = nil) {
        self.title = title
        self.author = author
        self.isbn = isbn
        self.coverImageData = coverImageData
        self.createdAt = Date()
    }

    /// 정렬된 문장 목록 (최신순)
    var sortedQuotes: [Quote] {
        (quotes ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    var quoteCount: Int { quotes?.count ?? 0 }
}
