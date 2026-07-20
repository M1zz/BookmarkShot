//
//  BookmarkShotWidget.swift
//  BookmarkShotWidget
//
//  "오늘의 문장" 위젯.
//  App Group에 저장된 스크랩 스냅샷에서 날짜 기반으로 매일 한 문장을 고른다.
//  즐겨찾기한 문장이 있으면 그중에서, 없으면 전체에서 고른다 → 즐겨찾기가 홈화면에 보이는 보상.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct QuoteEntry: TimelineEntry {
    let date: Date
    let quote: SharedQuote?
    let total: Int
}

struct Provider: TimelineProvider {

    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(date: Date(), quote: .sample, total: 1)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuoteEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuoteEntry>) -> Void) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        // 오늘부터 일주일치 엔트리를 미리 만들어 매일 자정에 문장이 바뀌도록 한다.
        var entries: [QuoteEntry] = []
        for dayOffset in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) {
                entries.append(entry(for: day))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// 특정 날짜의 "오늘의 문장" 계산
    private func entry(for date: Date) -> QuoteEntry {
        let all = SharedQuoteStore.load()
        let favorites = all.filter { $0.isFavorite }
        let pool = favorites.isEmpty ? all : favorites

        guard !pool.isEmpty else {
            return QuoteEntry(date: date, quote: nil, total: 0)
        }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        let index = day % pool.count
        return QuoteEntry(date: date, quote: pool[index], total: pool.count)
    }
}

// MARK: - View

struct BookmarkShotWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: QuoteEntry

    var body: some View {
        Group {
            if let quote = entry.quote {
                quoteBody(quote)
            } else {
                emptyBody
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.99, green: 0.96, blue: 0.90),
                         Color(red: 0.96, green: 0.91, blue: 0.82)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    private func quoteBody(_ quote: SharedQuote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.caption)
                .foregroundStyle(.orange)

            Text(quote.text)
                .font(family == .systemSmall ? .caption : .callout)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(family == .systemSmall ? 5 : (family == .systemLarge ? 10 : 4))
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            if !quote.bookTitle.isEmpty {
                HStack(spacing: 4) {
                    Text("— \(quote.bookTitle)")
                        .lineLimit(1)
                    if let page = quote.pageLabel {
                        Text(page).foregroundStyle(.tertiary)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyBody: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed")
                .font(.title2)
                .foregroundStyle(.orange.opacity(0.7))
            Text("문장을 스크랩하면\n여기서 매일 만나요")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget

struct BookmarkShotWidget: Widget {
    let kind = "DailyQuoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            BookmarkShotWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("오늘의 문장")
        .description("스크랩한 문장을 매일 한 문장씩 만나요. 즐겨찾기한 문장이 있으면 그중에서 보여드려요.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct BookmarkShotWidgetBundle: WidgetBundle {
    var body: some Widget {
        BookmarkShotWidget()
    }
}

// MARK: - Preview sample

extension SharedQuote {
    static let sample = SharedQuote(
        text: "우리가 읽은 책이 우리를 만든다.",
        bookTitle: "책갈피샷",
        author: "",
        pageLabel: "p.1",
        isFavorite: true
    )
}
