//
//  TagEditor.swift
//  밑줄 (BookmarkShot)
//
//  모음(태그): 문장을 "위로가 된 말", "일할 때" 처럼 내 말로 묶는다. 한 문장이 여러 모음에 들 수 있다.
//  이미 쓴 모음은 눌러서 넣고 빼고, 새 이름을 적으면 새 모음이 된다.
//

import SwiftUI
import SwiftData

struct TagEditor: View {
    @Bindable var quote: Quote
    @Query private var allQuotes: [Quote]
    @State private var newTag = ""

    private var knownTags: [String] {
        Array(Set(allQuotes.flatMap(\.tags) + quote.tags)).sorted()
    }

    var body: some View {
        if !knownTags.isEmpty {
            TagChips(tags: knownTags, selected: Set(quote.tags)) { tag in
                if let index = quote.tags.firstIndex(of: tag) {
                    quote.tags.remove(at: index)
                } else {
                    quote.tags.append(tag)
                }
            }
        }
        TextField("새 모음 이름", text: $newTag)
            .submitLabel(.done)
            .onSubmit(addNewTag)
    }

    private func addNewTag() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        newTag = ""
        guard !tag.isEmpty, !quote.tags.contains(tag) else { return }
        quote.tags.append(tag)
    }
}

/// 모음 칩 줄. 넓이가 모자라면 다음 줄로 흐른다. 고른 칩은 채워진다.
struct TagChips: View {
    let tags: [String]
    let selected: Set<String>
    let onTap: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                let isOn = selected.contains(tag)
                Button { onTap(tag) } label: {
                    Text(verbatim: "#\(tag)")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isOn ? Color.accentColor : Color.accentColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(isOn ? Color.white : Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

/// 자식을 줄 단위로 흘려 놓는다.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        rows(proposal.width ?? .infinity, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, point) in rows(bounds.width, subviews).origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func rows(_ width: CGFloat, _ subviews: Subviews) -> (origins: [CGPoint], size: CGSize) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (origins, CGSize(width: maxX, height: y + rowHeight))
    }
}
