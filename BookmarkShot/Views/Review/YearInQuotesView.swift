//
//  YearInQuotesView.swift
//  밑줄 (BookmarkShot)
//
//  올해의 문장: 한 해 동안 그은 문장을 돌아보고, 한 문장을 골라 회고 카드로 공유한다.
//  숫자(문장 · 책 · 가장 많이 그은 책) + 내가 고른 올해의 문장 한 줄. 카드는 기기 안에서 굽는다.
//

import SwiftUI
import SwiftData

struct YearInQuotesView: View {
    @Query(sort: \Quote.createdAt) private var allQuotes: [Quote]
    @Environment(\.dismiss) private var dismiss

    @State private var year = Calendar.current.component(.year, from: .now)
    /// 올해의 문장으로 고른 것. 처음엔 즐겨찾기 중 가장 최근, 없으면 가장 최근 문장.
    @State private var chosen: Quote?
    @State private var cardImage: UIImage?

    private var quotes: [Quote] {
        allQuotes.filter { Calendar.current.component(.year, from: $0.createdAt) == year }
    }

    private var years: [Int] {
        Array(Set(allQuotes.map { Calendar.current.component(.year, from: $0.createdAt) })).sorted(by: >)
    }

    private var stats: YearStats { YearStats(year: year, quotes: quotes) }

    var body: some View {
        NavigationStack {
            List {
                if years.count > 1 {
                    Picker("연도", selection: $year) {
                        ForEach(years, id: \.self) { Text($0, format: .number.grouping(.never)).tag($0) }
                    }
                }
                if quotes.isEmpty {
                    Text("이 해에 담은 문장이 없어요.").foregroundStyle(.secondary)
                } else {
                    Section {
                        if let cardImage {
                            Image(uiImage: cardImage)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                                .accessibilityLabel(Text(stats.summary(chosen: chosen)))
                            ShareLink(item: Image(uiImage: cardImage),
                                      preview: SharePreview(String(localized: "올해의 문장"), image: Image(uiImage: cardImage))) {
                                Label("회고 카드 공유", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                    Section {
                        ForEach(quotes.reversed()) { quote in
                            Button { chosen = quote } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Image(systemName: chosen == quote ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(chosen == quote ? Color.accentColor : .secondary)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(quote.text).lineLimit(3).foregroundStyle(.primary)
                                            .naturalDirection(of: quote.text)
                                        if let title = quote.book?.title {
                                            Text(title).font(.footnote).foregroundStyle(.secondary)
                                                .naturalDirection(of: title)
                                        }
                                    }
                                }
                            }
                            .accessibilityAddTraits(chosen == quote ? .isSelected : [])
                        }
                    } header: {
                        Text("올해의 문장 고르기")
                    }
                }
            }
            .navigationTitle(String(localized: "\(year.formatted(.number.grouping(.never))) 나의 문장"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Label("닫기", systemImage: "xmark") }
                }
            }
            .task(id: year) {
                chosen = quotes.last { $0.isFavorite } ?? quotes.last
            }
            .task(id: chosen?.persistentModelID) {
                cardImage = YearCardRenderer.image(stats: stats, chosen: chosen)
            }
        }
    }
}

/// 한 해의 숫자.
struct YearStats {
    let year: Int
    let quoteCount: Int
    let bookCount: Int
    /// 가장 많이 그은 책과 그 문장 수
    let topBook: (title: String, count: Int)?

    init(year: Int, quotes: [Quote]) {
        self.year = year
        quoteCount = quotes.count
        let byBook = Dictionary(grouping: quotes.compactMap { $0.book?.title }, by: { $0 }).mapValues(\.count)
        bookCount = byBook.count
        topBook = byBook.max { ($0.value, $1.key) < ($1.value, $0.key) }.map { ($0.key, $0.value) }
    }

    /// VoiceOver 가 카드 대신 읽는 한 줄
    func summary(chosen: Quote?) -> String {
        var parts = [String(localized: "\(year.formatted(.number.grouping(.never)))년, 책 \(bookCount)권에서 문장 \(quoteCount)개를 담았어요.")]
        if let chosen { parts.append("“\(chosen.text)”") }
        return parts.joined(separator: " ")
    }
}

/// 공유용 회고 카드. 문장 카드와 같은 종이 느낌.
struct YearCard: View {
    let stats: YearStats
    let chosen: Quote?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(stats.year, format: .number.grouping(.never))
                .font(.system(size: 54, weight: .heavy, design: .serif))
                .foregroundStyle(Color.accentColor)
            Text("올해 내가 그은 문장")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)

            HStack(spacing: 28) {
                number(stats.quoteCount, String(localized: "문장"))
                number(stats.bookCount, String(localized: "책"))
            }

            if let top = stats.topBook {
                VStack(alignment: .leading, spacing: 2) {
                    Text("가장 많이 그은 책").font(.system(size: 12)).foregroundStyle(.secondary)
                    Text(top.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                        .naturalDirection(of: top.title)
                }
            }

            if let chosen {
                Divider().overlay(Theme.ink.opacity(0.15))
                Text("올해의 문장").font(.system(size: 12)).foregroundStyle(.secondary)
                Text("“\(chosen.text)”")
                    .font(.system(size: 21, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .naturalDirection(of: chosen.text)
                if let title = chosen.book?.title {
                    Text("— \(title)").font(.system(size: 14)).foregroundStyle(.secondary)
                        .naturalDirection(of: title)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "camera.viewfinder").foregroundStyle(Color.accentColor)
                Text("밑줄").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(34)
        .frame(width: QuoteShareCard.cardWidth, alignment: .leading)
        .background(LinearGradient(colors: [Color(red: 0.99, green: 0.96, blue: 0.90),
                                            Color(red: 0.96, green: 0.91, blue: 0.82)],
                                   startPoint: .top, endPoint: .bottom))
    }

    private func number(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value, format: .number)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text(label).font(.system(size: 13)).foregroundStyle(.secondary)
        }
    }
}

enum YearCardRenderer {
    @MainActor
    static func image(stats: YearStats, chosen: Quote?) -> UIImage? {
        // 화면 밖에서 굽는 그림이라 앱 언어의 방향을 직접 건넨다 (아랍어면 오른쪽부터)
        let renderer = ImageRenderer(content: YearCard(stats: stats, chosen: chosen)
            .environment(\.layoutDirection, .app))
        renderer.scale = 3
        return renderer.uiImage
    }
}
