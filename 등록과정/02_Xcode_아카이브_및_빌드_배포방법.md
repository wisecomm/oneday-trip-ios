# 02. Xcode 아카이브 및 빌드 배포 방법

Xcode를 사용하여 배포용 바이너리(IPA)를 아카이브(Archive)하고, App Store Connect 및 TestFlight에 업로드하는 단계별 가이드입니다.

---

## 📌 1. 버전 및 빌드 번호 관리

배포 시에는 매번 이전 업로드보다 높은 **빌드 번호(Build)**를 지정해야 App Store Connect에서 중복 오류 없이 처리됩니다.

- **버전 (`CFBundleShortVersionString`)**: 사용자에게 표시되는 버전 (예: `1.0.0`, `1.0.1`)
- **빌드 (`CURRENT_PROJECT_VERSION`)**: App Store Connect 내부 식별 빌드 번호 (정수, 예: `1`, `2`, `3`...)

### Xcode에서 변경하는 방법
1. Xcode 좌측 네비게이터에서 **`oneday-trip-ios` 프로젝트 선택**
2. **TARGETS** ➔ **`oneday-trip-ios`** 선택 ➔ **General** 탭
3. **Identity** 섹션:
   - **Version**: `1.0.0`
   - **Build**: `1` (업로드할 때마다 `2`, `3`... 1씩 증가)

---

## 🚀 2. 아카이브(Archive) 및 업로드 단계

### 1단계: 타겟 디바이스 설정
- Xcode 상단 바 중앙의 기기 선택 드롭다운 클릭
- 목록에서 **`Any iOS Device (arm64)`** 선택 (또는 연결된 실제 iPhone 선택)
  > *※ 시뮬레이터(Simulator)를 선택한 상태에서는 아카이브 메뉴가 비활성화됩니다.*

---

### 2단계: 아카이브 실행
1. Xcode 상단 메뉴: **[Product] ➔ [Archive]** 클릭
2. 컴파일 및 패키징이 진행되며 완료되면 자동으로 **Organizer(오거나이저)** 창이 열립니다.

---

### 3단계: App Store Connect 업로드 배포
1. Organizer 목록에서 방금 생성된 최신 빌드 선택
2. 우측 파란색 **[Distribute App]** 버튼 클릭
3. 배포 대상 선택:
   - **[App Store Connect]** 선택 ➔ [Next]
4. 목적 선택:
   - **[Upload]** (App Store 제출 및 TestFlight용) 선택 ➔ [Next]
5. 배포 옵션:
   - "Upload your app's symbols" 체크 권장 (크래시 로그 분석용)
   - [Next] 클릭
6. 코드 서명 (Re-sign):
   - **[Automatically manage signing]** 선택 ➔ [Next]
7. 검토 및 업로드:
   - 빌드 서명 요약 정보 확인 후 **[Upload]** 클릭
8. "App Store Connect upload succeeded" 메시지가 뜨면 완료!

---

## ✈️ 3. TestFlight(테스트플라이트)를 통한 사전 테스트

업로드 후 약 10~20분 뒤 App Store Connect에서 바이너리 처리가 완료되면 TestFlight로 즉시 실기기 테스트가 가능합니다.

1. [App Store Connect](https://appstoreconnect.apple.com) 접속 ➔ **[나의 앱]** ➔ **[하루여행]**
2. 상단 **[TestFlight]** 탭 클릭
3. **내부 테스팅(Internal Testing)**:
   - 개발자 본인 및 팀원을 내부 테스터로 추가 시 심사 없이 **즉시 초대 및 설치 가능**
4. **외부 테스팅(External Testing)**:
   - 지인 또는 일반 사용자 대상 (최대 10,000명)
   - 최초 1회 간단한 TestFlight 베타 심사(Beta App Review) 후 초대 링크 배포 가능

---

## 🛠️ CLI(터미널) 자동화 빌드 명령어

CI/CD 파이프라인이나 터미널에서 직접 아카이브를 만들고 업로드할 때 사용하는 명령어입니다:

```bash
cd /Users/danyoh/XXX-GARDE/oneday-trip-ios

# 1. Archive 생성
xcodebuild -project oneday-trip-ios.xcodeproj \
           -scheme oneday-trip-ios \
           -configuration Release \
           -destination 'generic/platform=iOS' \
           -archivePath build/oneday-trip-ios.xcarchive \
           archive

# 2. App Store Connect 유효성 검사 및 업로드 (altool / notarytool)
xcrun altool --validate-app \
             -f build/oneday-trip-ios.ipa \
             -t ios \
             --apiKey <API_KEY_ID> \
             --apiIssuer <ISSUER_ID>
```
