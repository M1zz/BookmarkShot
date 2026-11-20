# App Review 메모 · 답장

인앱 상품을 붙여 심사에 낼 때마다 이 글을 **App Review 정보 ▸ 메모** 에 넣고,
2.1(b) "인앱 상품을 찾을 수 없다" 로 돌아오면 같은 글로 답장한다.

## 지난 리젝 (2026-11-10, 1.0.4 빌드 5, 2.1(b))

- 원인: 1.0.4 빌드 5 는 페이월을 넣기 **전** 빌드였다 (`BookmarkShotEntitlement.lastBuildBeforePaywall = 5`).
  그런데 상품 10개를 그 제출에 붙여 냈다. 앱 안에 사는 자리가 없으니 심사원이 못 찾았다.
- 다시 막지 않으려면:
  1. 상품을 붙인 제출에는 **페이월이 든 빌드(6 이상)** 만 낸다. 다시 내는 빌드: 1.0.4 (6) — 1.0.5 로 만든 것을 모두 담았다.
  2. 상품 10개 모두 App Store Connect 에서 '제출 준비 완료' 이고 이번 버전 제출에 붙어 있는지 본다.
  3. 유료 앱 계약(Paid Apps Agreement)이 '활성' 인지 본다.
  4. 아래 영어 글을 메모 칸과 답장에 넣는다.

## 메모 · 답장 (영어 — 그대로 붙여 넣는다)

```
Hello App Review team,

Thank you for your patience. Build 1.0.4 (5) was built before the in-app purchases were added, which is why they could not be found. The new build, 1.0.4 (6), includes the full purchase screen. All In-App Purchases are offered by StoreKit 2 and need no account or login. They are not restricted by storefront or device.

How to find each In-App Purchase:

1. Launch the app. Tap the gear button (Settings) at the top right of any tab.
2. Tap the first row, "Bookmark Shot Plus · Pro". The purchase screen opens.
   (The same screen also opens when a free limit is reached: adding an 11th book or a 101st quote.)
3. Bookmark Shot Plus card: "Yearly" and "Lifetime" are shown. Tap "Show weekly and monthly" to see Weekly and Monthly.
   -> Plus Yearly ($5.99), Plus Lifetime ($17.99), Plus Weekly ($0.99), Plus Monthly ($1.99)
4. Bookmark Shot Pro card: same layout.
   -> Pro Yearly ($8.99), Pro Lifetime ($26.99), Pro Weekly ($1.49), Pro Monthly ($2.99)
5. Plus to Pro (Lifetime) ($8.99): after buying Plus Lifetime, open the purchase screen again. The Pro card's Lifetime option becomes "Upgrade to Pro Lifetime".
6. Pro Graduate ($17.99): after starting any subscription, open Settings. Under "Bookmark Shot Plus · Pro", tap "Switch to Lifetime". It offers Pro Lifetime at the graduate price to current subscribers.

"Restore Purchases" is in the top right of the purchase screen and in Settings.

The app works offline and does not require sign-in. Text recognition runs on device.

Thank you.
```
