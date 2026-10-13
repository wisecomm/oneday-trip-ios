import UIKit
import WebKit
import CoreLocation

public class MainViewController: UIViewController {

    // MARK: - Properties
    public private(set) var webViewManager: WebViewManager!
    private var locationManager: CLLocationManager?

    // 하루여행 공식 웹 서비스 주소 (원격 배포 URL)
    // 로컬 디버깅 시: "http://localhost:5173" 또는 Mac IP (예: "http://192.168.0.x:5173")
    public static let defaultWebURL = "https://oneday-trip.vercel.app"

    // MARK: - Lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupWebView()
        setupLocationManager()
        loadInitialURL()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    // MARK: - Setup
    private func setupWebView() {
        webViewManager = WebViewManager(presentingViewController: self)
        webViewManager.appInterface.delegate = self

        let webView = webViewManager.webView
        view.addSubview(webView)

        // 풀스크린 웹뷰 배치 (Safe Area 내비게이션 바/상태바 영역 자연스럽게 대응)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        requestLocationPermission()
    }

    private func loadInitialURL() {
        webViewManager.load(urlString: MainViewController.defaultWebURL)
    }

    public func requestLocationPermission() {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager?.authorizationStatus ?? .notDetermined
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        if status == .notDetermined {
            locationManager?.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager?.startUpdatingLocation()
        }
    }

    // MARK: - Back Navigation Handling
    public func handleBackNavigation() -> Bool {
        if webViewManager.webView.canGoBack {
            webViewManager.webView.goBack()
            return true
        }
        return false
    }
}

// MARK: - WebAppInterfaceDelegate
extension MainViewController: WebAppInterfaceDelegate {

    public func webAppDidRequestToast(message: String) {
        ToastView.show(message: message, in: view)
    }

    public func webAppDidRequestExit() {
        UIControl().sendAction(#selector(NSXPCConnection.suspend), to: UIApplication.shared, for: nil)
    }

    public func webAppDidRequestLogout() {
        // 로그아웃 후 초기 하루여행 홈으로 이동
        webViewManager.load(urlString: MainViewController.defaultWebURL)
    }

    public func webAppDidRequestServerError(message: String) {
        let alert = UIAlertController(
            title: "오류",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    public func webAppDidRequestDownloadBlob(data: Data, mimeType: String, fileName: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL, options: .atomic)
            NSLog("[MainViewController] Blob saved to temporary path: %@", tempURL.path)

            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            // iPad popover anchor 대응
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            present(activityVC, animated: true) { [weak self] in
                guard let self = self else { return }
                ToastView.show(message: "다운로드 완료: \(fileName)", in: self.view)
            }
        } catch {
            NSLog("[MainViewController] Failed to save blob data: %@", error.localizedDescription)
            ToastView.show(message: "다운로드 실패: \(error.localizedDescription)", in: view)
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension MainViewController: CLLocationManagerDelegate {

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        NSLog("[MainViewController] Location authorization status: %d", status.rawValue)

        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        NSLog("[MainViewController] Updated location: lat=%.6f, lng=%.6f", location.coordinate.latitude, location.coordinate.longitude)
        // 단발성 위치 확인 후 배터리 절약을 위해 정지
        manager.stopUpdatingLocation()
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("[MainViewController] Location manager failed with error: %@", error.localizedDescription)
    }
}
