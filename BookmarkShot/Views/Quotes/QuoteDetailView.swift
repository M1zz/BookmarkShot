//
//  QuoteDetailView.swift
//  책갈피샷
//
//  스크랩 상세: 문장 수정, 페이지, 메모, 즐겨찾기, 원본 사진 확인, 공유.
//

import SwiftUI
import SwiftData

struct QuoteDetailView: View {
    @Bindable var quote: Quote
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showOriginalImage = false

    private var pageBinding: Binding<String> {
        Binding(
            get: { quote.pageNumber.map(String.init) ?? "" },
            set: { quote.pageNumber = Int($0) }
        )
    }

    var body: some View {
        Form {
            Section("문장") {
                TextEditor(text: $quote.text)
                    .frame(minHeight: 120)
            }

            Section("정보") {
                if let book = quote.book {
                    LabeledContent("책", value: book.title)
                }
                HStack {
                    Text("페이지")
                    Spacer()
                    TextField("없음", text: pageBinding)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                Toggle(isOn: $quote.isFavorite) {
                    Label("즐겨찾기", systemImage: "heart")
                }
            }

            Section("메모") {
                TextEditor(text: $quote.note)
                    .frame(minHeight: 80)
                    .overlay(alignment: .topLeading) {
                        if quote.note.isEmpty {
                            Text("이 문장이 좋았던 이유를 남겨보세요")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }
                    }
            }

            if let data = quote.pageImageData, let image = UIImage(data: data) {
                Section("원본 사진") {
                    Button {
                        showOriginalImage = true
                    } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                ShareLink(item: shareText) {
                    Label("문장 공유하기", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    modelContext.delete(quote)
                    try? modelContext.save()
                    dismiss()
                } label: {
                    Label("스크랩 삭제", systemImage: "trash")
                }
            }
        }
        .navigationTitle("스크랩")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showOriginalImage) {
            if let data = quote.pageImageData, let image = UIImage(data: data) {
                NavigationStack {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    }
                    .navigationTitle("원본 사진")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("닫기") { showOriginalImage = false }
                        }
                    }
                }
            }
        }
        .onDisappear {
            try? modelContext.save()
        }
    }

    private var shareText: String {
        var parts = ["“\(quote.text)”"]
        if let book = quote.book {
            var source = "— \(book.title)"
            if !book.author.isEmpty { source += ", \(book.author)" }
            if let pageLabel = quote.pageLabel { source += " (\(pageLabel))" }
            parts.append(source)
        }
        return parts.joined(separator: "\n")
    }
}
