import UIKit
import WebKit

public protocol WebAppInterfaceDelegate: AnyObject {
    func webAppDidRequestToast(message: String)
    func webAppDidRequestExit()
    func webAppDidRequestLogout()
    func webAppDidRequestServerError(message: String)
    func webAppDidRequestDownloadBlob(data: Data, mimeType: String, fileName: String)
}

public class WebAppInterface: NSObject, WKScriptMessageHandler {

    public weak var webView: WKWebView?
    public weak var delegate: WebAppInterfaceDelegate?

    public init(webView: WKWebView? = nil, delegate: WebAppInterfaceDelegate? = nil) {
        self.webView = webView
        self.delegate = delegate
        super.init()
    }

    // MARK: - WKScriptMessageHandler
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "AppBridge" || message.name == "AndroidBridge" else { return }

        // 메시지 바디 파싱 (Dictionary 또는 JSON String 대응)
        var action: String?
        var data: [String: Any]?
        var callbackId: String?

        if let dict = message.body as? [String: Any] {
            action = dict["action"] as? String
            data = dict["data"] as? [String: Any]
            callbackId = dict["callbackId"] as? String
        } else if let jsonString = message.body as? String,
                  let jsonData = jsonString.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            action = dict["action"] as? String
            data = dict["data"] as? [String: Any]
            callbackId = dict["callbackId"] as? String
        }

        guard let action = action else {
            NSLog("[WebAppInterface] Received invalid bridge message without action: %@", String(describing: message.body))
            return
        }

        NSLog("[WebAppInterface] Received action: %@, callbackId: %@", action, callbackId ?? "none")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.handleAction(action: action, data: data, callbackId: callbackId)
        }
    }

    // MARK: - Action Handler
    private func handleAction(action: String, data: [String: Any]?, callbackId: String?) {
        switch action {
        case "LOGOUT":
            logout()

        case "EXIT_APP":
            exitApp()

        case "SHOW_TOAST":
            let message = data?["message"] as? String ?? ""
            showToast(message: message)

        case "ERROR_DIALOG":
            let message = data?["message"] as? String ?? "오류가 발생했습니다."
            handleServerError(message: message)

        case "GET_APP_VERSION":
            let versionName = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            let versionCode = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
            let versionInfo: [String: Any] = [
                "versionName": versionName,
                "versionCode": versionCode
            ]
            sendResponse(callbackId: callbackId, data: versionInfo)

        // 기기 시스템 언어 브릿지 (oneday-trip 다국어 ko, en, ja, zh-CN, zh-TW 연동)
        case "GET_DEVICE_LANGUAGE":
            let appLang = getDeviceAppLanguage()
            let langTag = Locale.preferredLanguages.first ?? Locale.current.identifier
            let langInfo: [String: Any] = [
                "language": appLang,
                "languageTag": langTag
            ]
            sendResponse(callbackId: callbackId, data: langInfo)

        case "DELAYED_WORK":
            DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { [weak self] in
                let resultData: [String: Any] = ["status": "done"]
                DispatchQueue.main.async {
                    self?.sendResponse(callbackId: callbackId, data: resultData)
                }
            }

        case "SYNC_COOKIES":
            syncCookies()

        case "DOWNLOAD_BLOB":
            if let base64String = data?["base64"] as? String,
               let mimeType = data?["mimeType"] as? String {
                let fileName = data?["fileName"] as? String ?? ""
                downloadBlob(base64: base64String, mimeType: mimeType, fileName: fileName)
            }

        default:
            NSLog("[WebAppInterface] Unknown action: %@", action)
        }
    }

    /// iOS 시스템 언어를 oneday-trip 지원 언어 코드(ko, en, ja, zh-CN, zh-TW)로 매핑 (기본: ko)
    private func getDeviceAppLanguage() -> String {
        let preferred = (Locale.preferredLanguages.first ?? "ko").lowercased()

        if preferred.hasPrefix("ko") {
            return "ko"
        } else if preferred.hasPrefix("ja") {
            return "ja"
        } else if preferred.hasPrefix("en") {
            return "en"
        } else if preferred.contains("hant") || preferred.contains("tw") || preferred.contains("hk") || preferred.contains("mo") {
            return "zh-TW"
        } else if preferred.hasPrefix("zh") {
            return "zh-CN"
        } else {
            return "ko" // 기본 언어는 한국어
        }
    }

    // MARK: - Native Actions

    public func showToast(message: String) {
        delegate?.webAppDidRequestToast(message: message)
    }

    public func exitApp() {
        if let delegate = delegate {
            delegate.webAppDidRequestExit()
        } else {
            UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
        }
    }

    public func logout() {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        dataStore.removeData(ofTypes: dataTypes, modifiedSince: Date.distantPast) { [weak self] in
            DispatchQueue.main.async {
                self?.delegate?.webAppDidRequestLogout()
                self?.showToast(message: "로그아웃 완료")
            }
        }
    }

    public func syncCookies() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            NSLog("[WebAppInterface] Synced %ld cookies", cookies.count)
        }
    }

    public func handleServerError(message: String) {
        delegate?.webAppDidRequestServerError(message: message)
    }

    public func downloadBlob(base64: String, mimeType: String, fileName: String) {
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
            NSLog("[WebAppInterface] Failed to decode base64 blob data")
            showToast(message: "다운로드 실패: 잘못된 파일 데이터")
            return
        }

        var finalFileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalFileName.isEmpty || finalFileName == "null" {
            let ext = getExtensionFromMimeType(mimeType)
            finalFileName = "onedaytrip_\(Int(Date().timeIntervalSince1970 * 1000)).\(ext)"
        }

        delegate?.webAppDidRequestDownloadBlob(data: data, mimeType: mimeType, fileName: finalFileName)
    }

    private func getExtensionFromMimeType(_ mimeType: String) -> String {
        switch mimeType.lowercased() {
        case "image/jpeg", "image/jpg": return "jpg"
        case "image/png": return "png"
        case "image/gif": return "gif"
        case "application/pdf": return "pdf"
        case "text/plain": return "txt"
        case "application/json": return "json"
        case "application/zip": return "zip"
        case "application/vnd.ms-excel", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": return "xlsx"
        default: return "bin"
        }
    }

    // MARK: - Native -> Web Communication

    /// Web으로 비동기 응답 전송 (Request-Response 패턴: window.onNativeResponse)
    public func sendResponse(callbackId: String?, data: [String: Any]) {
        guard let callbackId = callbackId, !callbackId.isEmpty else { return }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: data),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let escapedCallbackId = callbackId.replacingOccurrences(of: "'", with: "\\'")
        let js = "if(window.onNativeResponse) { window.onNativeResponse('\(escapedCallbackId)', \(jsonString)); }"

        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(js, completionHandler: { _, error in
                if let error = error {
                    NSLog("[WebAppInterface] Error sending response: %@", error.localizedDescription)
                }
            })
        }
    }

    /// Native에서 Web으로 이벤트 전송 (Event-Listening 패턴: window.onNativeEvent)
    public func sendEvent(eventName: String, data: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let escapedEventName = eventName.replacingOccurrences(of: "'", with: "\\'")
        let js = "if(window.onNativeEvent) { window.onNativeEvent('\(escapedEventName)', \(jsonString)); }"

        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(js, completionHandler: { _, error in
                if let error = error {
                    NSLog("[WebAppInterface] Error sending event: %@", error.localizedDescription)
                }
            })
        }
    }
}
