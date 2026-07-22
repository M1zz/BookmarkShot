# BookmarkShot TODO

## 완료
- [x] 빌드 확인 — iOS Simulator 대상 클린 빌드 성공 (2026-07-20, Xcode 17C52 / iOS 26.2 SDK)
- [x] 표지 제목 추출: 글자 크기 기반 "제목일 확률" 스코어링 도입 (CoverAnalyzer)
      - 각 줄에 확률(합=1) 부여, 확률 1위 줄을 제목으로 채택
      - AddBookView에 "제목 인식 신뢰도 NN%" 표시
- [x] "오늘의 문장" 위젯 추가 (BookmarkShotWidgetExtension 타깃)
      - App Group(group.com.leeo.bookmarkshot) 공유 저장소로 앱↔위젯 연동
      - 즐겨찾기가 있으면 즐겨찾기 중에서, 없으면 전체 중 매일 하나 선택 (자정 자동 갱신)
      - small/medium/large 지원
- [x] "문장 책장" 탭 추가 (QuoteShelfView) — 즐겨찾기 문장 수집 장치
      - 빈 슬롯 + 다음 목표(진행률) 노출로 수집 동기 부여
- [x] 구절 스크랩 촬영 개선 (2026-07-22) — 페이지를 "종이처럼 납작하게" 펴서 담기
      - 촬영 흐름: 일반 카메라(가이드/자동촬영 없음) → 영역 선택 → 구문 추출 → 밑줄
      - RegionSelectionView 추가: 사진 위 네 모서리 핸들을 손가락으로 페이지 꼭짓점에 맞춤
        · 초기값은 DocumentFlattener.detectCorners(Vision 문서 세그먼테이션)로 자동 추정
      - DocumentScanner.swift: detectCorners + flatten(corners:)로 선택 영역만 원근 보정(CIPerspectiveCorrection)
      - HighlightSelectionView: 핀치 확대/이동 지원 + 확대 시 판정 여유 자동 축소로 정밀 밑줄
      - 하이라이트 안내 문구는 처음 3번만 노출(@AppStorage)
- [x] 앱 버전 1.0.1로 상향 (MARKETING_VERSION, 앱·위젯 Debug/Release)

## 남은 설정 (Apple 개발자 포털)
- [ ] App ID에 App Groups capability 활성화 + group.com.leeo.bookmarkshot 등록 (실기기용)
