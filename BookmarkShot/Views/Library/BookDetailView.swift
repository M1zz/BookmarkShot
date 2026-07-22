//
//  BookDetailView.swift
//  밑줄
//
//  책 한 권의 스크랩 모음. 여기서 "구절 스크랩"으로 새 문장을 추가한다.
//

import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Bindable var book: Book
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showScanPage = false
    @State private var showDeleteConfirm = false

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 16) {
                    if let data = book.coverImageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.headline)
                        if !book.author.isEmpty {
                            Text(book.author)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let isbn = book.isbn {
                            Text("ISBN \(isbn)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Text("스크랩 \(book.quoteCount)개")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }
                .listRowSeparator(.hidden)
            }

            Section {
                if book.sortedQuotes.isEmpty {
                    Text("아직 스크랩한 문장이 없어요.\n아래 버튼으로 첫 구절을 담아보세요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    ForEach(book.sortedQuotes) { quote in
                        NavigationLink {
                            QuoteDetailView(quote: quote)
                        } label: {
                            QuoteCardView(quote: quote, showBookTitle: false)
                        }
                    }
                    .onDelete(perform: deleteQuotes)
                }
            } header: {
                Text("스크랩한 문장")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                showScanPage = true
            } label: {
                Label("구절 스크랩", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.brandPrimary)
            .padding(.horizontal, Theme.screenPadding)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showScanPage) {
            ScanPageView(book: book)
        }
        .confirmationDialog("이 책과 스크랩을 모두 삭제할까요?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                modelContext.delete(book)
                try? modelContext.save()
                dismiss()
            }
        }
    }

    private func deleteQuotes(at offsets: IndexSet) {
        let quotes = book.sortedQuotes
        for index in offsets {
            modelContext.delete(quotes[index])
        }
        try? modelContext.save()
    }
}
