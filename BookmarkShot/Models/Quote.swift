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

    /// "p.123" 형태 표기
    var pageLabel: String? {
        guard let pageNumber else { return nil }
        return "p.\(pageNumber)"
    }
}
