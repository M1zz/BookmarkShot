# 책갈피샷 (BookmarkShot) 📚

책 구절 촬영 → 문장 스크랩 iOS 앱.

책표지와 마음에 드는 구절이 있는 페이지를 찍기만 하면 **무슨 책 몇 페이지**인지 자동으로 인식하고, 페이지 사진 위를 **손가락으로 형광펜 긋듯 스윽 문지르면** 그 문장만 골라 추출해 줍니다.

## 요구 사항

- Xcode 16 이상 (프로젝트가 Xcode 16 폴더 동기화 방식이라 15에서는 열리지 않습니다)
- iOS 17.0 이상 기기
- 카메라 테스트는 **실기기** 필요 (시뮬레이터에서는 자동으로 앨범 선택으로 폴백)

## 실행 방법

1. `BookmarkShot.xcodeproj`를 Xcode에서 엽니다.
2. 프로젝트 설정 → **Signing & Capabilities**에서 본인 팀(Team)을 선택하고, Bundle Identifier(`com.leeo.bookmarkshot`)를 본인 계정에 맞게 변경합니다.
3. 실기기를 연결하고 Run.

### iCloud 동기화 관련

- SwiftData + CloudKit으로 기기 간 자동 동기화됩니다. **유료 Apple 개발자 계정**이 있어야 하고, entitlements의 컨테이너 ID(`iCloud.com.leeo.bookmarkshot`)를 본인 번들 ID에 맞게 바꿔주세요.
- 개발자 계정이 없거나 iCloud를 쓰지 않는 경우: Signing & Capabilities에서 iCloud/Push capability를 제거해도 됩니다. 앱이 CloudKit 초기화에 실패하면 **자동으로 로컬 저장으로 폴백**하도록 되어 있습니다.

## 주요 기능

| 기능 | 구현 |
|---|---|
| 책 등록 | 표지 촬영 → 온디바이스 OCR로 제목/저자 추정, 뒤표지 바코드(EAN-13) 찍히면 ISBN 자동 인식 |
| 페이지 번호 | 페이지 사진 상/하단 가장자리의 숫자를 휴리스틱으로 자동 감지 (수정 가능) |
| 문장 추출 | 페이지 촬영 → Vision OCR(한국어+영어) → **손가락 하이라이트로 원하는 단어만 선택** |
| 하이라이트 도구 | 지우개 모드, 전체 지우기, 페이지 전체 선택 |
| 보관함 | 책별 그리드 서재, 전체 문장 검색, 즐겨찾기 |
| 회고 | "오늘의 문장" — 매일 스크랩 하나를 다시 보여줌, 공유 카드 |
| 저장 | SwiftData (+ CloudKit 자동 동기화, 실패 시 로컬 폴백) |

## 코드 구조

```
BookmarkShot/
├── App/            앱 진입점, 탭 구성
├── Models/         Book, Quote (SwiftData, CloudKit 호환 규칙 적용)
├── Services/
│   ├── OCRService.swift      Vision OCR (줄/단어 단위 박스) + 바코드
│   ├── CoverAnalyzer.swift   표지 → 제목/저자 추정 휴리스틱
│   └── PageAnalyzer.swift    페이지 번호 추정 휴리스틱
└── Views/
    ├── Capture/    ImagePicker, ScanPageView, HighlightSelectionView(핵심 UX)
    ├── Library/    서재, 책 상세, 책 추가
    ├── Quotes/     전체 문장, 스크랩 상세
    └── Review/     오늘의 문장
```

## 알아두면 좋은 것

- OCR은 100% 온디바이스(Vision)라 네트워크 없이 동작하고, 사진이 외부로 나가지 않습니다.
- 표지 제목/저자 추정은 휴리스틱이라 디자인이 화려한 표지에서는 틀릴 수 있습니다 → 저장 전 항상 수정 가능한 폼으로 노출됩니다.
- 손가락 하이라이트는 OCR 단어 박스와 터치 궤적의 교차 판정으로 동작합니다. 판정 여유는 `HighlightSelectionView`의 `touchTolerance`로 조절하세요.
