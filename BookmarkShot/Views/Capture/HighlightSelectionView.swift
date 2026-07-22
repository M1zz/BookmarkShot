//
//  HighlightSelectionView.swift
//  밑줄
//
//  핵심 UX: 촬영한 페이지 위를 형광펜 긋듯 손가락으로 스윽 문지르면
//  손가락이 지나간 단어들만 골라 문장을 추출한다.
//

import SwiftUI

struct HighlightSelectionView: View {
    let image: UIImage
    let ocr: OCRResult
    /// 선택된 텍스트가 바뀔 때마다 호출
    let onSelectionChange: (String) -> Void

    @State private var selectedWordIDs: Set<UUID> = []
    @State private var strokePoints: [CGPoint] = []
    @State private var eraseMode = false

    /// 손가락 터치 판정 여유 (단어 박스를 상하좌우로 넓혀서 판정)
    private let touchTolerance: CGFloat = 10

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let fitted = fittedRect(for: image.size, in: geo.size)

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)

                    // 선택된 단어 하이라이트 (형광펜 느낌)
                    Canvas { context, _ in
                        for word in ocr.allWords where selectedWordIDs.contains(word.id) {
                            let rect = viewRect(for: word.box, fitted: fitted)
                                .insetBy(dx: -3, dy: -2)
                            context.fill(
                                Path(roundedRect: rect, cornerRadius: 4),
                                with: .color(.yellow.opacity(0.45))
                            )
                        }
                        // 현재 손가락 궤적 표시
                        if strokePoints.count > 1 {
                            var path = Path()
                            path.move(to: strokePoints[0])
                            for point in strokePoints.dropFirst() {
                                path.addLine(to: point)
                            }
                            context.stroke(
                                path,
                                with: .color(eraseMode ? .red.opacity(0.35) : .orange.opacity(0.35)),
                                style: StrokeStyle(lineWidth: 24, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                    .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            strokePoints.append(value.location)
                            updateSelection(at: value.location, fitted: fitted)
                        }
                        .onEnded { _ in
                            strokePoints.removeAll()
                            notifySelection()
                        }
                )
            }

            // 도구 모음
            HStack(spacing: 16) {
                Button {
                    eraseMode.toggle()
                } label: {
                    Label(eraseMode ? "지우개 ON" : "지우개",
                          systemImage: eraseMode ? "eraser.fill" : "eraser")
                }
                .tint(eraseMode ? .red : .accentColor)

                Button {
                    selectedWordIDs.removeAll()
                    notifySelection()
                } label: {
                    Label("전체 지우기", systemImage: "trash")
                }
                .disabled(selectedWordIDs.isEmpty)

                Spacer()

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
    }

    // MARK: - 선택 로직

    private func updateSelection(at point: CGPoint, fitted: CGRect) {
        for word in ocr.allWords {
            let rect = viewRect(for: word.box, fitted: fitted)
                .insetBy(dx: -touchTolerance, dy: -touchTolerance)
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
        onSelectionChange(parts.joined(separator: " "))
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
