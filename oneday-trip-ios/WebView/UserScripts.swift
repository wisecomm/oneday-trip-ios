import Foundation
import WebKit

public struct UserScripts {

    /// 웹페이지 시작 시 주입되는 스크립트 (AndroidBridge 호환 프록시, Blob Revoke 차단 등)
    public static var documentStartScript: WKUserScript {
        let source = """
        (function() {
            console.log("[UserScript] Injecting AndroidBridge compatibility layer & helpers");

            // 1. AndroidBridge 프록시 객체 생성 (기존 안드로이드용 웹 프론트 코드 완벽 호환)
            if (!window.AndroidBridge) {
                window.AndroidBridge = {
                    postMessage: function(message) {
                        try {
                            var payload = typeof message === 'string' ? JSON.parse(message) : message;
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.AppBridge) {
                                window.webkit.messageHandlers.AppBridge.postMessage(payload);
                            }
                        } catch (e) {
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.AppBridge) {
                                window.webkit.messageHandlers.AppBridge.postMessage({ action: 'RAW_MESSAGE', data: message });
                            }
                        }
                    },
                    showToast: function(message) {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.AppBridge) {
                            window.webkit.messageHandlers.AppBridge.postMessage({
                                action: 'SHOW_TOAST',
                                data: { message: message }
                            });
                        }
                    },
                    exitApp: function() {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.AppBridge) {
                            window.webkit.messageHandlers.AppBridge.postMessage({ action: 'EXIT_APP' });
                        }
                    },
                    logout: function() {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.AppBridge) {
                            window.webkit.messageHandlers.AppBridge.postMessage({ action: 'LOGOUT' });
                        }
                    },
                    syncCookies: function() {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.AppBridge) {
                            window.webkit.messageHandlers.AppBridge.postMessage({ action: 'SYNC_COOKIES' });
                        }
                    },
                    handleServerError: function(message) {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.AppBridge) {
                            window.webkit.messageHandlers.AppBridge.postMessage({
                                action: 'ERROR_DIALOG',
                                data: { message: message }
                            });
                        }
                    },
                    downloadBlob: function(base64, mimeType, fileName) {
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.AppBridge) {
                            window.webkit.messageHandlers.AppBridge.postMessage({
                                action: 'DOWNLOAD_BLOB',
                                data: {
                                    base64: base64,
                                    mimeType: mimeType,
                                    fileName: fileName
                                }
                            });
                        }
                    }
                };
            }

            // 2. Blob Revocation Blocker (다운로드 전 blob이 취소되는 현상 방지)
            var originalRevokeObjectURL = window.URL.revokeObjectURL;
            window.URL.revokeObjectURL = function(url) {
                console.log("[UserScript] Blocked URL.revokeObjectURL for: " + url);
            };

            // 3. Anchor Click Hook (동적 생성 링크의 download 파일명 캡처)
            if (!window.__downloadMap) {
                window.__downloadMap = {};
                var oldClick = HTMLAnchorElement.prototype.click;
                HTMLAnchorElement.prototype.click = function() {
                    var href = this.href;
                    var download = this.download;
                    if (href && download) {
                        window.__downloadMap[href] = download;
                        console.log("[UserScript] Captured filename for " + href + " -> " + download);
                    }
                    oldClick.apply(this, arguments);
                };
            }
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }

    /// 웹페이지 로드 완료 시 주입되는 스크립트 (서버 에러 감지)
    public static var documentEndScript: WKUserScript {
        let source = """
        (function() {
            try {
                var content = document.body ? document.body.innerText : '';
                if (content && content.trim().startsWith('{"status":"error"')) {
                    var json = JSON.parse(content);
                    if (window.AndroidBridge && window.AndroidBridge.handleServerError) {
                        window.AndroidBridge.handleServerError(json.message || "오류가 발생했습니다.");
                    }
                }
            } catch(e) {}
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    }
}
