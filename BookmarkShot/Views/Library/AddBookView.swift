//
//  AddBookView.swift
//  밑줄
//
//  책 등록 플로우: 표지 촬영 → 표지 OCR(제목/저자 추정) + 바코드(ISBN) 인식 → 확인 후 저장.
//  뒤표지 바코드가 함께 찍히면 ISBN도 자동으로 채워진다. 모든 필드는 수정 가능.
//

import SwiftUI
import SwiftData

struct AddBookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var pickerSource: ImagePicker.Source?
    @State private var coverImage: UIImage?
    @State private var isAnalyzing = false
    @State private var title = ""
    @State private var author = ""
    @State private var isbn = ""
    /// 표지에서 추정한 제목의 인식 신뢰도 (0~1). 자동으로 채워졌을 때만 표시.
    @State private var titleConfidence: Double?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        if let coverImage {
                            Image(uiImage: coverImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .shadow(radius: 3)
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.secondarySystemBackground))
                                .frame(height: 160)
                                .overlay {
                                    VStack(spacing: 8) {
                                        Image(systemName: "book.closed")
                                            .font(.largeTitle)
                                            .foregroundStyle(.tertiary)
                                        Text("표지를 찍으면 제목·저자를 자동으로 읽어와요")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                        }

                        if isAnalyzing {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("표지를 읽고 있어요…")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            PhotoSourceButtons { source in
                                pickerSource = source
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8))
                } header: {
                    Text("책 표지")
                } footer: {
                    Text("표지 대신(또는 표지와 함께) 뒤표지 바코드를 찍으면 ISBN까지 자동 인식돼요.")
                }

                Section("책 정보 (수정 가능)") {
                    TextField("제목", text: $title)
                    if let titleConfidence {
                        Label("제목 인식 신뢰도 \(Int((titleConfidence * 100).rounded()))%",
                              systemImage: "textformat.size")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    TextField("저자", text: $author)
                    TextField("ISBN (선택)", text: $isbn)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("책 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { saveBook() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: Binding(
                get: { pickerSource != nil },
                set: { if !$0 { pickerSource = nil } }
            )) {
                if let source = pickerSource {
                    ImagePicker(source: source) { image in
                        coverImage = image
                        Task { await analyzeCover(image) }
                    }
                    .ignoresSafeArea()
                }
            }
        }
    }

    // MARK: - Actions

    private func analyzeCover(_ image: UIImage) async {
        isAnalyzing = true
        defer { isAnalyzing = false }

        // 표지 OCR과 바코드 인식을 동시에 수행
        async let ocrTask = try? OCRService.recognizeText(in: image)
        async let isbnTask = OCRService.detectISBN(in: image)

        let (ocr, detectedISBN) = await (ocrTask, isbnTask)

        if let ocr {
            let guess = CoverAnalyzer.guess(from: ocr)
            if title.isEmpty, !guess.title.isEmpty {
                title = guess.title
                titleConfidence = guess.titleProbability
            }
            if author.isEmpty { author = guess.author }
        }
        if let detectedISBN, isbn.isEmpty {
            isbn = detectedISBN
        }
    }

    private func saveBook() {
        let book = Book(
            title: title.trimmingCharacters(in: .whitespaces),
            author: author.trimmingCharacters(in: .whitespaces),
            isbn: isbn.isEmpty ? nil : isbn,
            coverImageData: coverImage?.jpegData(compressionQuality: 0.7)
        )
        modelContext.insert(book)
        try? modelContext.save()
        dismiss()
    }
}
