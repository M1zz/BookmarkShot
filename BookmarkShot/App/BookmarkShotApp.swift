//
//  BookmarkShotApp.swift
//  밑줄 (BookmarkShot)
//
//  책 구절 촬영 → 문장 스크랩 앱
//

import SwiftUI
import AppIntents
import SwiftData
import LeeoKit

@main
struct BookmarkShotApp: App {

    /// SwiftData 컨테이너.
    /// 1순위: iCloud(CloudKit) 동기화 — Apple 개발자 계정 + iCloud 켜진 기기에서 자동 동기화.
    /// 실패 시(개발자 계정 없음, 시뮬레이터 미로그인 등): 로컬 저장으로 자동 폴백.
    let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 사용량 기록 · 크래시 진단 · 익명 사용 통계. 실패해도 앱 동작에는 영향이 없다.
        LeeoKit.bootstrap(BookmarkShotSpec.self)

        let schema = Schema([Book.self, Quote.self])
        if ScreenshotMode.isActive {
            // 스크린샷 데모(DEBUG): 메모리 저장소에 데모 서재만 — 실제 데이터 · iCloud 를 건드리지 않는다
            container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
            ScreenshotMode.populate(container.mainContext)
            Self.shareWithIntents(container)
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
                container = StoreFallback.memoryContainer(schema: schema, after: error)
            }
        }
        Self.shareWithIntents(container)
    }

    /// Siri · Spotlight 인텐트가 같은 저장소를 읽게 한다 (→ BookmarkShotIntents.swift).
    /// 인텐트는 화면 없이 앱을 깨워 돌기도 해서, 화면이 아니라 여기서 넘긴다.
    private static func shareWithIntents(_ container: ModelContainer) {
        AppDependencyManager.shared.add(dependency: container)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .leeoSatisfactionCheck(BookmarkShotSpec.self)
                .storeFallbackNotice()
                // 팁 상품을 불러오고 끝나지 않은 팁을 마저 센다
                .task { await BookmarkShotSpec.tipJar.startStandalone() }
                // Spotlight 에 싣는 문장을 지금 것에 맞춘다. 열 때 한 번, 뒤로 보낼 때마다.
                .task { await BookmarkShotLibrary.reindex(container) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { Task { await BookmarkShotLibrary.reindex(container) } }
                }
        }
        .modelContainer(container)
    }
}
