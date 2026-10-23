//
//  BookmarkShotApp.swift
//  밑줄 (BookmarkShot)
//
//  책 구절 촬영 → 문장 스크랩 앱
//

import SwiftUI
import SwiftData
import LeeoKit

@main
struct BookmarkShotApp: App {

    /// SwiftData 컨테이너.
    /// 1순위: iCloud(CloudKit) 동기화 — Apple 개발자 계정 + iCloud 켜진 기기에서 자동 동기화.
    /// 실패 시(개발자 계정 없음, 시뮬레이터 미로그인 등): 로컬 저장으로 자동 폴백.
    let container: ModelContainer

    init() {
        // 사용량 기록 · 크래시 진단 · 익명 사용 통계. 실패해도 앱 동작에는 영향이 없다.
        LeeoKit.bootstrap(BookmarkShotSpec.self)

        let schema = Schema([Book.self, Quote.self])
        if ScreenshotMode.isActive {
            // 스크린샷 데모(DEBUG): 메모리 저장소에 데모 서재만 — 실제 데이터 · iCloud 를 건드리지 않는다
            container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
            ScreenshotMode.populate(container.mainContext)
            return
        }
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
                .leeoSatisfactionCheck(BookmarkShotSpec.self)
        }
        .modelContainer(container)
    }
}
