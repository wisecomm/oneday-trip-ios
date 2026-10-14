import UIKit
import WebKit

public protocol WebViewManagerDelegate: AnyObject {
    func webViewDidStartLoading()
    func webViewDidFinishLoading()
    func webViewDidFail(with error: Error)
    func webViewDidDownloadFile(at fileURL: URL, suggestedFilename: String)
}

public class WebViewManager: NSObject {

    public let webView: WKWebView
    public let appInterface: WebAppInterface
    public weak var delegate: WebViewManagerDelegate?
    private weak var presentingViewController: UIViewController?

    private static let naverMapAppStoreURL = "https://apps.apple.com/app/id311867728"
    private static let naverMapWebURL = "https://map.naver.com"
    private static let kakaoMapAppStoreURL = "https://apps.apple.com/app/id304608425"
    private static let tmapAppStoreURL = "https://apps.apple.com/app/id431589174"
    private static let googleMapsAppStoreURL = "https://apps.apple.com/app/id585027354"

    public init(presentingViewController: UIViewController) {
        self.presentingViewController = presentingViewController

        // 1. WKWebViewConfiguration 구성
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let userContentController = WKUserContentController()

        // 2. UserScripts 주입 (AndroidBridge 호환 프록시, Blob 후킹 등)
        userContentController.addUserScript(UserScripts.documentStartScript)
        userContentController.addUserScript(UserScripts.documentEndScript)

        let appInterface = WebAppInterface()
        userContentController.add(appInterface, name: "AppBridge")
        userContentController.add(appInterface, name: "AndroidBridge")
        configuration.userContentController = userContentController
        configuration.websiteDataStore = WKWebsiteDataStore.default()

        // 3. WKWebView 생성
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = true
        webView.translatesAutoresizingMaskIntoConstraints = false

        // Custom User-Agent 설정 (웹에서 하이브리드 앱 여부 판별)
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 OneDayTripApp/1.0.0 (iOS)"

        // 4. Safari 원격 웹 인스펙터 활성화 (iOS 16.4+)
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        self.webView = webView
        self.appInterface = appInterface
        super.init()

        self.appInterface.webView = webView
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        self.webView.scrollView.delegate = self
        self.webView.scrollView.minimumZoomScale = 1.0
        self.webView.scrollView.maximumZoomScale = 1.0
        self.webView.scrollView.bouncesZoom = false
        self.webView.scrollView.showsHorizontalScrollIndicator = false
    }

    public func load(urlString: String) {
        guard let url = URL(string: urlString) else {
            NSLog("[WebViewManager] Invalid URL string: %@", urlString)
            return
        }
        var request = URLRequest(url: url)
        // 기기 시스템 언어를 Accept-Language 헤더로 전달
        let preferredLanguages = Locale.preferredLanguages.joined(separator: ", ")
        request.setValue(preferredLanguages, forHTTPHeaderField: "Accept-Language")

        webView.load(request)
    }

    public func reload() {
        webView.reload()
    }
}

// MARK: - WKNavigationDelegate
extension WebViewManager: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        NSLog("[WebViewManager] Page started: %@", webView.url?.absoluteString ?? "")
        delegate?.webViewDidStartLoading()
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NSLog("[WebViewManager] Page finished: %@", webView.url?.absoluteString ?? "")
        delegate?.webViewDidFinishLoading()

        // 뷰포트 고정 및 화면 배율(Zoom Scale) 1.0 원복
        let resetZoomJS = """
            var meta = document.querySelector('meta[name="viewport"]');
            if (meta) {
                meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';
            }
            window.scrollTo(0, 0);
        """
        webView.evaluateJavaScript(resetZoomJS, completionHandler: nil)
        webView.scrollView.setZoomScale(1.0, animated: false)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NSLog("[WebViewManager] Provisional navigation failed: %@", error.localizedDescription)
        handleLoadError(error)
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("[WebViewManager] Navigation failed: %@", error.localizedDescription)
        handleLoadError(error)
    }

    private func handleLoadError(_ error: Error) {
        delegate?.webViewDidFail(with: error)
        let nsError = error as NSError
        // 사용자가 내비게이션을 취소한 경우 (Code -999) 또는 외부 앱 스킴 시도 등으로 인한 미지원 URL (Code -1002) 무시
        if nsError.domain == NSURLErrorDomain {
            if nsError.code == NSURLErrorCancelled || nsError.code == NSURLErrorUnsupportedURL {
                NSLog("[WebViewManager] Ignored benign navigation error (code %d): %@", nsError.code, error.localizedDescription)
                return
            }
        }

        guard let vc = presentingViewController else { return }
        let alert = UIAlertController(
            title: "오류",
            message: "페이지를 로드할 수 없습니다.\n\(error.localizedDescription)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default, handler: nil))
        vc.present(alert, animated: true, completion: nil)
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let scheme = url.scheme?.lowercased() ?? ""

        // 1. 네이버 지도 스킴 (nmap://route/walk 등) 길찾기 연동
        if scheme == "nmap" {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else if let appStoreURL = URL(string: WebViewManager.naverMapAppStoreURL) {
                UIApplication.shared.open(appStoreURL, options: [:], completionHandler: nil)
            }
            decisionHandler(.cancel)
            return
        }

        // 2. 카카오맵 스킴 (kakaomap://)
        if scheme == "kakaomap" {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else if let appStoreURL = URL(string: WebViewManager.kakaoMapAppStoreURL) {
                UIApplication.shared.open(appStoreURL, options: [:], completionHandler: nil)
            }
            decisionHandler(.cancel)
            return
        }

        // 3. 티맵 스킴 (tmap://)
        if scheme == "tmap" {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else if let appStoreURL = URL(string: WebViewManager.tmapAppStoreURL) {
                UIApplication.shared.open(appStoreURL, options: [:], completionHandler: nil)
            }
            decisionHandler(.cancel)
            return
        }

        // 4. 구글맵 스킴 (comgooglemaps://, comgooglemapsurl://, googlemaps://)
        if scheme == "comgooglemaps" || scheme == "comgooglemapsurl" || scheme == "googlemaps" {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else if let appStoreURL = URL(string: WebViewManager.googleMapsAppStoreURL) {
                UIApplication.shared.open(appStoreURL, options: [:], completionHandler: nil)
            }
            decisionHandler(.cancel)
            return
        }

        // 5. 애플 지도 스킴 (maps://)
        if scheme == "maps" {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            decisionHandler(.cancel)
            return
        }

        // 6. 안드로이드 Intent 스킴 (intent://)
        if scheme == "intent" {
            handleIntentURL(url)
            decisionHandler(.cancel)
            return
        }

        // 7. 전화(tel:), 메일(mailto:), 메시지(sms:), 앱스토어(itms-apps:) 등 시스템 스킴 처리
        if scheme == "tel" || scheme == "mailto" || scheme == "sms" || scheme == "itms-apps" || scheme == "itms-appss" {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            decisionHandler(.cancel)
            return
        }

        // 8. 기타 외부 커스텀 스킴 (http, https, about, data, blob이 아닌 모든 스킴)
        if scheme != "http" && scheme != "https" && scheme != "about" && scheme != "data" && scheme != "blob" {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                NSLog("[WebViewManager] Unhandled custom scheme: %@", scheme)
            }
            decisionHandler(.cancel)
            return
        }

        // 9. 새 창(target="_blank") 열기 요청 시 현재 웹뷰에서 탐색
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    private func handleIntentURL(_ url: URL) {
        let urlString = url.absoluteString

        // 1. browser_fallback_url 파라미터가 있는 경우 추출하여 열기
        if let fallbackRange = urlString.range(of: "browser_fallback_url=") {
            let encodedFallback = String(urlString[fallbackRange.upperBound...]).components(separatedBy: ";").first ?? ""
            if let decodedFallback = encodedFallback.removingPercentEncoding,
               let fallbackURL = URL(string: decodedFallback) {
                if UIApplication.shared.canOpenURL(fallbackURL) {
                    UIApplication.shared.open(fallbackURL, options: [:], completionHandler: nil)
                    return
                }
            }
        }

        // 2. Google Maps intent인 경우 (예: intent://maps.google.com/...)
        if urlString.contains("maps.google.com") || urlString.contains("google.com/maps") {
            if let gmapsURL = URL(string: "comgooglemaps://"), UIApplication.shared.canOpenURL(gmapsURL) {
                let cleanURLString = urlString.replacingOccurrences(of: "intent://", with: "https://").components(separatedBy: "#Intent").first ?? ""
                if let cleanURL = URL(string: cleanURLString) {
                    UIApplication.shared.open(cleanURL, options: [:], completionHandler: nil)
                    return
                }
            } else if let appStoreURL = URL(string: WebViewManager.googleMapsAppStoreURL) {
                UIApplication.shared.open(appStoreURL, options: [:], completionHandler: nil)
                return
            }
        }

        // 3. scheme=https 혹은 scheme=http 파라미터 추출하여 웹 URL로 변환
        if let schemeRange = urlString.range(of: "scheme=") {
            let schemePart = String(urlString[schemeRange.upperBound...]).components(separatedBy: ";").first ?? "https"
            let pathPart = urlString.replacingOccurrences(of: "intent://", with: "").components(separatedBy: "#Intent").first ?? ""
            if let convertedURL = URL(string: "\(schemePart)://\(pathPart)") {
                if UIApplication.shared.canOpenURL(convertedURL) {
                    UIApplication.shared.open(convertedURL, options: [:], completionHandler: nil)
                    return
                }
            }
        }
    }

    @available(iOS 14.5, *)
    public func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    @available(iOS 14.5, *)
    public func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }
}

// MARK: - WKUIDelegate
extension WebViewManager: WKUIDelegate {

    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard let vc = presentingViewController else {
            completionHandler()
            return
        }

        let alert = UIAlertController(title: "알림", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
            completionHandler()
        })
        vc.present(alert, animated: true, completion: nil)
    }

    public func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard let vc = presentingViewController else {
            completionHandler(false)
            return
        }

        let alert = UIAlertController(title: "알림", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in
            completionHandler(false)
        })
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
            completionHandler(true)
        })
        vc.present(alert, animated: true, completion: nil)
    }

    public func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        guard let vc = presentingViewController else {
            completionHandler(nil)
            return
        }

        let alert = UIAlertController(title: "입력", message: prompt, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = defaultText
        }
        alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in
            completionHandler(nil)
        })
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
            let text = alert.textFields?.first?.text
            completionHandler(text)
        })
        vc.present(alert, animated: true, completion: nil)
    }

    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    @available(iOS 15.0, *)
    public func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }

    @available(iOS 15.0, *)
    public func webView(_ webView: WKWebView, requestGeolocationPermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        NSLog("[WebViewManager] Geolocation permission requested for origin: %@://%@:%ld", origin.protocol, origin.host, origin.port)
        decisionHandler(.grant)
    }
}

// MARK: - WKDownloadDelegate
extension WebViewManager: WKDownloadDelegate {

    @available(iOS 14.5, *)
    public func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let tempDir = FileManager.default.temporaryDirectory
        let destinationURL = tempDir.appendingPathComponent(suggestedFilename)

        try? FileManager.default.removeItem(at: destinationURL)
        completionHandler(destinationURL)
    }

    @available(iOS 14.5, *)
    public func downloadDidFinish(_ download: WKDownload) {
        NSLog("[WebViewManager] Download finished: %@", download.description)
    }

    @available(iOS 14.5, *)
    public func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        NSLog("[WebViewManager] Download failed with error: %@", error.localizedDescription)
    }
}

// MARK: - UIScrollViewDelegate
extension WebViewManager: UIScrollViewDelegate {

    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return nil // 핀치 줌 및 입력창 포커스 자동 확대(Zoom-in) 방지
    }

    public func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if scale != 1.0 {
            scrollView.setZoomScale(1.0, animated: false)
        }
    }
}

