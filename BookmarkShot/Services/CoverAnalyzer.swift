//
//  CoverAnalyzer.swift
//  밑줄
//
//  표지 사진 OCR 결과에서 제목/저자를 추정하는 휴리스틱.
//  - 각 줄에 "제목일 확률"을 매긴다. 주 신호는 글자 크기(박스 높이).
//    큰 글자일수록 제목일 확률이 높고, 저자/역자 수식어나 너무 긴 줄은 확률을 낮춘다.
//  - 확률이 가장 높은 줄을 제목으로 채택(비슷한 크기의 인접 줄은 이어붙여 다줄 제목 처리).
//  - 저자: 제목 다음으로 크거나, 제목 주변의 짧은 줄.
//  결과는 어디까지나 "추정"이므로 UI에서 항상 수정 가능하게 노출한다.
//

import Foundation

/// 한 줄이 제목일 확률과 그 근거
struct TitleCandidate: Identifiable {
    let id: UUID
    let text: String
    /// 표지의 모든 줄 중 이 줄이 제목일 상대 확률 (0~1, 전체 합 = 1)
    let probability: Double
    let box: CGRect
}

struct CoverGuess {
    var title: String = ""
    var author: String = ""
    /// 채택된 제목의 확률 (0~1). "제목 인식 신뢰도"로 UI에 표시 가능.
    var titleProbability: Double = 0
    /// 확률 내림차순 후보 목록 (사용자가 다른 줄을 제목으로 고르고 싶을 때 사용)
    var candidates: [TitleCandidate] = []
}

enum CoverAnalyzer {

    static func guess(from result: OCRResult) -> CoverGuess {
        let lines = result.lines.filter {
            !$0.text.trimmingCharacters(in: .whitespaces).isEmpty
        }
        guard !lines.isEmpty else { return CoverGuess() }

        // 1) 각 줄의 "제목 점수" 계산 — 글자 크기(박스 높이)가 주 신호
        let maxHeight = lines.map(\.box.height).max() ?? 1
        let scored: [(line: RecognizedLine, score: Double)] = lines.map { line in
            let relativeHeight = maxHeight > 0 ? line.box.height / maxHeight : 0  // 0~1
            // 큰 글자를 강조하기 위해 지수 가중 (크기 차이를 벌린다)
            var score = pow(relativeHeight, 1.5)
            // 저자/역자 수식어가 있으면 제목일 확률을 크게 낮춤
            if containsAuthorMarker(line.text) { score *= 0.3 }
            // 너무 긴 줄은 문장·설명·홍보문구일 가능성 → 약한 페널티
            if line.text.count > 25 { score *= 0.6 }
            return (line, max(score, 0.0001))
        }

        // 2) 점수 → 확률 (전체 합이 1이 되도록 정규화)
        let total = scored.reduce(0) { $0 + $1.score }
        var candidates = scored.map { item in
            TitleCandidate(
                id: item.line.id,
                text: item.line.text,
                probability: item.score / total,
                box: item.line.box
            )
        }
        candidates.sort { $0.probability > $1.probability }

        // 3) 확률 1위 줄을 제목으로 채택
        guard let best = scored.max(by: { $0.score < $1.score })?.line else { return CoverGuess() }

        // 크기가 비슷(70% 이상)하고 세로로 인접한 줄들을 병합해 다줄 제목 처리
        let titleThreshold = best.box.height * 0.7
        var titleLines = lines.filter { line in
            line.box.height >= titleThreshold &&
            abs(line.box.midY - best.box.midY) < best.box.height * 3
        }
        titleLines.sort { $0.box.minY < $1.box.minY }
        let title = titleLines.map(\.text).joined(separator: " ")

        // 4) 저자: 제목에 포함되지 않은 줄 중, 크기가 그 다음으로 크고 너무 길지 않은 줄
        let titleIDs = Set(titleLines.map(\.id))
        let byHeight = lines.sorted { $0.box.height > $1.box.height }
        let authorCandidate = byHeight.first { line in
            !titleIDs.contains(line.id) &&
            line.text.count <= 30
        }

        return CoverGuess(
            title: title.trimmingCharacters(in: .whitespaces),
            author: cleanAuthor(authorCandidate?.text ?? ""),
            titleProbability: candidates.first?.probability ?? 0,
            candidates: candidates
        )
    }

    /// 저자/역자 수식어가 들어간 줄인지 (제목보다는 저자 줄일 신호)
    private static func containsAuthorMarker(_ text: String) -> Bool {
        let markers = ["지은이", "지음", "옮긴이", "옮김", "저자", "엮음", "편저", "역"]
        return markers.contains { text.contains($0) }
    }

    /// "지은이", "저", "옮김" 등 흔한 수식어 제거
    private static func cleanAuthor(_ raw: String) -> String {
        var text = raw
        for token in ["지은이", "지음", "옮긴이", "옮김", "저자", "글", "저"] {
            text = text.replacingOccurrences(of: token, with: "")
        }
        return text.trimmingCharacters(in: CharacterSet(charactersIn: " .|·:"))
    }
}
