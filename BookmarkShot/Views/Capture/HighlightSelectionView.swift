//
//  HighlightSelectionView.swift
//  밑줄
//
//  핵심 UX: 촬영한 페이지 위를 형광펜 긋듯 손가락으로 스윽 문지르면
//  손가락이 지나간 단어들만 골라 문장을 추출한다.
//  페이지는 화면을 최대한 넓게 쓰고, 핀치로 확대/이동해 밑줄을 정밀하게 그을 수 있다.
//

import SwiftUI

struct HighlightSelectionView: View {
    let image: UIImage
    let ocr: OCRResult
    /// 처음부터 골라 둘 문장 (스크린샷 데모용). 인식된 글에서 이 문장에 해당하는 단어들을 고른다.
    var preselectedText: String? = nil
    /// 선택된 텍스트가 바뀔 때마다 호출
    let onSelectionChange: (String) -> Void

    @State private var selectedWordIDs: Set<UUID> = []
    @State private var strokePoints: [CGPoint] = []
    @State private var eraseMode = false
    @State private var moveMode = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 확대/이동 상태
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    /// 손가락 터치 판정 여유 (단어 박스를 상하좌우로 넓혀서 판정). 확대할수록 좁힌다.
    private let touchTolerance: CGFloat = 10
    private let maxScale: CGFloat = 6

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let fitted = fittedRect(for: image.size, in: geo.size)
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .accessibilityHidden(true)

                    // 선택된 단어 하이라이트 + 현재 손가락 궤적 (미변환 로컬 좌표)
                    Canvas { context, _ in
                        for word in ocr.allWords where selectedWordIDs.contains(word.id) {
                            let rect = viewRect(for: word.box, fitted: fitted)
                                .insetBy(dx: -3, dy: -2)
                            context.fill(
                                Path(roundedRect: rect, cornerRadius: 4),
                                with: .color(.yellow.opacity(0.45))
                            )
                        }
                        if strokePoints.count > 1 {
                            var path = Path()
                            path.move(to: strokePoints[0])
                            for point in strokePoints.dropFirst() {
                                path.addLine(to: point)
                            }
                            context.stroke(
                                path,
                                with: .color(eraseMode ? .red.opacity(0.35) : .orange.opacity(0.35)),
                                style: StrokeStyle(lineWidth: 24 / scale, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                    // VoiceOver·음성 명령: 문지르기 대신 줄마다 하나의 요소로 두고, 두 번 탭하면 밑줄을 긋거나 지운다
                    ForEach(ocr.lines) { line in
                        let rect = viewRect(for: line.box, fitted: fitted)
                        Color.clear
                            .frame(width: max(rect.width, 1), height: max(rect.height, 1))
                            .position(x: rect.midX, y: rect.midY)
                            .allowsHitTesting(false)
                            .accessibilityElement()
                            .accessibilityLabel(line.text)
                            .accessibilityHint(Text("두 번 탭하면 밑줄을 긋거나 지웁니다."))
                            .accessibilityAddTraits(isSelected(line) ? [.isButton, .isSelected] : .isButton)
                            .accessibilityAction { toggle(line) }
                    }
                }
                .scaleEffect(scale, anchor: .center)
                .offset(offset)
                .contentShape(Rectangle())
                .gesture(dragGesture(fitted: fitted, center: center, container: geo.size))
                .simultaneousGesture(magnificationGesture())
            }
            .coordinateSpace(name: "canvas")
            .clipped()

            toolbar
        }
        .onAppear(perform: applyPreselection)
    }

    /// preselectedText 에 해당하는 단어를 고른다 (글자만 비교 — 띄어쓰기 · 문장부호 · 대소문자 무시).
    private func applyPreselection() {
        guard let target = preselectedText, selectedWordIDs.isEmpty else { return }
        func letters(_ text: String) -> String {
            String(text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil).unicodeScalars.filter { CharacterSet.letters.union(.decimalDigits).contains($0) }.map(Character.init))
        }
        let words = ocr.allWords
        var joined = ""
        var ranges: [Range<Int>] = []
        for word in words {
            let part = letters(word.text)
            ranges.append(joined.count..<(joined.count + part.count))
            joined += part
        }
        let goal = letters(target)
        guard goal.count >= 4 else { return }
        // 통째로 찾고, 안 되면 처음 · 끝 몇 글자로 찾는다 (인식이 한두 글자 틀려도 고를 수 있게).
        // 같은 말이 여러 번 나오면 길이가 문장과 가장 비슷한 짝을 고른다.
        func offsets(of needle: String) -> [Int] {
            var result: [Int] = []
            var searchRange = joined.startIndex..<joined.endIndex
            while let found = joined.range(of: needle, range: searchRange) {
                result.append(joined.distance(from: joined.startIndex, to: found.lowerBound))
                searchRange = joined.index(after: found.lowerBound)..<joined.endIndex
            }
            return result
        }
        var from = 0, to = 0
        if let exact = offsets(of: goal).first {
            from = exact
            to = exact + goal.count
        } else {
            var found: (Int, Int)?
            for probe in [12, 8, 5] where probe <= goal.count && found == nil {
                let starts = offsets(of: String(goal.prefix(probe)))
                let ends = offsets(of: String(goal.suffix(probe))).map { $0 + probe }
                let pairs = starts.flatMap { s in ends.filter { $0 > s }.map { (s, $0) } }
                found = pairs.min(by: { abs($0.1 - $0.0 - goal.count) < abs($1.1 - $1.0 - goal.count) })
            }
            guard let found else { return }
            (from, to) = found
        }
        selectedWordIDs = Set(zip(words, ranges).filter { $0.1.lowerBound < to && $0.1.upperBound > from }.map(\.0.id))
        notifySelection()
    }

    // MARK: - 제스처

    private func dragGesture(fitted: CGRect, center: CGPoint, container: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
            .onChanged { value in
                if moveMode {
                    var next = CGSize(width: lastOffset.width + value.translation.width,
                                      height: lastOffset.height + value.translation.height)
                    next = clampOffset(next, container: container)
                    offset = next
                } else {
                    let local = toLocal(value.location, center: center)
                    strokePoints.append(local)
                    updateSelection(at: local, fitted: fitted)
                }
            }
            .onEnded { _ in
                if moveMode {
                    lastOffset = offset
                } else {
                    strokePoints.removeAll()
                    notifySelection()
                }
            }
    }

    private func magnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.01 {
                    resetZoom()
                }
            }
    }

    /// 화면(canvas) 좌표 → 변환 전 로컬 좌표 (확대/이동 역변환)
    private func toLocal(_ point: CGPoint, center: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - center.x - offset.width) / scale + center.x,
                y: (point.y - center.y - offset.height) / scale + center.y)
    }

    /// 확대 상태에서 이미지가 화면 밖으로 과하게 벗어나지 않도록 이동량 제한
    private func clampOffset(_ proposed: CGSize, container: CGSize) -> CGSize {
        let maxX = max(0, container.width * (scale - 1) / 2)
        let maxY = max(0, container.height * (scale - 1) / 2)
        return CGSize(width: min(max(proposed.width, -maxX), maxX),
                      height: min(max(proposed.height, -maxY), maxY))
    }

    private func resetZoom() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            scale = 1
            offset = .zero
        }
        lastScale = 1
        lastOffset = .zero
    }

    // MARK: - 도구 모음

    private var toolbar: some View {
        HStack(spacing: 14) {
            Button {
                moveMode.toggle()
            } label: {
                Label(moveMode ? String(localized: "이동 중") : String(localized: "이동"),
                      systemImage: "hand.draw")
            }
            .tint(moveMode ? .blue : .accentColor)
            .accessibilityAddTraits(moveMode ? .isSelected : [])

            Button {
                eraseMode.toggle()
            } label: {
                Label(eraseMode ? String(localized: "지우개 ON") : String(localized: "지우개"),
                      systemImage: eraseMode ? "eraser.fill" : "eraser")
            }
            .tint(eraseMode ? .red : .accentColor)
            .accessibilityAddTraits(eraseMode ? .isSelected : [])
            .disabled(moveMode)

            if scale > 1.01 {
                Button {
                    resetZoom()
                } label: {
                    Label("원래대로", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                }
            }

            Spacer()

            Button {
                selectedWordIDs.removeAll()
                notifySelection()
            } label: {
                Label("전체 지우기", systemImage: "trash")
            }
            .disabled(selectedWordIDs.isEmpty)

            Button {
                selectedWordIDs = Set(ocr.allWords.map(\.id))
                notifySelection()
            } label: {
                Label("페이지 전체", systemImage: "doc.plaintext")
            }
        }
        .font(.footnote)
        .padding(.horizontal)
    }

    // MARK: - 선택 로직

    /// 줄의 단어가 모두 골라졌는지
    private func isSelected(_ line: RecognizedLine) -> Bool {
        !line.words.isEmpty && line.words.allSatisfy { selectedWordIDs.contains($0.id) }
    }

    /// 줄 하나를 통째로 고르거나 뺀다 (손가락 대신 VoiceOver·음성 명령으로 밑줄 긋기)
    private func toggle(_ line: RecognizedLine) {
        let ids = line.words.map(\.id)
        if isSelected(line) {
            selectedWordIDs.subtract(ids)
        } else {
            selectedWordIDs.formUnion(ids)
        }
        notifySelection()
    }

    private func updateSelection(at point: CGPoint, fitted: CGRect) {
        // 확대할수록 판정 여유를 좁혀 정밀하게
        let tolerance = touchTolerance / scale
        for word in ocr.allWords {
            let rect = viewRect(for: word.box, fitted: fitted)
                .insetBy(dx: -tolerance, dy: -tolerance)
            if rect.contains(point) {
                if eraseMode {
                    selectedWordIDs.remove(word.id)
                } else {
                    selectedWordIDs.insert(word.id)
                }
            }
        }
        notifySelection()
    }

    /// 읽기 순서대로 선택된 단어를 이어붙여 문장 생성
    private func notifySelection() {
        var parts: [String] = []
        for line in ocr.lines {
            let selectedInLine = line.words
                .filter { selectedWordIDs.contains($0.id) }
                .map(\.text)
            if !selectedInLine.isEmpty {
                parts.append(selectedInLine.joined(separator: " "))
            }
        }
        onSelectionChange(Self.join(parts))
    }

    /// 줄을 이어 붙인다. 띄어쓰기가 없는 글(중국어 · 일본어 · 태국어)은 줄 사이에 빈칸을 넣지 않는다.
    static func join(_ parts: [String]) -> String {
        var result = ""
        for part in parts {
            if let last = result.last, let first = part.first,
               !(isUnspacedScript(last) && isUnspacedScript(first)) {
                result.append(" ")
            }
            result += part
        }
        return result
    }

    private static func isUnspacedScript(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        switch scalar.value {
        case 0x3000...0x30FF,   // 일본어 가나 · 구두점
             0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF,   // 한자
             0xFF00...0xFFEF,   // 전각 구두점
             0x0E00...0x0E7F:   // 태국 문자
            return true
        default:
            return false
        }
    }

    // MARK: - 좌표 변환

    /// aspect-fit으로 표시된 이미지의 실제 프레임
    private func fittedRect(for imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(containerSize.width / imageSize.width,
                        containerSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(x: (containerSize.width - size.width) / 2,
                             y: (containerSize.height - size.height) / 2)
        return CGRect(origin: origin, size: size)
    }

    /// 정규화 좌표(좌상단 원점) → 화면 좌표
    private func viewRect(for normalized: CGRect, fitted: CGRect) -> CGRect {
        CGRect(x: fitted.minX + normalized.minX * fitted.width,
               y: fitted.minY + normalized.minY * fitted.height,
               width: normalized.width * fitted.width,
               height: normalized.height * fitted.height)
    }
}
