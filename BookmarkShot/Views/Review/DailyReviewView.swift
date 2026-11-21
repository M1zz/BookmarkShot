//
//  DailyReviewView.swift
//  밑줄
//
//  회고: 하루에 하나, 예전에 스크랩한 문장을 다시 만난다.
//  (날짜 기반 시드로 매일 같은 문장이 유지되고, 셔플로 다른 문장도 볼 수 있다)
//

import SwiftUI
import SwiftData

struct DailyReviewView: View {
    @Query private var quotes: [Quote]
    /// 오늘 묶음 안에서 몇 번째 (넘기면 다음 묶음으로)
    @State private var index = 0
    /// 같은 날의 몇 번째 묶음
    @State private var round = 0
    /// 이 모음 안에서만 다시 만난다. nil 이면 모든 문장.
    @State private var tag: String?
    @State private var showsYear = false
    /// 스크린샷 데모(DEBUG)에서 정해 둔 문장
    @State private var screenshotQuote: Quote?
    @State private var shareImage: UIImage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 오늘 묶음. 빈도를 바꿔도 보던 문장이 바로 바뀌지 않게, 묶음이 바뀔 때만 다시 고른다.
    @State private var picks: [Quote] = []

    private func refreshPicks() {
        picks = ReviewPicker.picks(from: quotes, round: round, tag: tag)
        if index >= picks.count { index = 0 }
    }

    private var todaysQuote: Quote? {
        if let screenshotQuote { return screenshotQuote }
        let picks = picks
        return picks.isEmpty ? nil : picks[index % picks.count]
    }

    private var allTags: [String] { Array(Set(quotes.flatMap(\.tags))).sorted() }

    var body: some View {
        NavigationStack {
            Group {
                if let quote = todaysQuote {
                    reviewCard(for: quote)
                } else {
                    ContentUnavailableView {
                        Label("다시 만날 문장이 없어요", systemImage: "sparkles")
                    } description: {
                        Text("문장을 스크랩하면 매일 한 문장씩\n여기서 다시 만날 수 있어요.")
                    }
                }
            }
            .navigationTitle("오늘의 문장")
            .toolbar {
                if !allTags.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Picker("모음", selection: $tag) {
                                Text("모든 문장").tag(String?.none)
                                ForEach(allTags, id: \.self) { Text(verbatim: "#\($0)").tag(String?.some($0)) }
                            }
                        } label: {
                            Label(tag.map { "#\($0)" } ?? String(localized: "모든 문장"), systemImage: "tag")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showsYear = true } label: {
                        Label(String(localized: "올해의 문장"), systemImage: "calendar")
                    }
                    .disabled(quotes.isEmpty)
                }
            }
            .onChange(of: tag) { index = 0; round = 0 }
            .task(id: "\(round)|\(tag ?? "")|\(quotes.count)") { refreshPicks() }
            .sheet(isPresented: $showsYear) { YearInQuotesView() }
        }
        .onAppear(perform: pickScreenshotQuote)
    }

    /// 스크린샷 데모(DEBUG): 정해 둔 문장이 오늘의 문장으로 나오게 한다.
    private func pickScreenshotQuote() {
        guard let target = ScreenshotMode.dailyQuoteText else { return }
        screenshotQuote = quotes.first { $0.text == target }
    }

    /// 다음 문장. 오늘 묶음을 다 보면 같은 날의 다른 묶음으로.
    private func showNext() {
        screenshotQuote = nil
        withAnimation(reduceMotion ? nil : .default) {
            if index + 1 >= picks.count { index = 0; round += 1 } else { index += 1 }
        }
    }

    private func reviewCard(for quote: Quote) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 32)

                VStack(spacing: 20) {
                    Image(systemName: "quote.opening")
                        .font(.title)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)

                    Text(quote.text)
                        .font(.title3.weight(.medium))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .naturalDirection(of: quote.text)

                    VStack(spacing: 4) {
                        if let book = quote.book {
                            Text(book.title)
                                .font(.subheadline.weight(.semibold))
                                .naturalDirection(of: book.title)
                            if !book.author.isEmpty {
                                Text(book.author)
                                    .font(.caption)
                                    .naturalDirection(of: book.author)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let pageLabel = quote.pageLabel {
                            Text(pageLabel)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal)

                // 큰 글자에서는 두 버튼을 위아래로 쌓아 글자가 잘리지 않게 한다
                let buttons = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                buttons {
                    Button(action: showNext) {
                        Label(String(localized: "다음 문장 \(index % max(picks.count, 1) + 1)/\(max(picks.count, 1))"),
                              systemImage: "arrow.forward")
                    }
                    .buttonStyle(.brandSecondary)

                    if let shareImage {
                        ShareLink(item: Image(uiImage: shareImage),
                                  preview: SharePreview("문장 카드", image: Image(uiImage: shareImage))) {
                            Label("이미지로 공유", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.brandPrimary)
                    } else {
                        ShareLink(item: shareText(for: quote)) {
                            Label("공유", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.brandPrimary)
                    }
                }
                .padding(.horizontal)

                HStack(spacing: 12) {
                    SpeakButton(text: quote.note.isEmpty ? quote.text : quote.text + "\n\n" + quote.note)
                        .buttonStyle(.bordered)
                    // 이 문장을 얼마나 자주 다시 만날까 (→ ReviewPicker)
                    Picker(selection: Binding(get: { quote.reviewBias }, set: { quote.reviewBias = $0 })) {
                        Text("더 자주").tag(1)
                        Text("보통").tag(0)
                        Text("덜 자주").tag(-1)
                    } label: {
                        Text("만나는 빈도")
                    }
                    .pickerStyle(.menu)
                    .buttonStyle(.bordered)
                }

                if !quote.note.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("그때 남긴 메모", systemImage: "pencil.line")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(quote.note)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .naturalDirection(of: quote.note)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal)
                }
            }
        }
        .task(id: quote.persistentModelID) {
            shareImage = QuoteShareRenderer.image(
                text: quote.text,
                bookTitle: quote.book?.title ?? "",
                author: quote.book?.author ?? "",
                pageLabel: quote.pageLabel
            )
        }
    }

    private func shareText(for quote: Quote) -> String {
        var text = "“\(quote.text)”"
        if let book = quote.book {
            text += "\n— \(book.title)"
            if let pageLabel = quote.pageLabel { text += " (\(pageLabel))" }
        }
        return text
    }
}
