//
//  ContentView.swift
//  책갈피샷
//

import SwiftUI

struct ContentView: View {
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Book.self, Quote.self], inMemory: true)
}
