//
//  BookmarkShotRoadmap.swift
//  BookmarkShot
//
//  **앞으로 만들 것**의 원본. 설정 ▸ 앞으로 만들 기능(`LeeoRoadmapView`)이 이 목록을 그대로 보여 준다.
//
//  ⚠️ 개발하다 "이건 다음에" 가 생기면 **여기에 한 줄을 더한다.** 코드의 TODO 주석으로만 남기지 않는다.
//     - 새 항목: `.planned`. 손대기 시작하면 `.building`. 내보내면 `.shipped("1.2.0")`.
//     - id 는 한 번 정하면 바꾸지 않는다(문구는 바꿔도 된다).
//     - 문구는 사용자 말로 쓴다(내부 이름 · 기술 용어 금지). 키는 한국어 문구이고, 지금은 한국어 앱이라 키가 곧 문구다 — 다른 언어를 열면 이 키들도 함께 번역한다.
//     - 사용자에게 보일 만한 것만 적는다. 리팩터링 · 시험 · 빌드 설정은 `.sprintcommander/tasks.json` 의 몫이다.
//

import SwiftUI
import LeeoKit

extension BookmarkShotSpec {
    static var roadmap: [LeeoRoadmapItem] {[
        // MARK: 다음에 만들어요
        .init(id: "a11y.voiceover", status: .planned,
              title: NSLocalizedString("VoiceOver로 더 편하게", comment: "Roadmap item: a11y.voiceover"),
              detail: NSLocalizedString("화면 읽기 기능이 책과 문장, 단추를 빠짐없이, 알맞은 순서로 읽어 줘요.", comment: "Roadmap item detail: a11y.voiceover")),
        .init(id: "a11y.largetext", status: .planned,
              title: NSLocalizedString("큰 글씨에 맞춘 화면", comment: "Roadmap item: a11y.largetext"),
              detail: NSLocalizedString("글자 크기를 키워도 잘리지 않고 보기 좋게 다시 배치돼요.", comment: "Roadmap item detail: a11y.largetext")),
        .init(id: "a11y.contrast", status: .planned,
              title: NSLocalizedString("보기 편한 색과 대비", comment: "Roadmap item: a11y.contrast"),
              detail: NSLocalizedString("대비를 높이거나 색을 구별하기 어려워도 내용을 알아볼 수 있어요.", comment: "Roadmap item detail: a11y.contrast")),
        .init(id: "a11y.motion", status: .planned,
              title: NSLocalizedString("움직임 줄이기", comment: "Roadmap item: a11y.motion"),
              detail: NSLocalizedString("움직임 줄이기를 켜면 화면 효과가 차분해져요.", comment: "Roadmap item detail: a11y.motion")),
        .init(id: "a11y.keyboard", status: .planned,
              title: NSLocalizedString("키보드로 조작하기", comment: "Roadmap item: a11y.keyboard"),
              detail: NSLocalizedString("아이패드에서 키보드만으로 책과 문장을 찾아 넘겨요.", comment: "Roadmap item detail: a11y.keyboard")),
        .init(id: "lang.english", status: .shipped("1.0.2"),
              title: NSLocalizedString("영어 지원", comment: "Roadmap item: lang.english"),
              detail: NSLocalizedString("앱을 영어로도 쓸 수 있어요.", comment: "Roadmap item detail: lang.english")),
        .init(id: "lang.more", status: .shipped("1.0.2"),
              title: NSLocalizedString("더 많은 언어", comment: "Roadmap item: lang.more"),
              detail: NSLocalizedString("더 많은 나라 말로 앱을 쓸 수 있게 해요.", comment: "Roadmap item detail: lang.more")),
        .init(id: "onboarding", status: .planned,
              title: NSLocalizedString("처음 쓰는 분을 위한 안내", comment: "Roadmap item: onboarding"),
              detail: NSLocalizedString("처음 열었을 때 무엇을 할 수 있는지 짧게 보여 줘요.", comment: "Roadmap item detail: onboarding")),
        .init(id: "whatsnew", status: .planned,
              title: NSLocalizedString("업데이트 소식", comment: "Roadmap item: whatsnew"),
              detail: NSLocalizedString("업데이트 뒤 처음 열 때 무엇이 새로 생겼는지 알려 줘요.", comment: "Roadmap item detail: whatsnew")),
        .init(id: "tips", status: .planned,
              title: NSLocalizedString("쓰는 요령 알려 주기", comment: "Roadmap item: tips"),
              detail: NSLocalizedString("알아 두면 편한 기능을 알맞은 때에 살짝 알려 줘요.", comment: "Roadmap item detail: tips")),
        .init(id: "haptics", status: .planned,
              title: NSLocalizedString("손끝으로 느끼는 반응", comment: "Roadmap item: haptics"),
              detail: NSLocalizedString("문장을 긋거나 저장하면 가볍게 떨려서 알려 줘요.", comment: "Roadmap item detail: haptics")),
        .init(id: "shortcuts", status: .planned,
              title: NSLocalizedString("Siri와 단축어", comment: "Roadmap item: shortcuts"),
              detail: NSLocalizedString("Siri에게 말하거나 단축어로 오늘의 문장을 바로 열어요.", comment: "Roadmap item detail: shortcuts")),
        .init(id: "backup", status: .planned,
              title: NSLocalizedString("백업과 내보내기", comment: "Roadmap item: backup"),
              detail: NSLocalizedString("모은 책과 문장을 파일로 저장하고 다시 불러올 수 있어요.", comment: "Roadmap item detail: backup")),
        .init(id: "lock.faceid", status: .planned,
              title: NSLocalizedString("Face ID 잠금", comment: "Roadmap item: lock.faceid"),
              detail: NSLocalizedString("Face ID나 Touch ID로 앱을 잠가 모은 문장을 지켜요.", comment: "Roadmap item detail: lock.faceid")),
        .init(id: "notifications", status: .planned,
              title: NSLocalizedString("오늘의 문장 알림", comment: "Roadmap item: notifications"),
              detail: NSLocalizedString("정해 둔 때에 모은 문장 하나를 알림으로 보내 줘요.", comment: "Roadmap item detail: notifications")),
        .init(id: "fold", status: .planned,
              title: NSLocalizedString("펼치는 아이폰 화면", comment: "Roadmap item: fold"),
              detail: NSLocalizedString("펼치는 아이폰에서 넓은 화면을 두 쪽으로 나눠 써요.", comment: "Roadmap item detail: fold")),
        .init(id: "data.delete", status: .planned,
              title: NSLocalizedString("내 데이터 한 번에 지우기", comment: "Roadmap item: data.delete"),
              detail: NSLocalizedString("원하면 앱 안에서 모은 책과 문장을 모두 지울 수 있어요.", comment: "Roadmap item detail: data.delete")),
        .init(id: "autosave", status: .planned,
              title: NSLocalizedString("하던 일 이어서 하기", comment: "Roadmap item: autosave"),
              detail: NSLocalizedString("문장을 고르다 앱이 꺼져도 하던 내용이 남아 있어요.", comment: "Roadmap item detail: autosave")),
    ]}
}

// MARK: - 화면

/// 설정 ▸ 앞으로 만들 기능. "이런 기능이 있으면 좋겠어요" 는 LeeoKit 피드백 창을 연다.
struct RoadmapScreen: View {
    @State private var showFeedback = false

    var body: some View {
        LeeoRoadmapView<BookmarkShotSpec>(onSuggest: { showFeedback = true })
            .sheet(isPresented: $showFeedback) {
                NavigationStack {
                    LeeoFeedbackView<BookmarkShotSpec>()
                }
            }
    }
}
