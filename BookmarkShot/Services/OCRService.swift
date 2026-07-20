//
//  OCRService.swift
//  책갈피샷
//
//  Vision 프레임워크 기반 온디바이스 OCR (한국어 + 영어).
//  모든 좌표는 "정규화(0~1) + 좌상단 원점" 기준으로 변환해 SwiftUI에서 바로 쓰기 좋게 만든다.
//

import UIKit
import Vision

/// 단어 하나 (공백 기준 토큰)와 그 위치
struct RecognizedWord: Identifiable, Hashable {
    let id = UUID()
    let text: String
    /// 정규화 좌표 (0~1), 좌상단 원점
    let box: CGRect
}

/// OCR로 인식된 한 줄
struct RecognizedLine: Identifiable, Hashable {
    let id = UUID()
    let text: String
    /// 정규화 좌표 (0~1), 좌상단 원점
    let box: CGRect
    let words: [RecognizedWord]
}

struct OCRResult {
    let lines: [RecognizedLine]
    var fullText: String {
        lines.map(\.text).joined(separator: "\n")
    }
    /// 읽기 순서(위→아래, 왼→오른쪽)로 정렬된 모든 단어
    var allWords: [RecognizedWord] {
        lines.flatMap(\.words)
    }
}

enum OCRError: Error {
    case invalidImage
    case recognitionFailed
}

enum OCRService {

    // MARK: - 텍스트 인식

    /// 이미지에서 한국어/영어 텍스트를 줄 + 단어 단위로 인식
    static func recognizeText(in image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else { throw OCRError.invalidImage }
        let orientation = cgOrientation(from: image.imageOrientation)

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["ko-KR", "en-US"]
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    continuation.resume(returning: OCRResult(lines: Self.makeLines(from: observations)))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 관측 결과 → 줄/단어 구조로 변환 (읽기 순서 정렬 포함)
    private static func makeLines(from observations: [VNRecognizedTextObservation]) -> [RecognizedLine] {
        var lines: [RecognizedLine] = []

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let lineText = candidate.string
            let lineBox = flip(observation.boundingBox)

            // 공백 기준 토큰별로 단어 박스 계산
            var words: [RecognizedWord] = []
            var searchStart = lineText.startIndex
            for token in lineText.split(separator: " ") {
                let tokenString = String(token)
                if let range = lineText.range(of: tokenString, range: searchStart..<lineText.endIndex) {
                    searchStart = range.upperBound
                    if let boxObservation = try? candidate.boundingBox(for: range) {
                        words.append(RecognizedWord(text: tokenString, box: flip(boxObservation.boundingBox)))
                    } else {
                        words.append(RecognizedWord(text: tokenString, box: lineBox))
                    }
                }
            }
            if words.isEmpty && !lineText.trimmingCharacters(in: .whitespaces).isEmpty {
                words = [RecognizedWord(text: lineText, box: lineBox)]
            }
            // 단어를 왼쪽 → 오른쪽 순으로
            words.sort { $0.box.minX < $1.box.minX }
            lines.append(RecognizedLine(text: lineText, box: lineBox, words: words))
        }

        // 줄을 위 → 아래 순으로 (좌상단 원점이므로 minY 오름차순)
        lines.sort {
            if abs($0.box.midY - $1.box.midY) > min($0.box.height, $1.box.height) * 0.5 {
                return $0.box.midY < $1.box.midY
            }
            return $0.box.minX < $1.box.minX
        }
        return lines
    }

    // MARK: - 바코드 (ISBN)

    /// 뒤표지 바코드에서 ISBN(EAN-13, 978/979 시작) 추출
    static func detectISBN(in image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        let orientation = cgOrientation(from: image.imageOrientation)

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNDetectBarcodesRequest()
                request.symbologies = [.ean13]

                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
                do {
                    try handler.perform([request])
                    let isbn = (request.results ?? [])
                        .compactMap(\.payloadStringValue)
                        .first { $0.hasPrefix("978") || $0.hasPrefix("979") }
                    continuation.resume(returning: isbn)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - 좌표/방향 유틸

    /// Vision(좌하단 원점) → 좌상단 원점 정규화 좌표
    private static func flip(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.origin.x,
               y: 1 - rect.origin.y - rect.height,
               width: rect.width,
               height: rect.height)
    }

    private static func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
