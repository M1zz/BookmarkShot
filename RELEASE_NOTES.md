# 릴리즈 노트

## 1.0.2

### 앱스토어 (한국어)

설정 화면이 새로 생겼어요.
의견 보내기와 리뷰 남기기를 설정에서 할 수 있어요.
앱 버전도 설정에서 바로 확인할 수 있어요.
앱이 더 안정적으로 동작하도록 다듬었어요.

### 앱스토어 (en)

A new Settings screen is here.
Send feedback or review from Settings.
Check the app version right there too.
Polished for steadier performance.

### 앱스토어 (en-GB)

A new Settings screen has arrived.
Send feedback or review from Settings.
Check the app version there as well.
Polished for steadier performance.

### 앱스토어 (zh-Hans)

全新的设置页面来啦。
可以在设置里发送反馈、给我们评价。
在设置里也能直接查看 App 版本。
优化了细节，运行更稳定。

### 앱스토어 (zh-Hant)

全新的設定頁面登場了。
可以在設定裡傳送意見、給我們評價。
在設定裡也能直接查看 App 版本。
調整了細節，運作更穩定。

### 앱스토어 (ja)

設定画面が新しくなりました。
設定からご意見の送信やレビューができます。
アプリのバージョンも設定で確認できます。
より安定して動くよう調整しました。

### 앱스토어 (ru)

Появился новый экран настроек.
Отзыв можно оставить в настройках.
Версия приложения тоже в настройках.
Мы сделали приложение стабильнее.

### 앱스토어 (es)

Ya hay una nueva pantalla de ajustes.
Comentarios y reseñas, en Ajustes.
También verás la versión de la app ahí.
Mejoramos la app para más estabilidad.

### 앱스토어 (de)

Die Einstellungen sind ganz neu.
Feedback und Bewertung: dort möglich.
Auch die App-Version steht dort.
Die App läuft nun noch stabiler.

## 1.0.1

### App Store "이번 버전의 새로운 기능"
```
구절 스크랩이 더 쉬워졌어요.

• 촬영 후 페이지 영역을 직접 선택할 수 있어요. 네 모서리를 페이지에 맞추면 자동으로 반듯하게 펴드려요.
• 선택한 영역만 종이처럼 펴서 담아, 글자가 더 또렷하고 크게 보여요.
• 밑줄 화면에서 두 손가락으로 확대·이동해 원하는 문장을 더 정확하게 그을 수 있어요.
```

### 변경 사항 (개발 메모)
- 구절 스크랩 촬영 흐름 개편: **일반 카메라 촬영 → 영역 선택 → 구문 추출 → 밑줄**
  - 가이드/자동 촬영 오버레이 없는 일반 카메라로 촬영
  - `RegionSelectionView`: 사진 위 네 모서리 핸들을 손가락으로 페이지 꼭짓점에 맞춤
    - 초기 위치는 Vision 문서 세그먼테이션(`DocumentFlattener.detectCorners`)으로 자동 추정
  - 선택 영역만 원근 보정(`CIPerspectiveCorrection`)해 종이처럼 반듯하게 크롭
- 밑줄(하이라이트) 화면 개선
  - 핀치 확대(최대 6배)·이동 지원, 확대 시 단어 판정 여유 자동 축소로 정밀 밑줄
  - 안내 문구는 처음 3회만 노출
- 앱 버전 1.0.1로 상향
