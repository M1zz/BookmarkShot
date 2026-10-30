//
//  ContentView.swift
//  밑줄
//

import SwiftUI
import SwiftData
import LeeoKit

struct ContentView: View {
    /// 위젯 공유 저장소 동기화용. 스크랩·즐겨찾기 변화를 감지해 스냅샷을 갱신한다.
    @Query private var quotes: [Quote]

    /// 지원(설정) 시트 표시 여부
    @State private var showSupport = false

    @State private var selectedTab = ScreenshotMode.initialTab
    /// 스크린샷 데모(DEBUG)에서 구절 스크랩 화면을 바로 연다
    @State private var screenshotScanBook: Book?
    @Query private var books: [Book]
    /// 아이폰 듀오를 폈을 때 오른쪽 판에 세울 책 · 스크랩 (→ FoldPanes.swift)
    @State private var foldPick = FoldPick()

    var body: some View {
        TabView(selection: $selectedTab) {
            // 아이폰 듀오를 펴면 왼쪽(세로면 아래)에 이 탭, 오른쪽(위)에 고른 것 · 오늘의 문장이 선다.
            // 접혀 있거나 보통 아이폰이면 `FoldTab` 은 이 탭만 그린다. 지금 화면 그대로다.
            FoldTab { LibraryView() } result: { FoldBookResult() }
                .tabItem {
                    Label("서재", systemImage: "books.vertical.fill")
                }
                .tag(0)

            FoldTab { AllQuotesView() } result: { FoldQuoteResult() }
                .tabItem {
                    Label("문장", systemImage: "quote.opening")
                }
                .tag(1)

            DailyReviewView()
                .tabItem {
                    Label("오늘의 문장", systemImage: "sparkles")
                }
                .tag(2)
        }
        .foldTabBar(items: FoldTabs.items, selected: selectedTab) { selectedTab = $0 }
        .foldReviewTabRedirect(selectedTab: $selectedTab)
        .environment(foldPick)
        .onChange(of: books) { foldPick.forget(missingFrom: books, quotes) }
        .onChange(of: quotes) { foldPick.forget(missingFrom: books, quotes) }
        .sheet(item: $screenshotScanBook) { book in
            ScanPageView(book: book)
        }
        .task {
            ScreenshotMode.paintCovers(books)
            if ScreenshotMode.opensScanPage {
                screenshotScanBook = ScreenshotMode.pageBook(in: books)
            } else if ScreenshotMode.scene == .settings {
                showSupport = true
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showSupport = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .padding(10)
                    .background(.regularMaterial, in: Circle())
            }
            .accessibilityLabel("설정")
            .padding(.top, 8)
            .padding(.trailing, 12)
        }
        .sheet(isPresented: $showSupport) {
            BookmarkShotSupportView()
        }
        .task { syncWidget() }
        .onChange(of: widgetSignature) { syncWidget() }
        // 시트 · 알림창이 접힌 선을 비킨다. 접혀 있으면 아무것도 바뀌지 않는다.
        .foldAware()
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
