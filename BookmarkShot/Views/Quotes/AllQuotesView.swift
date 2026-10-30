//
//  AllQuotesView.swift
//  밑줄
//
//  모든 책의 스크랩을 한곳에서: 검색 + 즐겨찾기 필터.
//

import SwiftUI
import SwiftData
import LeeoKit

struct AllQuotesView: View {
    @Query(sort: \Quote.createdAt, order: .reverse) private var quotes: [Quote]
    @State private var searchText = ""
    @State private var favoritesOnly = false
    @Environment(\.foldLayout) private var fold
    /// 펼친 화면에서는 스크랩을 밀어 넣지 않고 오른쪽 판에 세운다 (→ FoldPanes.swift)
    @Environment(FoldPick.self) private var foldPick: FoldPick?

    private var filteredQuotes: [Quote] {
        quotes.filter { quote in
            if favoritesOnly && !quote.isFavorite { return false }
            guard !searchText.isEmpty else { return true }
            let target = searchText.localizedLowercase
            return quote.text.localizedLowercase.contains(target)
                || quote.note.localizedLowercase.contains(target)
                || (quote.book?.title.localizedLowercase.contains(target) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if quotes.isEmpty {
                    ContentUnavailableView {
                        Label("스크랩한 문장이 없어요", systemImage: "quote.opening")
                    } description: {
                        Text("서재에서 책을 고르고 페이지를 찍어보세요.")
                    }
                } else if filteredQuotes.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(filteredQuotes) { quote in
                            if fold.isUnfolded, let foldPick {
                                Button {
                                    foldPick.quote = quote
                                } label: {
                                    QuoteCardView(quote: quote)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(foldPick.quote == quote ? Color.accentColor.opacity(0.14) : nil)
                                .accessibilityAddTraits(foldPick.quote == quote ? .isSelected : [])
                            } else {
                                NavigationLink {
                                    QuoteDetailView(quote: quote)
                                } label: {
                                    QuoteCardView(quote: quote)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("문장")
            .searchable(text: $searchText, prompt: "문장, 메모, 책 제목 검색")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        favoritesOnly.toggle()
                    } label: {
                        Image(systemName: favoritesOnly ? "heart.fill" : "heart")
                            .foregroundStyle(favoritesOnly ? .red : .accentColor)
                    }
                    .accessibilityLabel("즐겨찾기")
                    .accessibilityAddTraits(favoritesOnly ? .isSelected : [])
                }
            }
        }
    }
}
