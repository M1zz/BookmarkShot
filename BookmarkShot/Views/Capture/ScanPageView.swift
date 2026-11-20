//
//  ScanPageView.swift
//  밑줄
//
//  구절 스크랩 플로우: 페이지 촬영 → 영역 선택 → OCR → 손가락 하이라이트 → 문장/페이지 확인 → 저장
//
//  사진첩에서 여러 장을 고르면 한 장씩 차례로 같은 길을 간다 — 저장하거나 건너뛰면 다음 사진.
//  사진첩에 잠자던 책 사진을 한 번에 글귀로 꺼내는 길이다. 이미 꺼낸 사진은 다시 묻지 않는다 (→ ImportedPhotos).
//

import SwiftUI
import SwiftData
import PhotosUI

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
    /// 추출된 문장 칸 높이 — 큰 글자에서는 함께 키운다
    @ScaledMetric(relativeTo: .body) private var extractedHeight: CGFloat = 72
    @State private var purchases = Purchases.shared
    /// 무료 100개를 다 채웠을 때 페이월. 그은 문장 · 페이지는 이 화면에 그대로 남아 있다.
    @State private var paywallFeature: BookmarkShotFeature?
    /// 문장을 고르는 길. VoiceOver 가 켜져 있으면 목록으로 시작한다 (→ SentenceListView).
    @State private var pickMode: PickMode = UIAccessibility.isVoiceOverRunning ? .list : .swipe
    /// 저장하면 가볍게 떨린다
    @State private var savedCount = 0

    private enum PickMode: Hashable { case swipe, list }

    /// 사진첩에서 고른 것 (고르자마자 대기열로 옮긴다)
    @State private var pickedItems: [PhotosPickerItem] = []
    /// 아직 열지 않은 사진들
    @State private var queue: [PhotosPickerItem] = []
    /// 이번에 고른 사진 수 (이미 꺼낸 사진은 빼고)
    @State private var queueTotal = 0
    /// 지금 보고 있는 사진첩 사진. 저장하거나 건너뛰면 '꺼냄'으로 적는다.
    @State private var currentPhotoID: String?
    /// 이번에 건너뛴, 이미 꺼낸 사진 수
    @State private var alreadyImported = 0

    /// 대기열에서 몇 번째 사진인가 (1부터)
    private var queuePosition: Int { queueTotal - queue.count }
    private var isBatch: Bool { queueTotal > 1 }

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
            .navigationTitle(isBatch && step != .pickPhoto
                             ? String(localized: "사진 \(queuePosition)/\(queueTotal)")
                             : String(localized: "구절 스크랩"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Label("닫기", systemImage: "xmark") }
                }
                if isBatch, step == .selectRegion || step == .highlight {
                    ToolbarItem(placement: .bottomBar) {
                        Button { finishCurrentPhoto() } label: {
                            Label(queue.isEmpty ? String(localized: "이 사진 건너뛰고 마치기") : String(localized: "이 사진 건너뛰기"),
                                  systemImage: "forward")
                        }
                    }
                }
                if step == .selectRegion {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { extractFromRegion() } label: { Label("구문 추출", systemImage: "text.viewfinder") }
                    }
                }
                if step == .highlight {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { Task { await saveIfAllowed() } } label: { Label("저장", systemImage: "checkmark") }
                            .disabled(extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { pickerSource != nil },
                set: { if !$0 { pickerSource = nil } }
            )) {
                if let source = pickerSource {
                    ImagePicker(source: source) { begin(with: $0) }
                        .ignoresSafeArea()
                }
            }
            .sheet(item: $paywallFeature, onDismiss: {
                // 페이월에서 Plus 를 열고 돌아왔으면 방금 그은 문장을 바로 담는다
                if purchases.canAddQuote(having: quoteCount) { saveQuote() }
            }) { PaywallView(highlight: $0) }
            .alert("인식 실패", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("확인") {
                    // 여러 장을 꺼내는 중이면 다음 사진으로, 아니면 처음으로
                    if isBatch { finishCurrentPhoto() } else { step = .pickPhoto }
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task { await startScreenshotScene() }
        .onChange(of: pickedItems) { _, items in startQueue(items) }
        .sensoryFeedback(.success, trigger: savedCount)
        .sensoryFeedback(.error, trigger: errorMessage) { _, new in new != nil }
    }

    /// 스크린샷 데모(DEBUG): 페이지 사진을 고른 것처럼 영역 선택으로, highlight 장면이면 구문 추출까지 진행한다.
    private func startScreenshotScene() async {
        guard ScreenshotMode.opensScanPage, let photo = ScreenshotMode.pagePhoto else { return }
        rawImage = photo
        corners = await DocumentFlattener.detectCorners(photo) ?? .defaultInset
        step = .selectRegion
        if ScreenshotMode.scene == .highlight {
            extractFromRegion()
        }
    }

    // MARK: - Steps

    private var pickPhotoStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "text.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("마음에 드는 구절이 있는\n페이지를 찍어주세요")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("페이지를 반듯하게 펴서 담은 뒤,\n원하는 문장을 손가락으로 스윽 문질러 골라낼 수 있어요.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: 12) {
                Button {
                    pickerSource = .camera
                } label: {
                    Label("카메라로 찍기", systemImage: "camera.fill")
                }
                .buttonStyle(.brandPrimary)

                // 여러 장을 한 번에. 사진첩 전체 권한은 묻지 않는다 — 고른 사진만 앱에 온다.
                PhotosPicker(selection: $pickedItems, maxSelectionCount: nil,
                             selectionBehavior: .ordered, matching: .images, photoLibrary: .shared()) {
                    Label("사진첩에서 여러 장 꺼내기", systemImage: "photo.stack")
                }
                .buttonStyle(.brandSecondary)

                if alreadyImported > 0 {
                    Text("이미 꺼낸 사진 \(alreadyImported)장은 건너뛰었어요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Theme.screenPadding)
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
                Picker("고르는 방법", selection: $pickMode) {
                    Label("긋기", systemImage: "highlighter").tag(PickMode.swipe)
                    Label("목록", systemImage: "list.bullet").tag(PickMode.list)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 6)
                // 고르는 길을 바꾸면 처음부터 고른다 (두 길의 선택은 서로 모른다)
                .onChange(of: pickMode) { extractedText = "" }

                if pickMode == .swipe, highlightHintShownCount < highlightHintMaxShows {
                    Text("문장 위를 손가락으로 스윽 · 두 손가락으로 확대해 밑줄")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                        .transition(.opacity)
                }

                Group {
                    if pickMode == .swipe {
                        HighlightSelectionView(image: pageImage, ocr: ocrResult,
                                               preselectedText: ScreenshotMode.highlightText) { text in
                            extractedText = text
                        }
                    } else {
                        SentenceListView(ocr: ocrResult) { extractedText = $0 }
                    }
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
                        .frame(height: extractedHeight)
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

    /// 사진 한 장으로 시작한다 → 페이지 영역을 자동 추정한 값으로 영역 선택 화면.
    private func begin(with image: UIImage) {
        rawImage = image
        pageImage = nil
        ocrResult = nil
        extractedText = ""
        pageNumberText = ""
        corners = .defaultInset
        step = .selectRegion
        Task {
            let found = await DocumentFlattener.detectCorners(image)
            corners = found ?? .defaultInset
            announce(found != nil
                     ? String(localized: "페이지를 찾았어요. 구문 추출을 누르세요.")
                     : String(localized: "페이지 모서리를 찾지 못했어요. 책을 화면 가득 다시 찍거나 그대로 구문 추출을 누르세요."))
        }
    }

    /// 사진첩에서 고른 사진들을 대기열에 세운다. 이미 꺼낸 사진은 뺀다.
    private func startQueue(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        let fresh = items.filter { !ImportedPhotos.contains($0.itemIdentifier) }
        alreadyImported = items.count - fresh.count
        pickedItems = []
        queue = fresh
        queueTotal = fresh.count
        if fresh.isEmpty {
            announce(String(localized: "고른 사진은 모두 이미 꺼냈어요."))
        } else {
            openNextPhoto()
        }
    }

    /// 대기열의 다음 사진을 연다. 못 읽은 사진은 건너뛴다.
    private func openNextPhoto() {
        guard !queue.isEmpty else { dismiss(); return }
        let item = queue.removeFirst()
        currentPhotoID = item.itemIdentifier
        step = .processing
        Task {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                begin(with: image)
                if isBatch { announce(String(localized: "사진 \(queuePosition)/\(queueTotal)")) }
            } else {
                finishCurrentPhoto()
            }
        }
    }

    /// 지금 사진을 끝낸다(저장했거나 건너뜀). 사진첩 사진이면 '꺼냄'으로 적고 다음 사진으로.
    private func finishCurrentPhoto() {
        ImportedPhotos.insert(currentPhotoID)
        currentPhotoID = nil
        if queue.isEmpty { dismiss() } else { openNextPhoto() }
    }

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
                errorMessage = String(localized: "사진에서 글자를 찾지 못했어요. 초점과 조명을 확인하고 다시 찍어주세요.")
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
            announce(pageNumberText.isEmpty
                     ? String(localized: "글을 \(result.lines.count)줄 읽었어요.")
                     : String(localized: "\(pageNumberText)쪽, 글을 \(result.lines.count)줄 읽었어요."))
        } catch {
            errorMessage = String(localized: "텍스트 인식 중 오류가 발생했어요. 다시 시도해 주세요.")
        }
    }

    private var quoteCount: Int { (try? modelContext.fetchCount(FetchDescriptor<Quote>())) ?? 0 }

    /// 무료 한도(문장 100개)를 넘으면 페이월을 먼저. 칸을 아직 모르면 App Store 에 물어보고 정한다.
    private func saveIfAllowed() async {
        if !purchases.isKnown { await purchases.refresh() }
        if purchases.canAddQuote(having: quoteCount) {
            saveQuote()
        } else {
            paywallFeature = .quotes
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
        savedCount += 1
        finishCurrentPhoto()
    }

    /// VoiceOver 로 지금 일을 알린다. 보이지 않아도 찍기 · 읽기가 어떻게 됐는지 안다.
    private func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}

/// 이미 글귀로 꺼낸 사진첩 사진. 같은 사진을 또 고르면 대기열에서 뺀다.
/// 사진첩의 식별자만 적는다 (사진 자체는 저장하지 않는다).
enum ImportedPhotos {
    private static let key = "importedPhotoIDs"

    static func contains(_ id: String?) -> Bool {
        guard let id else { return false }
        return Set(UserDefaults.standard.stringArray(forKey: key) ?? []).contains(id)
    }

    static func insert(_ id: String?) {
        guard let id else { return }
        var ids = UserDefaults.standard.stringArray(forKey: key) ?? []
        guard !ids.contains(id) else { return }
        ids.append(id)
        UserDefaults.standard.set(ids, forKey: key)
    }
}
