//
//  QuoteShareCard.swift
//  밑줄
//
//  문장을 SNS에 올릴 수 있는 한 장의 카드 이미지로 렌더링한다.
//  DailyReviewView / QuoteDetailView 의 "이미지로 공유"에서 사용.
//

import SwiftUI

/// 공유용 문장 카드. ImageRenderer로 UIImage로 굽는다.
struct QuoteShareCard: View {
    let text: String
    let bookTitle: String
    let author: String
    let pageLabel: String?

    /// 카드 폭(포인트). scale 3배로 구우면 약 1080pt 폭 이미지가 된다.
    static let cardWidth: CGFloat = 360

    private var paperGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.99, green: 0.96, blue: 0.90),
                     Color(red: 0.96, green: 0.91, blue: 0.82)],
            startPoint: .top, endPoint: .bottom
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: "quote.opening")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Color.accentColor)

            Text(text)
                .font(.system(size: 25, weight: .medium, design: .serif))
                .foregroundStyle(Theme.ink)
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)

            if !bookTitle.isEmpty || !author.isEmpty || pageLabel != nil {
                VStack(alignment: .leading, spacing: 3) {
                    if !bookTitle.isEmpty {
                        Text(bookTitle)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    HStack(spacing: 6) {
                        if !author.isEmpty { Text(author) }
                        if let pageLabel { Text(pageLabel).foregroundStyle(.tertiary) }
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                }
            }

            Divider().overlay(Theme.ink.opacity(0.15))

            HStack(spacing: 6) {
                Image(systemName: "camera.viewfinder")
                    .foregroundStyle(Color.accentColor)
                Text("밑줄")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(34)
        .frame(width: Self.cardWidth, alignment: .leading)
        .background(paperGradient)
    }
}

enum QuoteShareRenderer {
    /// 카드를 고해상도 PNG UIImage로 렌더링. 실패 시 nil.
    @MainActor
    static func image(text: String,
                      bookTitle: String,
                      author: String,
                      pageLabel: String?) -> UIImage? {
        let card = QuoteShareCard(text: text,
                                  bookTitle: bookTitle,
                                  author: author,
                                  pageLabel: pageLabel)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage
    }
}
