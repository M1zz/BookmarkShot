//
//  PageAnalyzer.swift
//  책갈피샷
//
//  페이지 사진 OCR 결과에서 페이지 번호를 추정하는 휴리스틱.
//  - 페이지 위/아래 가장자리(상단 12% / 하단 12%)에 있는 1~4자리 숫자를 후보로.
//  - 여러 개면 가장자리에 더 가까운 것을 선택.
//

import Foundation

enum PageAnalyzer {

    static func guessPageNumber(from result: OCRResult) -> Int? {
        struct Candidate {
            let number: Int
            let edgeDistance: CGFloat
        }

        var candidates: [Candidate] = []

        for line in result.lines {
            let trimmed = line.text.trimmingCharacters(in: .whitespaces)
            // "123", "- 123 -", "123p", "p.123" 등에서 숫자만 추출
            let digits = trimmed.filter(\.isNumber)
            guard !digits.isEmpty, digits.count <= 4,
                  // 숫자 이외 문자가 소수인 짧은 줄만 (본문 문장 배제)
                  trimmed.count <= 8,
                  let number = Int(digits), number > 0 else { continue }

            let midY = line.box.midY
            let nearTop = midY < 0.12
            let nearBottom = midY > 0.88
            guard nearTop || nearBottom else { continue }

            let edgeDistance = min(midY, 1 - midY)
            candidates.append(Candidate(number: number, edgeDistance: edgeDistance))
        }

        return candidates.min { $0.edgeDistance < $1.edgeDistance }?.number
    }
}
