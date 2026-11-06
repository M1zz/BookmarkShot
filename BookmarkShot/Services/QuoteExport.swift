//
//  QuoteExport.swift
//  밑줄 (BookmarkShot)
//
//  모은 문장 전체를 파일로 꺼낸다 — 텍스트(.txt) · 표(.csv). **무료다.** 칸과 상관없이 늘 열려 있다.
//  내 문장을 앱 밖으로 가져갈 길은 잠그지 않는다.
//
//  ShareLink 에 넘기면 공유 시트가 열릴 때 파일을 만든다(누르기 전에는 아무것도 쓰지 않는다).
//

import SwiftUI
import UniformTypeIdentifiers

struct QuoteExport: Transferable {
    enum Format { case text, csv }

    /// 파일에 적을 한 줄. SwiftData 모델을 공유 시트 밖으로 넘기지 않게 값으로 떠 둔다.
    struct Row {
        var text, book, author, note: String
        var page: Int?
        var pageLabel: String?
        var isFavorite: Bool
        var createdAt: Date
    }

    let rows: [Row]
    let format: Format

    init(quotes: [Quote], format: Format) {
        // 책 순서(제목) → 책 안에서는 담은 순서. 읽은 길을 따라 읽히게.
        self.rows = quotes
            .map { Row(text: $0.text, book: $0.book?.title ?? "", author: $0.book?.author ?? "", note: $0.note,
                       page: $0.pageNumber, pageLabel: $0.pageLabel, isFavorite: $0.isFavorite, createdAt: $0.createdAt) }
            .sorted { ($0.book, $0.createdAt) < ($1.book, $1.createdAt) }
        self.format = format
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { export in
            try export.write(.text)
        }
        .exportingCondition { $0.format == .text }
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            try export.write(.csv)
        }
        .exportingCondition { $0.format == .csv }
    }

    /// 공유 시트에 보일 파일 이름 (확장자 없이).
    static var fileName: String { String(localized: "밑줄 문장 모음", comment: "Export: file name for all saved quotes") }

    private func write(_ format: Format) throws -> SentTransferredFile {
        let ext = format == .text ? "txt" : "csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(Self.fileName).\(ext)")
        let body = format == .text ? plainText : csv
        // CSV 는 BOM 을 붙인다. 없으면 엑셀이 한글 · 한자를 깨뜨려 연다.
        let data = (format == .csv ? "\u{FEFF}" : "") + body
        try data.write(to: url, atomically: true, encoding: .utf8)
        return SentTransferredFile(url)
    }

    // MARK: - 텍스트

    private var plainText: String {
        rows.map { row in
            var source = [row.book, row.author].filter { !$0.isEmpty }.joined(separator: ", ")
            if let page = row.pageLabel { source += source.isEmpty ? page : " · \(page)" }
            var block = "“\(row.text)”"
            if !source.isEmpty { block += "\n— \(source)" }
            if !row.note.isEmpty { block += "\n\(row.note)" }
            return block
        }
        .joined(separator: "\n\n") + "\n"
    }

    // MARK: - CSV

    private var csv: String {
        let header = String(localized: "문장,책,저자,페이지,즐겨찾기,메모,날짜",
                            comment: "Export CSV header row. Keep exactly 7 comma-separated column names in this order: quote, book, author, page, favorite, note, date")
        let date = ISO8601DateFormatter()
        date.formatOptions = [.withFullDate]
        let lines = rows.map { row in
            [row.text, row.book, row.author, row.page.map(String.init) ?? "", row.isFavorite ? "1" : "0",
             row.note, date.string(from: row.createdAt)]
                .map(Self.escape)
                .joined(separator: ",")
        }
        return ([header] + lines).joined(separator: "\r\n") + "\r\n"
    }

    /// 쉼표 · 따옴표 · 줄바꿈이 든 칸은 따옴표로 감싼다 (RFC 4180).
    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
