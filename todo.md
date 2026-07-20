# BookmarkShot TODO

## 완료
- [x] 빌드 확인 — iOS Simulator 대상 클린 빌드 성공 (2026-07-20, Xcode 17C52 / iOS 26.2 SDK)
- [x] 표지 제목 추출: 글자 크기 기반 "제목일 확률" 스코어링 도입 (CoverAnalyzer)
      - 각 줄에 확률(합=1) 부여, 확률 1위 줄을 제목으로 채택
      - AddBookView에 "제목 인식 신뢰도 NN%" 표시
