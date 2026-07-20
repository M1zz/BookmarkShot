//
//  QuoteShelfView.swift
//  책갈피샷
//
//  "문장 책장" — 즐겨찾기한 문장을 책장 슬롯에 하나씩 꽂아 모으는 화면.
//  빈 칸을 일부러 보여주고 다음 목표를 제시해, 좋아하는 문장을 계속 모으고 싶게 만든다.
//

import SwiftUI
import SwiftData

struct QuoteShelfView: View {
    @Query(filter: #Predicate<Quote> { $0.isFavorite },
           sort: \Quote.createdAt, order: .reverse)
    private var favorites: [Quote]

    /// 다음으로 도달할 목표 개수
    private let milestones = [3, 5, 10, 20, 30, 50, 100]
    private var nextMilestone: Int {
        milestones.first { $0 > favorites.count } ?? (((favorites.count / 50) + 1) * 50)
    }

    /// 책장에 그릴 슬롯 수 (현재 채운 것 + 채울 빈 칸이 항상 보이도록 다음 목표까지)
    private var slotCount: Int { max(nextMilestone, 6) }

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    progressHeader

                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(0..<slotCount, id: \.self) { index in
                            slot(at: index)
                        }
                    }
                    .padding(.horizontal)

                    if favorites.isEmpty {
                        encouragement
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("문장 책장")
            .navigationDestination(for: Quote.self) { quote in
                QuoteDetailView(quote: quote)
            }
        }
    }

    // MARK: - Header

    private var progressHeader: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(favorites.count)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                Text("문장을 모았어요")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            let remaining = max(nextMilestone - favorites.count, 0)
            ProgressView(value: Double(favorites.count), total: Double(nextMilestone))
                .tint(.orange)
                .padding(.horizontal, 40)

            Text(remaining > 0
                 ? "다음 목표 \(nextMilestone)문장까지 \(remaining)개 남았어요"
                 : "새로운 목표를 향해 계속 모아볼까요?")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Slot

    @ViewBuilder
    private func slot(at index: Int) -> some View {
        if index < favorites.count {
            let quote = favorites[index]
            NavigationLink(value: quote) {
                filledSlot(quote)
            }
            .buttonStyle(.plain)
        } else {
            emptySlot
        }
    }

    private func filledSlot(_ quote: Quote) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "quote.opening")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.9))
            Text(quote.text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            if let title = quote.book?.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .padding(8)
        .frame(width: 84, height: 116, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(spineGradient(for: quote))
        )
        .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
    }

    private var emptySlot: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            .foregroundStyle(.tertiary)
            .frame(width: 84, height: 116)
            .overlay {
                Image(systemName: "plus")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
    }

    /// 문장 텍스트로 색을 골라 책등처럼 다양한 색이 되도록
    private func spineGradient(for quote: Quote) -> LinearGradient {
        let palette: [[Color]] = [
            [.orange, .red],
            [.teal, .blue],
            [.purple, .indigo],
            [.green, .mint],
            [.pink, .orange],
            [.brown, .orange]
        ]
        let idx = abs(quote.text.hashValue) % palette.count
        return LinearGradient(colors: palette[idx],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Empty encouragement

    private var encouragement: some View {
        VStack(spacing: 8) {
            Text("아직 책장이 비어 있어요")
                .font(.subheadline.weight(.semibold))
            Text("마음에 드는 문장의 상세 화면에서\n♡ 즐겨찾기를 켜면 이 책장에 한 칸씩 채워져요.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
