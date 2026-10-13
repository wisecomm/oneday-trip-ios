# 하루여행 (OneDay Trip) — iOS WKWebView 하이브리드 앱

위치기반 여행 일정 및 맛집 지도 서비스 **하루여행 (oneday-trip)**을 탑재한 Swift 기반 iOS 하이브리드 WKWebView 애플리케이션입니다.  
안드로이드 앱(`oneday-trip-app`)과 100% 동일한 기능 사양과 네이티브 브릿지 통신 규격을 제공합니다.

---

## 📱 프로젝트 정보

- **Bundle ID**: `kr.co.softone.onedaytrip`
- **앱 이름**: 하루여행 (OneDay Trip)
- **개발 언어**: Swift 5.0 (UIKit + WebKit)
- **최소 지원 버전**: iOS 15.0 이상
- **접속 대상 URL**: `https://oneday-trip.vercel.app` (로컬 개발 시: `http://localhost:5173` 또는 Mac IP)

---

## 🌐 다국어 지원 (i18n)

기본 언어는 **한국어(Default)**이며, 기기 시스템 언어에 따라 4개 국어(5개 로케일)를 완벽 지원합니다.

| 로케일 | 지원 언어 | 앱 이름 (`CFBundleDisplayName`) | 위치 권한 안내 문구 |
| :--- | :--- | :--- | :--- |
| **`ko.lproj/`** (기본) | **한국어** | **하루여행** | "내 주변 가볼 만한 곳과 맛집 추천, 여행 동선 길찾기를 위해 현재 위치 정보가 필요합니다." |
| **`en.lproj/`** | 영어 | OneDay Trip | "Location access is required to recommend nearby attractions, restaurants, and navigation routes." |
| **`ja.lproj/`** | 일본어 | ワンデイトリップ | "周辺の観光地やおすすめスポット、ルート案内のために位置情報が必要です。" |
| **`zh-Hans.lproj/`** | 중국어 간체 | 一日游 | "为了推荐周边景点、美食以及路线导航，需要获取您的当前位置信息。" |
| **`zh-Hant.lproj/`** | 중국어 번체 | 一日遊 | "為了推薦周邊景點、美食以及路線導航，需要獲取您的目前位置資訊。" |

---

## 🛠 주요 하이브리드 기능

1. **위치 정보(GPS / CoreLocation)**:
   - `CLLocationManager`를 통한 위치 권한 요청 및 웹의 Geolocation API 자동 연동
2. **외부 앱 스킴 연동 (`LSApplicationQueriesSchemes`)**:
   - **네이버 지도 길찾기 (`nmap://`)**: 네이버 지도 앱 설치 여부를 확인하여 앱 실행, 미설치 시 웹 지도/App Store 연결
   - 카카오맵(`kakaomap://`), 티맵(`tmap://`), 전화(`tel:`), 메일(`mailto:`) 인텐트 지원
3. **네이티브 브릿지 (`window.webkit.messageHandlers.AppBridge` & `window.AndroidBridge`)**:
   - `GET_DEVICE_LANGUAGE`: 기기 시스템 언어(`ko`, `en`, `ja`, `zh-CN`, `zh-TW`)를 웹 i18n으로 반환
   - `GET_APP_VERSION`: 앱 버전(`CFBundleShortVersionString`, `CFBundleVersion`) 반환
   - `SHOW_TOAST`: 안드로이드 스타일 토스트 UI 표시
   - `LOGOUT`: WKWebsiteDataStore 쿠키 및 캐시 삭제
   - `DOWNLOAD_BLOB`: 파일 다운로드 및 `UIActivityViewController`(공유/파일 앱 저장) 연동
4. **원격 웹뷰 디버깅**:
   - iOS 16.4+ `isInspectable = true` 활성화로 Mac Safari 웹 검사기(F12) 실시간 디버깅 지원

---

## 💻 빌드 및 실행 방법

### Xcode에서 실행
```bash
cd /Users/danyoh/XXX-GARDE/oneday-trip-ios
open oneday-trip-ios.xcodeproj
```
1. 상단 타겟 디바이스(iPhone 16 Pro 시뮬레이터 또는 실제 iPhone) 선택
2. `Cmd + R` 키를 눌러 실행

### 터미널에서 시뮬레이터 빌드
```bash
xcodebuild -project oneday-trip-ios/oneday-trip-ios.xcodeproj \
           -scheme oneday-trip-ios \
           -destination 'generic/platform=iOS Simulator' \
           build
```

---

## 🔍 Safari 웹 검사기 디버깅 방법

1. Mac의 Safari 실행 -> 설정 -> 고급 -> **"웹 개발자를 위한 기능 표시"** 체크
2. 시뮬레이터 또는 iPhone에서 앱 실행
3. Safari 상단 메뉴 **개발자용(Develop)** -> `시뮬레이터/기기명` -> `oneday-trip.vercel.app` 클릭
4. Safari 웹 개발자 도구로 실시간 콘솔, 네트워크, DOM 검사 수행
