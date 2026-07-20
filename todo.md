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

## 남은 설정 (Apple 개발자 포털)
- [ ] App ID에 App Groups capability 활성화 + group.com.leeo.bookmarkshot 등록 (실기기용)
