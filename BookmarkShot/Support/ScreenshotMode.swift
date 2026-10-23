//
//  ScreenshotMode.swift
//  밑줄
//
//  App Store 스크린샷용 데모 모드 (DEBUG 빌드에서만 동작한다).
//  시뮬레이터에서 아래처럼 띄우면 메모리 저장소에 그 언어의 데모 서재를 채우고 원하는 화면을 연다.
//
//    xcrun simctl launch <기기> com.leeo.bookmarkshot \
//      -AppleLanguages "(de)" -AppleLocale de_DE \
//      -ScreenshotSeed <앱 컨테이너 안 seed.json 경로> -ScreenshotScene library|quotes|daily|region|highlight|settings
//
//  seed.json: {"books":[{"title","author"}], "quotes":[{"book","text","page","fav","days_ago","note"}],
//              "daily_quote": n, "page": {"book","page","highlight"}}  + 같은 폴더의 page_photo.png(찍은 페이지 사진)
//  데모 서재: scripts/screenshot_seed/<언어>.json · 찍는 곳: scripts/capture_screenshots.py
//

import SwiftUI
import SwiftData

enum ScreenshotMode {
    enum Scene: String {
        case library, quotes, daily, region, highlight, settings
    }

    struct Seed: Decodable {
        struct SeedBook: Decodable { let title: String; let author: String }
        struct SeedQuote: Decodable {
            let book: Int
            let text: String
            let page: Int?
            let fav: Bool?
            let days_ago: Int
            let note: String?
        }
        struct SeedPage: Decodable { let book: Int; let page: Int?; let highlight: String }
        let books: [SeedBook]
        let quotes: [SeedQuote]
        let daily_quote: Int?
        let page: SeedPage?
    }

    #if DEBUG
    private static func argument(_ name: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: name), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }

    static let seedURL: URL? = argument("-ScreenshotSeed").map { URL(fileURLWithPath: $0) }
    static let scene: Scene? = argument("-ScreenshotScene").flatMap(Scene.init(rawValue:))
    static let seed: Seed? = seedURL.flatMap { try? JSONDecoder().decode(Seed.self, from: Data(contentsOf: $0)) }
    #else
    static let seedURL: URL? = nil
    static let scene: Scene? = nil
    static let seed: Seed? = nil
    #endif

    static var isActive: Bool { seed != nil }

    /// 탭 번호: 0 서재 · 1 문장 · 2 오늘의 문장
    static var initialTab: Int {
        switch scene {
        case .quotes: return 1
        case .daily: return 2
        default: return 0
        }
    }

    static var opensScanPage: Bool { scene == .region || scene == .highlight }

    /// 찍은 페이지 사진 (seed.json 옆의 page_photo.png)
    static var pagePhoto: UIImage? {
        guard let dir = seedURL?.deletingLastPathComponent() else { return nil }
        return UIImage(contentsOfFile: dir.appendingPathComponent("page_photo.png").path)
    }

    static var highlightText: String? { seed?.page?.highlight }
    static var dailyQuoteText: String? {
        guard let seed, let index = seed.daily_quote, seed.quotes.indices.contains(index) else { return nil }
        return seed.quotes[index].text
    }

    /// 데모 서재에서 페이지 사진의 책
    static func pageBook(in books: [Book]) -> Book? {
        guard let seed, let page = seed.page, seed.books.indices.contains(page.book) else { return books.first }
        let title = seed.books[page.book].title
        return books.first { $0.title == title } ?? books.first
    }

    /// 메모리 저장소에 데모 서재를 채운다.
    static func populate(_ context: ModelContext) {
        guard let seed else { return }
        UserDefaults.standard.set(0, forKey: "highlightHintShownCount")
        let now = Date()
        // 책은 서재에서 첫 책이 맨 앞(최신)에 오도록 만든 시각을 1분씩 당긴다
        let books: [Book] = seed.books.enumerated().map { index, item in
            let book = Book(title: item.title, author: item.author)
            book.createdAt = now.addingTimeInterval(TimeInterval(-60 * index))
            context.insert(book)
            return book
        }
        for item in seed.quotes where books.indices.contains(item.book) {
            let quote = Quote(text: item.text, pageNumber: item.page, note: item.note ?? "", book: books[item.book])
            quote.isFavorite = item.fav ?? false
            quote.createdAt = Calendar.current.date(byAdding: .day, value: -item.days_ago, to: now) ?? now
            context.insert(quote)
        }
        try? context.save()
    }

    /// 데모 책에 표지를 그려 넣는다. ⚠️ 앱 init 에서 그리면 UIKit 이 일찍 깨어나 앱 강조색(AccentColor)이
    /// 파란 기본색으로 바뀐다 — 화면이 뜬 뒤(ContentView.task)에 부른다.
    static func paintCovers(_ books: [Book]) {
        guard let seed else { return }
        for (index, item) in seed.books.enumerated() {
            guard let book = books.first(where: { $0.title == item.title }), book.coverImageData == nil else { continue }
            book.coverImageData = coverImage(title: item.title, author: item.author, style: index).pngData()
        }
    }

    /// 데모용 표지: 단색 바탕에 명조 제목 · 저자, 모서리에 둥근 무늬 (실제 표지 사진 대신)
    static func coverImage(title: String, author: String, style: Int) -> UIImage {
        let palette: [(UIColor, UIColor)] = [
            (UIColor(red: 0.13, green: 0.19, blue: 0.32, alpha: 1), .white),
            (UIColor(red: 0.76, green: 0.25, blue: 0.36, alpha: 1), .white),
            (UIColor(red: 0.92, green: 0.89, blue: 0.82, alpha: 1), UIColor(red: 0.25, green: 0.23, blue: 0.2, alpha: 1)),
            (UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1), .white),
            (UIColor(red: 0.80, green: 0.42, blue: 0.17, alpha: 1), .white),
            (UIColor(red: 0.29, green: 0.36, blue: 0.30, alpha: 1), .white),
        ]
        let (background, ink) = palette[style % palette.count]
        let size = CGSize(width: 600, height: 840)
        return UIGraphicsImageRenderer(size: size).image { context in
            background.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            ink.withAlphaComponent(0.16).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 330, y: 560, width: 380, height: 380))
            UIColor(red: 0.95, green: 0.64, blue: 0.29, alpha: 1).setFill()
            context.fill(CGRect(x: 56, y: 70, width: 70, height: 6))
            let serif = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle).withDesign(.serif)
                ?? UIFont.systemFont(ofSize: 60).fontDescriptor
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 8
            paragraph.lineBreakMode = .byWordWrapping
            let titleFont = UIFont(descriptor: serif, size: title.count <= 6 ? 124 : title.count <= 14 ? 100 : 84)
            (title as NSString).draw(with: CGRect(x: 56, y: 110, width: 500, height: 560),
                                     options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                                     attributes: [.font: titleFont, .foregroundColor: ink, .paragraphStyle: paragraph], context: nil)
            (author as NSString).draw(with: CGRect(x: 56, y: 720, width: 440, height: 70),
                                      options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                                      attributes: [.font: UIFont(descriptor: serif, size: 40), .foregroundColor: ink.withAlphaComponent(0.8)], context: nil)
        }
    }
}
