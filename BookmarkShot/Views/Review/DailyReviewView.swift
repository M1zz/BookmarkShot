//
//  DailyReviewView.swift
//  책갈피샷
//
//  회고: 하루에 하나, 예전에 스크랩한 문장을 다시 만난다.
//  (날짜 기반 시드로 매일 같은 문장이 유지되고, 셔플로 다른 문장도 볼 수 있다)
//

import SwiftUI
import SwiftData

struct DailyReviewView: View {
    @Query private var quotes: [Quote]
    @State private var shuffleOffset = 0

    private var todaysQuote: Quote? {
        guard !quotes.isEmpty else { return nil }
        let sorted = quotes.sorted { $0.createdAt < $1.createdAt }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let index = (day + shuffleOffset) % sorted.count
        return sorted[index]
    }

    var body: some View {
        NavigationStack {
            Group {
                if let quote = todaysQuote {
                    reviewCard(for: quote)
                } else {
                    ContentUnavailableView {
                        Label("다시 만날 문장이 없어요", systemImage: "sparkles")
                    } description: {
                        Text("문장을 스크랩하면 매일 한 문장씩\n여기서 다시 만날 수 있어요.")
                    }
                }
            }
            .navigationTitle("오늘의 문장")
        }
    }

    private func reviewCard(for quote: Quote) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 32)

                VStack(spacing: 20) {
                    Image(systemName: "quote.opening")
                        .font(.title)
                        .foregroundStyle(.tint)

                    Text(quote.text)
                        .font(.title3.weight(.medium))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)

                    VStack(spacing: 4) {
                        if let book = quote.book {
                            Text(book.title)
                                .font(.subheadline.weight(.semibold))
                            if !book.author.isEmpty {
                                Text(book.author)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let pageLabel = quote.pageLabel {
                            Text(pageLabel)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal)

                HStack(spacing: 16) {
                    Button {
                        withAnimation { shuffleOffset += 1 }
                    } label: {
                        Label("다른 문장", systemImage: "shuffle")
                    }
                    .buttonStyle(.bordered)

                    ShareLink(item: shareText(for: quote)) {
                        Label("공유", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if !quote.note.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("그때 남긴 메모", systemImage: "pencil.line")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(quote.note)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal)
                }
            }
        }
    }

    private func shareText(for quote: Quote) -> String {
        var text = "“\(quote.text)”"
        if let book = quote.book {
            text += "\n— \(book.title)"
            if let pageLabel = quote.pageLabel { text += " (\(pageLabel))" }
        }
        return text
    }
}
