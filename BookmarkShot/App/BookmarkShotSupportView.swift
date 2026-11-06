//
//  BookmarkShotSupportView.swift
//  밑줄 (BookmarkShot)
//
//  설정 — 밑줄 Plus · Pro, iCloud 동기화, 문장 내보내기, 지원(피드백 · 리뷰 · 버전).
//

import SwiftUI
import SwiftData
import StoreKit
import LeeoKit

struct BookmarkShotSupportView: View {
    @Query private var quotes: [Quote]
    @State private var purchases = Purchases.shared
    @State private var paywallFeature: BookmarkShotFeature?
    @State private var showsPaywall = false
    @State private var showsGraduation = false
    @State private var showsManageSubscription = false
    @State private var wantsSync = BookmarkShotEntitlement.wantsICloudSync

    var body: some View {
        NavigationStack {
            List {
                plansSection
                syncSection
                exportSection
                Section {
                    LeeoSupportSection<BookmarkShotSpec>()
                    // 앞으로 만들 기능 — 원본은 BookmarkShotRoadmap.swift
                    NavigationLink(LeeoRoadmapText.entry) { RoadmapScreen() }
                    LeeoShareAppLink<BookmarkShotSpec>()
                    // 개발자 응원하기 — 판매 중인 팁이 있을 때만 선다. 아무것도 열지 않는다.
                    LeeoTipJarLink<BookmarkShotSpec>(tipJar: purchases.tipJar)
                } header: {
                    Text("지원")
                }
            }
            .navigationTitle("설정")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .manageSubscriptionsSheet(isPresented: $showsManageSubscription)
            #endif
            .paywall(for: $paywallFeature)
            .sheet(isPresented: $showsPaywall) { PaywallView() }
            .sheet(isPresented: $showsGraduation) {
                LeeoGraduationOfferView(graduate: purchases.product(BookmarkShotEntitlement.graduateID)) {
                    await purchases.refresh()
                }
            }
            .task { await purchases.refresh() }
        }
    }

    // MARK: - 밑줄 Plus · Pro

    private var plansSection: some View {
        Section {
            if purchases.tier == .pro {
                Label {
                    Text(String(localized: "\(BookmarkShotTier.pro.title) 사용 중"))
                } icon: {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                }
            } else {
                Button {
                    showsPaywall = true
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(purchases.tier == .plus ? BookmarkShotTier.pro.title : String(localized: "밑줄 Plus · Pro"))
                            .font(.body.weight(.semibold))
                        Text(statusLine)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            // 구독 중인 사람에게는 늘 평생으로 바꾸는 길이 있다.
            if purchases.subscription != nil {
                Button(LeeoLadderText.manageSubscription) { showsManageSubscription = true }
                if purchases.product(BookmarkShotEntitlement.graduateID) != nil, !purchases.ownsLifetime(.pro) {
                    Button(LeeoLadderText.switchToLifetimeEntry) { showsGraduation = true }
                }
            }
            Button("구매 복원") {
                Task { await purchases.restore() }
            }
            .disabled(purchases.isWorking)
        } header: {
            Text("밑줄 Plus · Pro")
        } footer: {
            if let message = purchases.failureMessage {
                Text(message)
            }
        }
    }

    /// 지금 칸을 한 줄로. 아직 App Store 에 묻는 중이면 '무료'라고 단정하지 않는다.
    private var statusLine: String {
        guard purchases.isKnown else { return String(localized: "확인 중…") }
        return purchases.tier == .plus
            ? String(localized: "\(BookmarkShotTier.plus.title) 사용 중")
            : String(localized: "책 · 문장 무제한, iCloud 동기화와 위젯")
    }

    // MARK: - iCloud 동기화 (Pro)

    private var syncSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { purchases.allows(.sync) && wantsSync },
                set: { on in
                    guard purchases.allows(.sync) else {
                        if on { paywallFeature = .sync }
                        return
                    }
                    wantsSync = on
                    BookmarkShotEntitlement.wantsICloudSync = on
                }
            )) {
                HStack(spacing: 8) {
                    Text("iCloud 동기화")
                    if !purchases.allows(.sync) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text(String(localized: "잠김, \(BookmarkShotTier.pro.title) 필요")))
                    }
                }
            }
        } footer: {
            Text(syncFooter)
        }
    }

    /// 저장소는 앱을 열 때 iCloud 와 이을지 정한다. 이번 실행과 원하는 것이 다르면 그렇다고 말한다.
    private var syncFooter: String {
        let wanted = purchases.allows(.sync) && wantsSync
        if purchases.isKnown, wanted != BookmarkShotEntitlement.launchedWithICloud {
            return String(localized: "앱을 완전히 닫았다 다시 열면 적용돼요.")
        }
        return String(localized: "폰을 바꾸거나 아이패드에서도 같은 서재와 문장을 봐요. 꺼도 이 기기의 기록은 그대로예요.")
    }

    // MARK: - 내보내기 (무료)

    private var exportSection: some View {
        Section {
            ShareLink(item: QuoteExport(quotes: quotes, format: .text),
                      preview: SharePreview(QuoteExport.fileName)) {
                Label("텍스트로 내보내기", systemImage: "doc.plaintext")
            }
            ShareLink(item: QuoteExport(quotes: quotes, format: .csv),
                      preview: SharePreview(QuoteExport.fileName)) {
                Label("CSV로 내보내기", systemImage: "tablecells")
            }
        } header: {
            Text("문장 내보내기")
        } footer: {
            Text("모은 문장을 모두 파일로 꺼내요. 어느 칸이든 무료예요.")
        }
        .disabled(quotes.isEmpty)
    }
}
