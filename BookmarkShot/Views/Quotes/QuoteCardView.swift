//
//  QuoteCardView.swift
//  밑줄
//

import SwiftUI

struct QuoteCardView: View {
    let quote: Quote
    var showBookTitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "quote.opening")
                    .font(.caption)
                    .foregroundStyle(.tint)
                Text(quote.text)
                    .font(.subheadline)
                    .lineLimit(3)
            }
            HStack(spacing: 8) {
                if showBookTitle, let book = quote.book {
                    Text(book.title)
                        .lineLimit(1)
                }
                if let pageLabel = quote.pageLabel {
                    Text(pageLabel)
                }
                Spacer()
                if quote.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                }
                Text(quote.createdAt, format: .dateTime.month().day())
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
