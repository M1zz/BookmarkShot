//
//  QuoteCardView.swift
//  밑줄
//

import SwiftUI

struct QuoteCardView: View {
    let quote: Quote
    var showBookTitle = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "quote.opening")
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text(quote.text)
                    .font(.subheadline)
                    .lineLimit(3)
                    .naturalDirection(of: quote.text)
            }
            HStack(spacing: 8) {
                if showBookTitle, let book = quote.book {
                    Text(book.title)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                        .naturalDirection(of: book.title)
                }
                if let pageLabel = quote.pageLabel {
                    Text(pageLabel)
                }
                Spacer()
                if quote.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .accessibilityLabel("즐겨찾기")
                }
                Text(quote.createdAt, format: .dateTime.month().day())
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
