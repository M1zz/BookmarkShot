//
//  FoldPanes.swift
//  밑줄
//
//  아이폰 듀오를 폈을 때 탭마다 접힌 선 양쪽에 무엇이 서는가.
//  자리 셈 · 시트 가드 · 탭 막대는 LeeoKit Fold 모듈이 하고, 여기는 이 앱의 짝만 정한다.
//
//  - 펴면 왼쪽(세로면 아래)은 서재 · 문장 중 고른 탭, 오른쪽(세로면 위)은 고른 것의 자세히다.
//    서재에서 책을 누르면 그 책의 스크랩, 문장에서 스크랩을 누르면 그 스크랩이 선다.
//  - 아무것도 고르지 않았으면 오른쪽에는 **오늘의 문장**이 선다. 그래서 오늘의 문장 탭은 따로 서지 않고,
//    펼친 탭 막대에는 둘만 선다.
//  - 접으면 지금 화면 그대로다. 고르는 쪽 탭은 `FoldSplitView` 안에서 같은 뷰로 남아,
//    펴고 접어도 보던 서재 · 검색어가 이어진다.
//

import SwiftUI
import SwiftData
import LeeoKit

// MARK: - 고른 것

/// 펼친 화면에서 오른쪽 판에 세울 책 · 스크랩. 접힌 화면에서는 쓰지 않는다(그때는 밀어 넣어 연다).
@MainActor
@Observable
final class FoldPick {
    var book: Book?
    var quote: Quote?

    /// 지워진 책 · 스크랩을 붙잡고 있으면 놓는다.
    func forget(missingFrom books: [Book], _ quotes: [Quote]) {
        if let book, !books.contains(book) { self.book = nil }
        if let quote, !quotes.contains(quote) { self.quote = nil }
    }
}

// MARK: - 탭

/// 펼친 화면의 탭 한 장: 왼쪽 고른 탭 | 오른쪽 고른 것(없으면 오늘의 문장).
struct FoldTab<Choose: View, Result: View>: View {
    @ViewBuilder let choose: () -> Choose
    @ViewBuilder let result: () -> Result

    var body: some View {
        FoldSplitView {
            choose()
        } result: {
            result()
                // 오른쪽 판 안에서는 접히지 않은 화면처럼 선다.
                .environment(\.foldLayout, .single)
        }
        .foldTabBarRoom()
    }
}

/// 서재 탭의 오른쪽 판: 고른 책의 스크랩, 없으면 오늘의 문장.
struct FoldBookResult: View {
    @Environment(FoldPick.self) private var pick

    var body: some View {
        if let book = pick.book {
            NavigationStack {
                BookDetailView(book: book)
                    .toolbar { FoldCloseItem { pick.book = nil } }
            }
            .id(book.persistentModelID)
        } else {
            DailyReviewView()
        }
    }
}

/// 문장 탭의 오른쪽 판: 고른 스크랩, 없으면 오늘의 문장.
struct FoldQuoteResult: View {
    @Environment(FoldPick.self) private var pick

    var body: some View {
        if let quote = pick.quote {
            NavigationStack {
                QuoteDetailView(quote: quote)
                    .toolbar { FoldCloseItem { pick.quote = nil } }
            }
            .id(quote.persistentModelID)
        } else {
            DailyReviewView()
        }
    }
}

/// 오른쪽 판을 오늘의 문장으로 되돌리는 단추.
private struct FoldCloseItem: ToolbarContent {
    let close: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(action: close) {
                Label("닫기", systemImage: "xmark")
            }
        }
    }
}

enum FoldTabs {
    /// 펼쳤을 때 고르는 쪽 판 바닥에 서는 칸. 오늘의 문장(2)은 오른쪽 판에 있으므로 빠진다.
    static var items: [FoldTabBar<Int>.Item] {
        [
            .init(value: 0, title: String(localized: "서재"), symbol: "books.vertical.fill"),
            .init(value: 1, title: String(localized: "문장"), symbol: "quote.opening"),
        ]
    }
}

// MARK: - 고르는 쪽 칸

extension View {
    /// 펼친 화면에서 고른 칸에 테두리를 세운다.
    func foldPicked(_ isPicked: Bool) -> some View {
        overlay {
            if isPicked {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentColor, lineWidth: 2.5)
                    .padding(-6)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }

    /// 펼쳤을 때 오늘의 문장 탭에 있었다면 서재로 옮긴다. 오늘의 문장은 그 오른쪽 판에 서 있다.
    func foldReviewTabRedirect(selectedTab: Binding<Int>) -> some View {
        modifier(FoldReviewTabRedirect(selectedTab: selectedTab))
    }
}

private struct FoldReviewTabRedirect: ViewModifier {
    @Environment(\.foldLayout) private var fold
    @Binding var selectedTab: Int

    func body(content: Content) -> some View {
        content.onChange(of: fold.isUnfolded, initial: true) { _, unfolded in
            if unfolded, selectedTab == 2 { selectedTab = 0 }
        }
    }
}
