//
//  BookmarkShotApp.swift
//  책갈피샷 (BookmarkShot)
//
//  책 구절 촬영 → 문장 스크랩 앱
//

import SwiftUI
import SwiftData

@main
struct BookmarkShotApp: App {

    /// SwiftData 컨테이너.
    /// 1순위: iCloud(CloudKit) 동기화 — Apple 개발자 계정 + iCloud 켜진 기기에서 자동 동기화.
    /// 실패 시(개발자 계정 없음, 시뮬레이터 미로그인 등): 로컬 저장으로 자동 폴백.
    let container: ModelContainer

    init() {
        let schema = Schema([Book.self, Quote.self])
        do {
            let cloudConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            container = try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            // CloudKit을 쓸 수 없는 환경 → 로컬 전용으로 폴백
            do {
                let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
                container = try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                fatalError("SwiftData 컨테이너 생성 실패: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
