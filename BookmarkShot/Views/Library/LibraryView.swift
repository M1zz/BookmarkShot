//
//  LibraryView.swift
//  밑줄
//
//  서재: 등록한 책들을 표지 그리드로 보여준다. 상단에 지금까지 모은 책 권수를 센다.
//

import SwiftUI
import SwiftData
import LeeoKit

struct LibraryView: View {
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @State private var showAddBook = false
    @Environment(\.foldLayout) private var fold
    /// 펼친 화면에서는 책을 밀어 넣지 않고 오른쪽 판에 세운다 (→ FoldPanes.swift)
    @Environment(FoldPick.self) private var foldPick: FoldPick?

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("지금까지 \(books.count)권을 모았어요")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(books) { book in
                                    if fold.isUnfolded, let foldPick {
                                        Button {
                                            foldPick.book = book
                                        } label: {
                                            BookCoverCell(book: book)
                                        }
                                        .buttonStyle(.plain)
                                        .foldPicked(foldPick.book == book)
                                    } else {
                                        NavigationLink(value: book) {
                                            BookCoverCell(book: book)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
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
                    .accessibilityLabel("책 추가")
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
            Button {
                showAddBook = true
            } label: {
                Label("첫 책 추가하기", systemImage: "camera.fill")
            }
            .buttonStyle(.brandPrimary)
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
    }
}

struct BookCoverCell: View {
    let book: Book
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
            HStack(spacing: 4) {
                Image(systemName: "quote.opening")
                    .imageScale(.small)
                Text("\(book.quoteCount)")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(width: 110, alignment: .leading)
        // VoiceOver: 표지·제목·숫자를 따로 읽지 않고 '제목, 스크랩 N개' 한 번에
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(book.title + ", " + String(localized: "스크랩 \(book.quoteCount)개"))
    }
}
