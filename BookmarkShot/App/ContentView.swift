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
    @Bindable private var router = BookmarkShotRouter.shared
    @Environment(\.modelContext) private var modelContext
    /// 스크린샷 데모(DEBUG)에서 구절 스크랩 화면을 바로 연다
    @State private var screenshotScanBook: Book?
    @Query private var books: [Book]
    /// 아이폰 듀오를 폈을 때 오른쪽 판에 세울 책 · 스크랩 (→ FoldPanes.swift)
    @State private var foldPick = FoldPick()
    @State private var purchases = Purchases.shared
    /// 잠긴 위젯을 눌러 들어온 페이월
    @State private var paywallFeature: BookmarkShotFeature?
    /// 구독 6개월째 · 갱신 7일 전의 '구독 졸업' 제안
    @State private var showsGraduation = false
    /// 할인 배너에서 연 페이월
    @State private var showsSalePaywall = false

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
            // 넓은 아이패드 · 펼친 듀오에서 오른쪽 판에 책 하나 · 문장 하나를 세워 둔다
            if ScreenshotMode.isActive {
                foldPick.book = ScreenshotMode.pageBook(in: books)
                foldPick.quote = quotes.max { $0.createdAt < $1.createdAt }
            }
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
        // Siri · Spotlight 에서 고른 문장 · 스캔할 책 (→ BookmarkShotIntents.swift)
        .sheet(item: $router.quoteID) { id in
            if let quote = modelContext.model(for: id) as? Quote {
                NavigationStack { QuoteDetailView(quote: quote) }
            }
        }
        .sheet(item: $router.scanBookID) { id in
            if let book = modelContext.model(for: id) as? Book {
                ScanPageView(book: book)
            }
        }
        .paywall(for: $paywallFeature)
        // 할인 기간이면 앱을 연 뒤 한 번 할인 배너를 띄운다. 단추는 요금제를 연다 (LeeoKit).
        .leeoSaleBanner { showsSalePaywall = true }
        .sheet(isPresented: $showsSalePaywall) { PaywallView() }
        .sheet(isPresented: $showsGraduation) {
            LeeoGraduationOfferView(graduate: purchases.product(BookmarkShotEntitlement.graduateID)) {
                await purchases.refresh()
            }
        }
        .onChange(of: purchases.graduationIsDue, initial: true) { _, due in
            guard due, !showsGraduation, paywallFeature == nil, !showSupport else { return }
            purchases.markGraduationOffered()
            showsGraduation = true
        }
        // 문장을 고치는 동안 글자마다 위젯 · 알림을 다시 만들지 않는다 — 손을 멈추면 한 번.
        // (예전에는 글자마다 모든 문장을 JSON 으로 써 위젯을 새로 그리게 하고, 알림 14개를 고르느라
        //  문장 전체를 14번 정렬했다. 메인 스레드에서.)
        .task(id: widgetSignature) {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            syncWidget()
        }
        // 시트 · 알림창이 접힌 선을 비킨다. 접혀 있으면 아무것도 바뀌지 않는다.
        .foldAware()
        // 유료가 되면 콘페티, 모든 사용자가 한 번은 감사를 받는다 (LeeoStore 가 판정한다).
        // 스크린샷 데모에서는 띄우지 않는다 — 스토어 그림에 하트가 찍히지 않게.
        .modifier(CelebrationsUnlessScreenshot())
    }

    /// 스크랩 수·즐겨찾기·본문 변화를 담은 가벼운 시그니처 (변화 감지용)
    private var widgetSignature: [String] {
        quotes.map { "\($0.persistentModelID.hashValue)|\($0.isFavorite)|\($0.text.count)|\($0.reviewBias)" }
    }

    private func syncWidget() {
        SharedQuoteStore.save(from: quotes)
        // 알림에 실을 문장도 같은 때 다시 만든다 (지운 문장이 알림으로 오지 않게)
        DailyReminder.reschedule(with: quotes)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Book.self, Quote.self], inMemory: true)
}

private struct CelebrationsUnlessScreenshot: ViewModifier {
    func body(content: Content) -> some View {
        if ScreenshotMode.isActive {
            content
        } else {
            content.leeoCelebrations(appName: BookmarkShotSpec.appName)
        }
    }
}
