//
//  ScanPageView.swift
//  책갈피샷
//
//  구절 스크랩 플로우: 페이지 촬영 → 영역 선택 → OCR → 손가락 하이라이트 → 문장/페이지 확인 → 저장
//

import SwiftUI
import SwiftData

struct ScanPageView: View {
    let book: Book

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private enum Step {
        case pickPhoto
        case selectRegion
        case processing
        case highlight
    }

    /// 하이라이트 안내 문구를 보여준 횟수 (처음 몇 번만 노출)
    @AppStorage("highlightHintShownCount") private var highlightHintShownCount = 0
    private let highlightHintMaxShows = 3

    @State private var step: Step = .pickPhoto
    @State private var pickerSource: ImagePicker.Source?
    @State private var rawImage: UIImage?
    @State private var corners: QuadCorners = .defaultInset
    @State private var pageImage: UIImage?
    @State private var ocrResult: OCRResult?
    @State private var extractedText: String = ""
    @State private var pageNumberText: String = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .pickPhoto:
                    pickPhotoStep
                case .selectRegion:
                    selectRegionStep
                case .processing:
                    processingStep
                case .highlight:
                    highlightStep
                }
            }
            .navigationTitle("구절 스크랩")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                if step == .selectRegion {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("구문 추출") { extractFromRegion() }
                    }
                }
                if step == .highlight {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장") { saveQuote() }
                            .disabled(extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { pickerSource != nil },
                set: { if !$0 { pickerSource = nil } }
            )) {
                if let source = pickerSource {
                    ImagePicker(source: source) { image in
                        // 촬영/선택 후 → 페이지 영역을 자동 추정한 값으로 영역 선택 화면 진입
                        rawImage = image
                        step = .selectRegion
                        Task {
                            corners = await DocumentFlattener.detectCorners(image) ?? .defaultInset
                        }
                    }
                    .ignoresSafeArea()
                }
            }
            .alert("인식 실패", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("확인") { step = .pickPhoto }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Steps

    private var pickPhotoStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "text.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("마음에 드는 구절이 있는\n페이지를 찍어주세요")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("페이지를 반듯하게 펴서 담은 뒤,\n원하는 문장을 손가락으로 스윽 문질러 골라낼 수 있어요.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            PhotoSourceButtons(title: "") { source in
                pickerSource = source
            }
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private var selectRegionStep: some View {
        if let rawImage {
            VStack(spacing: 0) {
                Text("페이지 모서리에 네 점을 맞춰주세요")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)

                RegionSelectionView(image: rawImage, corners: $corners)
                    .frame(maxHeight: .infinity)
                    .padding(8)
            }
        }
    }

    private var processingStep: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("글자를 읽고 있어요…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var highlightStep: some View {
        if let pageImage, let ocrResult {
            VStack(spacing: 0) {
                if highlightHintShownCount < highlightHintMaxShows {
                    Text("문장 위를 손가락으로 스윽 · 두 손가락으로 확대해 밑줄")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                        .transition(.opacity)
                }

                HighlightSelectionView(image: pageImage, ocr: ocrResult) { text in
                    extractedText = text
                }
                .frame(maxHeight: .infinity)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("추출된 문장", systemImage: "quote.opening")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Text("페이지")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            TextField("자동", text: $pageNumberText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 64)
                        }
                    }

                    TextEditor(text: $extractedText)
                        .frame(height: 72)
                        .padding(6)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(alignment: .center) {
                            if extractedText.isEmpty {
                                Text("아직 선택된 문장이 없어요")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                .padding()
            }
        }
    }

    // MARK: - Actions

    private func extractFromRegion() {
        guard let rawImage else { return }
        Task {
            // 선택한 영역만 원근 보정(종이처럼 펴기) 후 OCR
            let flattened = await DocumentFlattener.flatten(rawImage, corners: corners)
            pageImage = flattened
            await runOCR(on: flattened)
        }
    }

    private func runOCR(on image: UIImage) async {
        step = .processing
        do {
            let result = try await OCRService.recognizeText(in: image)
            guard !result.lines.isEmpty else {
                errorMessage = "사진에서 글자를 찾지 못했어요. 초점과 조명을 확인하고 다시 찍어주세요."
                return
            }
            ocrResult = result
            if let page = PageAnalyzer.guessPageNumber(from: result) {
                pageNumberText = String(page)
            }
            if highlightHintShownCount < highlightHintMaxShows {
                highlightHintShownCount += 1
            }
            step = .highlight
        } catch {
            errorMessage = "텍스트 인식 중 오류가 발생했어요. 다시 시도해 주세요."
        }
    }

    private func saveQuote() {
        let text = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let imageData = pageImage?.jpegData(compressionQuality: 0.6)
        let quote = Quote(
            text: text,
            pageNumber: Int(pageNumberText),
            pageImageData: imageData,
            book: book
        )
        modelContext.insert(quote)
        try? modelContext.save()
        dismiss()
    }
}
