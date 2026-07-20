//
//  ContentView.swift
//  책갈피샷
//

import SwiftUI
import SwiftData

struct ContentView: View {
    /// 위젯 공유 저장소 동기화용. 스크랩·즐겨찾기 변화를 감지해 스냅샷을 갱신한다.
    @Query private var quotes: [Quote]

    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("서재", systemImage: "books.vertical.fill")
                }

            AllQuotesView()
                .tabItem {
                    Label("문장", systemImage: "quote.opening")
                }

            DailyReviewView()
                .tabItem {
                    Label("오늘의 문장", systemImage: "sparkles")
                }
        }
        .task { syncWidget() }
        .onChange(of: widgetSignature) { syncWidget() }
    }

    /// 스크랩 수·즐겨찾기·본문 변화를 담은 가벼운 시그니처 (변화 감지용)
    private var widgetSignature: [String] {
        quotes.map { "\($0.persistentModelID.hashValue)|\($0.isFavorite)|\($0.text.count)" }
    }

    private func syncWidget() {
        SharedQuoteStore.save(from: quotes)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Book.self, Quote.self], inMemory: true)
}
