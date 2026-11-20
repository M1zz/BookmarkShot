//
//  SentenceListView.swift
//  밑줄 (BookmarkShot)
//
//  긋기의 다른 길: 찍은 페이지를 문장 목록으로 보여 주고, 탭해서 고른다.
//  VoiceOver 로 한 문장씩 듣다가 두 번 탭하면 밑줄을 그은 것과 같다.
//  보이는 사람에게도 "긋기 귀찮을 때" 빠른 길이다. VoiceOver 가 켜져 있으면 이 길로 시작한다.
//

import SwiftUI
import NaturalLanguage

struct SentenceListView: View {
    let ocr: OCRResult
    /// 고른 문장이 바뀔 때마다 (페이지 순서대로 이어 붙인 글)
    let onSelectionChange: (String) -> Void

    @State private var selected: Set<Int> = []
    private let sentences: [String]

    init(ocr: OCRResult, onSelectionChange: @escaping (String) -> Void) {
        self.ocr = ocr
        self.onSelectionChange = onSelectionChange
        self.sentences = Self.split(ocr)
    }

    var body: some View {
        List(sentences.indices, id: \.self) { index in
            let isOn = selected.contains(index)
            Button {
                if isOn { selected.remove(index) } else { selected.insert(index) }
                onSelectionChange(HighlightSelectionView.join(selected.sorted().map { sentences[$0] }))
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isOn ? Color.accentColor : .secondary)
                        .accessibilityHidden(true)
                    Text(sentences[index])
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(isOn ? Color.yellow.opacity(0.18) : nil)
            .accessibilityAddTraits(isOn ? .isSelected : [])
            .accessibilityHint(Text("두 번 탭하면 밑줄을 긋거나 지웁니다."))
        }
        .listStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
    }

    /// 줄을 이어 붙인 뒤 문장으로 나눈다. 페이지 맨 위 · 아래에서 잘린 조각도 그대로 하나로 둔다.
    static func split(_ ocr: OCRResult) -> [String] {
        let text = HighlightSelectionView.join(ocr.lines.map(\.text))
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex)
            .map { text[$0].trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
