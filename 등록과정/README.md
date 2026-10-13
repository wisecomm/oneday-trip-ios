# 🍎 하루여행 (OneDay Trip) iOS 앱스토어 등록 절차 안내

Apple App Store(앱스토어) 출시를 위한 전체 등록 가이드, Xcode 아카이브/배포 방법, 심사 리젝 방지 가이드 및 스토어 메타데이터 모음입니다.

---

## 📑 목차 및 가이드 문서 바로가기

1. **[01. 애플 앱스토어 등록 절차 & 체크리스트](01_애플_앱스토어_등록_체크리스트_및_절차.md)**
   - Apple Developer Program 및 App Store Connect 설정
   - App ID(`kr.co.softone.onedaytrip`), 인증서 및 프로비저닝 프로파일
   - 신규 앱 생성 및 메타데이터, 연령 등급, 개인정보 보호(App Privacy) 설정
   - 심사 제출 체크리스트

2. **[02. Xcode 아카이브 및 빌드 배포 방법](02_Xcode_아카이브_및_빌드_배포방법.md)**
   - Team 및 코드 서명(`Apple Distribution`, Team ID `5VNT2YZBRT`)
   - 버전 및 빌드 번호 관리 (`CFBundleShortVersionString`, `CURRENT_PROJECT_VERSION`)
   - Xcode 아카이브(Archive) 및 App Store Connect 원클릭 업로드
   - TestFlight 내부/외부 테스터 배포 방법

3. **[03. 앱스토어 심사 리젝 방지 가이드 (웹뷰 앱 특화)](03_앱스토어_심사_리젝_방지_가이드.md)**
   - **Guideline 4.2 (최소 기능 요건)**: 단순 웹뷰 패키징 리젝 방지 핵심 요소
   - **Guideline 5.1.1(v) (계정 삭제 규정)**: 앱 내 회원 탈퇴 필수 요건
   - **Guideline 5.1.5 (위치 정보 이용)**: `NSLocationWhenInUseUsageDescription` 심사관 대응
   - 심사용 데모 계정 및 심사 메모(Review Notes) 작성법

4. **[04. 아이폰 앱 출시 전 필수 테스트 체크리스트](04_아이폰_앱_출시전_필수_테스트_체크리스트.md)**
   - **핵심 기능 검증**: GPS 위치, 외부 지도 앱(네이버/카카오/티맵) 연동, 파일 공유/다운로드, 카메라, 다국어(i18n), 회원 탈퇴
   - **iOS UI/UX 검증**: Safe Area(노치/다이내믹 아일랜드), 키보드 인풋 가림, 스와이프 뒤로가기 제스처, 다크 모드
   - **안정성 검증**: 오프라인 네트워크 단절 처리, 백그라운드 복귀

5. **[스토어 등록정보 복사용 텍스트](스토어_애셋/스토어_등록정보_복사용.md)**
   - 앱 이름, 부제(Subtitle), 키워드(Keywords), 상세 설명
   - 한국어, 영어, 일본어, 중국어 4개 국어 번역본
   - 지원 URL, 마케팅 URL, 개인정보처리방침 URL

---

## ⚡ 빠른 실행 명령어 요약

```bash
cd /Users/danyoh/XXX-GARDE/oneday-trip-ios

# 1. Xcode 프로젝트 열기
open oneday-trip-ios.xcodeproj

# 2. 터미널에서 아카이브 빌드 검증 (iOS 실기기 타겟)
xcodebuild -project oneday-trip-ios.xcodeproj \
           -scheme oneday-trip-ios \
           -destination 'generic/platform=iOS' \
           build

# 3. 연결된 iPhone(실기기)에 바로 설치 및 실행
xcrun devicectl device install app --device <UDID> \
  ~/Library/Developer/Xcode/DerivedData/oneday-trip-ios-*/Build/Products/Debug-iphoneos/oneday-trip-ios.app
```
