//
//  LibraryView.swift
//  책갈피샷
//
//  서재: 상단 세그먼트로 "책"(표지 그리드)과 "문장 책장"(즐겨찾기 수집)을 전환한다.
//  - 책: 등록한 책들을 표지 그리드로. 책별로 스크랩한 문장이 모인다.
//  - 문장 책장: 즐겨찾기한 문장을 책장 슬롯에 채우며, 빈 칸과 다음 목표로 수집을 유도한다.
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case books = "책"
        case shelf = "문장 책장"
        var id: String { rawValue }
    }

    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @Query(filter: #Predicate<Quote> { $0.isFavorite },
           sort: \Quote.createdAt, order: .reverse)
    private var favorites: [Quote]

    @State private var mode: Mode = .books
    @State private var showAddBook = false

    private let bookColumns = [GridItem(.adaptive(minimum: 110), spacing: 16)]
    private let shelfColumns = [GridItem(.adaptive(minimum: 84), spacing: 12)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("보기", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Group {
                    switch mode {
                    case .books: booksContent
                    case .shelf: shelfContent
                    }
                }
            }
            .navigationTitle("서재")
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book)
            }
            .navigationDestination(for: Quote.self) { quote in
                QuoteDetailView(quote: quote)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if mode == .books {
                        Button {
                            showAddBook = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddBook) {
                AddBookView()
            }
        }
    }

    // MARK: - 책 그리드

    @ViewBuilder
    private var booksContent: some View {
        if books.isEmpty {
            booksEmptyState
        } else {
            ScrollView {
                LazyVGrid(columns: bookColumns, spacing: 20) {
                    ForEach(books) { book in
                        NavigationLink(value: book) {
                            BookCoverCell(book: book)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }

    private var booksEmptyState: some View {
        ContentUnavailableView {
            Label("아직 등록된 책이 없어요", systemImage: "books.vertical")
        } description: {
            Text("표지를 한 장 찍는 것으로 시작해 보세요.\n제목과 저자는 자동으로 읽어드려요.")
        } actions: {
            Button("첫 책 추가하기") { showAddBook = true }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - 문장 책장

    private let milestones = [3, 5, 10, 20, 30, 50, 100]
    private var nextMilestone: Int {
        milestones.first { $0 > favorites.count } ?? (((favorites.count / 50) + 1) * 50)
    }
    private var slotCount: Int { max(nextMilestone, 6) }

    private var shelfContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                shelfHeader

                LazyVGrid(columns: shelfColumns, spacing: 18) {
                    ForEach(0..<slotCount, id: \.self) { index in
                        shelfSlot(at: index)
                    }
                }
                .padding(.horizontal)

                if favorites.isEmpty {
                    shelfEncouragement
                }
            }
            .padding(.vertical)
        }
    }

    private var shelfHeader: some View {
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

    @ViewBuilder
    private func shelfSlot(at index: Int) -> some View {
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

    private var shelfEncouragement: some View {
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

struct BookCoverCell: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let data = book.coverImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        LinearGradient(colors: [.orange.opacity(0.7), .yellow.opacity(0.5)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        Text(book.title.prefix(12))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(6)
                    }
                }
            }
            .frame(width: 110, height: 154)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            Text(book.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            HStack(spacing: 4) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 9))
                Text("\(book.quoteCount)")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(width: 110, alignment: .leading)
    }
}
