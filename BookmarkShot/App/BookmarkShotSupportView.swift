//
//  BookmarkShotSupportView.swift
//  밑줄 (BookmarkShot)
//
//  지원(피드백·리뷰·버전) 화면
//

import SwiftUI
import LeeoKit

struct BookmarkShotSupportView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    LeeoSupportSection<BookmarkShotSpec>()
                    // 앞으로 만들 기능 — 원본은 BookmarkShotRoadmap.swift
                    NavigationLink(LeeoRoadmapText.entry) { RoadmapScreen() }
                    LeeoShareAppLink<BookmarkShotSpec>()
                    // 개발자 응원하기 — 판매 중인 팁이 있을 때만 선다
                    LeeoTipJarLink<BookmarkShotSpec>(tipJar: BookmarkShotSpec.tipJar)
                } header: {
                    Text("지원")
                }
            }
            .navigationTitle("설정")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
