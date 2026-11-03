//
//  BookmarkShotIntents.swift
//  BookmarkShot
//
//  책과 밑줄 친 문장을 Siri · Spotlight · 단축어가 알아보게 한다.
//
//  - Spotlight: 문장마다 본문 · 책 제목 · 저자를 싣는다(iOS 18+). 누르면 그 문장이 열린다.
//  - "밑줄에서 ○○ 스캔해줘": 그 책의 페이지 스캔 화면을 바로 연다.
//  - "밑줄 오늘의 문장": Siri 가 문장 하나를 읽어 준다.
//  - "밑줄에서 문장 찾아줘": 단어로 찾은 문장들을 보여 준다.
//
//  SwiftData 모델은 고유 문자열 id 가 없어 PersistentIdentifier 를 문자열로 바꿔 쓴다.
//

import AppIntents
import CoreSpotlight
import Foundation
import SwiftData

// MARK: - 앱 화면으로 넘기는 요청

@MainActor @Observable
final class BookmarkShotRouter {
    static let shared = BookmarkShotRouter()
    /// 열어 달라는 문장 · 스캔할 책. ContentView 가 시트로 열고 비운다.
    var quoteID: PersistentIdentifier?
    var scanBookID: PersistentIdentifier?
}

/// 시트로 바로 열 수 있게 (`.sheet(item:)`).
extension PersistentIdentifier: @retroactive Identifiable {
    public var id: Self { self }
}

extension PersistentIdentifier {
    var intentID: String {
        (try? JSONEncoder().encode(self))?.base64EncodedString() ?? ""
    }

    init?(intentID: String) {
        guard let data = Data(base64Encoded: intentID),
              let id = try? JSONDecoder().decode(PersistentIdentifier.self, from: data) else { return nil }
        self = id
    }
}

// MARK: - 문장

struct QuoteEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("밑줄 문장", comment: "Siri/Spotlight: one underlined sentence from a book")
    )
    static let defaultQuery = QuoteQuery()

    let id: String
    let text: String
    let bookTitle: String
    let author: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(String(text.prefix(80)))", subtitle: "\(bookTitle)")
    }

    init(_ quote: Quote) {
        id = quote.persistentModelID.intentID
        text = quote.text
        bookTitle = quote.book?.title ?? ""
        author = quote.book?.author ?? ""
    }
}

@available(iOS 18.0, *)
extension QuoteEntity: IndexedEntity {
    var attributeSet: CSSearchableItemAttributeSet {
        let set = defaultAttributeSet
        set.textContent = text
        set.keywords = [bookTitle, author].filter { !$0.isEmpty }
        return set
    }
}

struct QuoteQuery: EntityStringQuery {
    @Dependency private var container: ModelContainer

    func entities(for identifiers: [String]) async throws -> [QuoteEntity] {
        let context = ModelContext(container)
        return identifiers.compactMap { raw in
            guard let id = PersistentIdentifier(intentID: raw),
                  let quote = context.model(for: id) as? Quote else { return nil }
            return QuoteEntity(quote)
        }
    }

    func entities(matching string: String) async throws -> [QuoteEntity] {
        BookmarkShotLibrary.search(string, in: container)
    }

    func suggestedEntities() async throws -> [QuoteEntity] {
        Array(BookmarkShotLibrary.quotes(in: container).prefix(20)).map(QuoteEntity.init)
    }
}

// MARK: - 책

struct BookEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("책", comment: "Siri: a book in the library")
    )
    static let defaultQuery = BookQuery()

    let id: String
    let title: String
    let author: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(author)")
    }

    init(_ book: Book) {
        id = book.persistentModelID.intentID
        title = book.title
        author = book.author
    }
}

struct BookQuery: EntityStringQuery {
    @Dependency private var container: ModelContainer

    private func books() -> [Book] {
        let descriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? ModelContext(container).fetch(descriptor)) ?? []
    }

    func entities(for identifiers: [String]) async throws -> [BookEntity] {
        let wanted = Set(identifiers)
        return books().map(BookEntity.init).filter { wanted.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [BookEntity] {
        books().filter { $0.title.localizedCaseInsensitiveContains(string) || $0.author.localizedCaseInsensitiveContains(string) }
            .map(BookEntity.init)
    }

    func suggestedEntities() async throws -> [BookEntity] {
        books().map(BookEntity.init)
    }
}

// MARK: - 인텐트

/// 그 책의 페이지 스캔 화면을 바로 연다.
struct ScanPageIntent: AppIntent {
    static let title = LocalizedStringResource("밑줄 스캔", comment: "Siri: open the page scanner for a book")
    static let description = IntentDescription(
        LocalizedStringResource("책 페이지를 찍어 밑줄 칠 문장을 고릅니다.", comment: "Siri: scan page description")
    )
    static let openAppWhenRun = true

    @Parameter(title: LocalizedStringResource("책", comment: "Siri: book parameter"),
               requestValueDialog: IntentDialog(LocalizedStringResource("어느 책을 스캔할까요?", comment: "Siri: ask which book")))
    var book: BookEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        BookmarkShotRouter.shared.scanBookID = PersistentIdentifier(intentID: book.id)
        return .result()
    }
}

/// 밑줄 친 문장 하나를 Siri 가 읽어 준다. 즐겨찾기한 문장에서 먼저 고른다.
struct TodayQuoteIntent: AppIntent {
    static let title = LocalizedStringResource("오늘의 문장", comment: "Siri: read one saved sentence")
    static let description = IntentDescription(
        LocalizedStringResource("밑줄 친 문장 하나를 골라 읽어 줍니다.", comment: "Siri: today's sentence description")
    )

    @Dependency private var container: ModelContainer

    func perform() async throws -> some IntentResult & ReturnsValue<QuoteEntity?> & ProvidesDialog {
        let all = BookmarkShotLibrary.quotes(in: container)
        let favorites = all.filter(\.isFavorite)
        guard let quote = (favorites.isEmpty ? all : favorites).randomElement() else {
            return .result(value: nil, dialog: IntentDialog(LocalizedStringResource("아직 밑줄 친 문장이 없어요.", comment: "Siri: no sentences yet")))
        }
        let source = quote.book?.title ?? ""
        let dialog = source.isEmpty
            ? IntentDialog(stringLiteral: quote.text)
            : IntentDialog(LocalizedStringResource("\(quote.text) (\(source))", comment: "Siri: a sentence followed by its book title in parentheses"))
        return .result(value: QuoteEntity(quote), dialog: dialog)
    }
}

/// 단어로 문장을 찾는다.
struct FindQuotesIntent: AppIntent {
    static let title = LocalizedStringResource("문장 찾기", comment: "Siri: find saved sentences by a word")
    static let description = IntentDescription(
        LocalizedStringResource("밑줄 친 문장과 책 제목에서 단어를 찾습니다.", comment: "Siri: find sentences description")
    )

    @Parameter(title: LocalizedStringResource("찾을 말", comment: "Siri: search word parameter"),
               requestValueDialog: IntentDialog(LocalizedStringResource("어떤 말을 찾을까요?", comment: "Siri: ask what to search")))
    var query: String

    @Dependency private var container: ModelContainer

    func perform() async throws -> some IntentResult & ReturnsValue<[QuoteEntity]> & ProvidesDialog {
        let found = BookmarkShotLibrary.search(query, in: container)
        let dialog = found.isEmpty
            ? IntentDialog(LocalizedStringResource("‘\(query)’이 들어간 문장이 없어요.", comment: "Siri: nothing found. Argument is the search word"))
            : IntentDialog(LocalizedStringResource("‘\(query)’이 들어간 문장 \(found.count)개를 찾았어요.", comment: "Siri: found. Arguments: search word, count"))
        return .result(value: found, dialog: dialog)
    }
}

/// 문장을 연다. Spotlight · Siri 결과를 누르면 여기로 온다.
struct OpenQuoteIntent: OpenIntent {
    static let title = LocalizedStringResource("문장 열기", comment: "Siri/Spotlight: open a saved sentence")

    @Parameter(title: LocalizedStringResource("밑줄 문장", comment: "Siri: sentence parameter"))
    var target: QuoteEntity

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        BookmarkShotRouter.shared.quoteID = PersistentIdentifier(intentID: target.id)
        return .result()
    }
}

// MARK: - Siri 문구

struct BookmarkShotShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanPageIntent(),
            phrases: [
                "Scan \(\.$book) with \(.applicationName)",
                "Scan a page with \(.applicationName)",
                "Underline a page with \(.applicationName)"
            ],
            shortTitle: "Scan a Page",
            systemImageName: "doc.viewfinder"
        )
        AppShortcut(
            intent: TodayQuoteIntent(),
            phrases: [
                "Read me a quote from \(.applicationName)",
                "\(.applicationName) quote of the day"
            ],
            shortTitle: "Quote of the Day",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: FindQuotesIntent(),
            phrases: [
                "Find a quote in \(.applicationName)",
                "Search \(.applicationName)"
            ],
            shortTitle: "Find Quotes",
            systemImageName: "text.magnifyingglass"
        )
    }
}

// MARK: - 읽기 · 색인

enum BookmarkShotLibrary {
    /// 최근에 밑줄 친 것부터.
    static func quotes(in container: ModelContainer) -> [Quote] {
        let descriptor = FetchDescriptor<Quote>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? ModelContext(container).fetch(descriptor)) ?? []
    }

    /// 문장 · 메모 · 책 제목 · 저자에서 찾는다(대소문자 · 악센트 무시).
    static func search(_ raw: String, in container: ModelContainer) -> [QuoteEntity] {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        func matches(_ s: String?) -> Bool {
            s?.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
        return quotes(in: container)
            .filter { matches($0.text) || matches($0.note) || matches($0.book?.title) || matches($0.book?.author) }
            .map(QuoteEntity.init)
    }

    /// Spotlight 에 싣는 문장을 지금 것에 맞춘다. 앱을 열 때와 뒤로 보낼 때 부른다.
    static func reindex(_ container: ModelContainer) async {
        guard #available(iOS 18.0, *) else { return }
        let entities = quotes(in: container).filter { !$0.text.isEmpty }.map(QuoteEntity.init)
        let index = CSSearchableIndex.default()
        try? await index.deleteAppEntities(ofType: QuoteEntity.self)
        try? await index.indexAppEntities(entities)
    }
}
