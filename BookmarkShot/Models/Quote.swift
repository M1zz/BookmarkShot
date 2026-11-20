//
//  Quote.swift
//  밑줄
//

import Foundation
import SwiftData

@Model
final class Quote {
    var text: String = ""
    var pageNumber: Int?
    @Attribute(.externalStorage) var pageImageData: Data?
    var note: String = ""
    var isFavorite: Bool = false
    var createdAt: Date = Date()
    /// 이 문장을 담은 모음(태그). 한 문장이 여러 모음에 들 수 있다.
    var tags: [String] = []
    /// 다시 만나는 빈도: -1 덜 자주 · 0 보통 · 1 더 자주 (→ ReviewPicker)
    var reviewBias: Int = 0

    var book: Book?

    init(text: String = "",
         pageNumber: Int? = nil,
         pageImageData: Data? = nil,
         note: String = "",
         book: Book? = nil) {
        self.text = text
        self.pageNumber = pageNumber
        self.pageImageData = pageImageData
        self.note = note
        self.book = book
        self.createdAt = Date()
    }

    /// "p.123" 형태 표기 (언어마다 쪽 표기가 다르다: S. 123, с. 123, 第123页 …)
    var pageLabel: String? {
        guard let pageNumber else { return nil }
        return String(localized: "p.\(pageNumber)", comment: "Page number label under a quote, e.g. p.12")
    }
}
