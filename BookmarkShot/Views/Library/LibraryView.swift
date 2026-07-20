//
//  LibraryView.swift
//  책갈피샷
//
//  서재: 등록한 책들을 표지 그리드로 보여준다. 책별로 스크랩한 문장이 모인다.
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @State private var showAddBook = false

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
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
            .navigationTitle("서재")
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddBook = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddBook) {
                AddBookView()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("아직 등록된 책이 없어요", systemImage: "books.vertical")
        } description: {
            Text("표지를 한 장 찍는 것으로 시작해 보세요.\n제목과 저자는 자동으로 읽어드려요.")
        } actions: {
            Button("첫 책 추가하기") { showAddBook = true }
                .buttonStyle(.borderedProminent)
        }
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
