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
