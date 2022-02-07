//
//  WebKitDownloadHelper.swift
//  WebviewDownloadSupport
//
//  Created by Nitin Bhatia on 02/02/22.
//



import Foundation
//
//  WKWebViewDownloadHelper.swift
//  WkWebViewTest
//
//  Created by Gualtiero Frigerio on 03/07/2020.
//  Copyright © 2020 Gualtiero Frigerio. All rights reserved.
//

// OLD implementation
// The helper is now distributed as SPM


//Package of third party avaibale at https://github.com/gualtierofrigerio/WKDownloadHelper

import Foundation
import WebKit

struct MimeType {
    var type:String
    var fileExtension:String
}

protocol WKWebViewDownloadHelperDelegate {
    func fileDownloadedAtURL(url:URL)
}

class WKWebviewDownloadHelper:NSObject {
    
    var webView:WKWebView
    var mimeTypes:[MimeType]
    var delegate:WKWebViewDownloadHelperDelegate
    
    init(webView:WKWebView, mimeTypes:[MimeType], delegate:WKWebViewDownloadHelperDelegate) {
        self.webView = webView
        self.mimeTypes = mimeTypes
        self.delegate = delegate
        super.init()
        webView.navigationDelegate = self
    }
    
    private var fileDestinationURL: URL?
    
    private func downloadData(fromURL url:URL,
                              fileName:String,
                              completion:@escaping (Bool, URL?) -> Void) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies() { cookies in
            let session = URLSession.shared
            session.configuration.httpCookieStorage?.setCookies(cookies, for: url, mainDocumentURL: nil)
            let task = session.downloadTask(with: url) { localURL, urlResponse, error in
                if let localURL = localURL {
                    let destinationURL = self.moveDownloadedFile(url: localURL, fileName: fileName)
                    completion(true, destinationURL)
                }
                else {
                    completion(false, nil)
                }
            }

            task.resume()
        }
    }
    
    private func getDefaultFileName(forMimeType mimeType:String) -> String {
        for record in self.mimeTypes {
            if mimeType.contains(record.type) {
                return "default." + record.fileExtension
            }
        }
        return "default"
    }
    
    private func getFileNameFromResponse(_ response:URLResponse) -> String? {
        if let httpResponse = response as? HTTPURLResponse {
            let headers = httpResponse.allHeaderFields
            if let disposition = headers["Content-Disposition"] as? String {
                let components = disposition.components(separatedBy: " ")
                if components.count > 1 {
                    let innerComponents = components[1].components(separatedBy: "=")
                    if innerComponents.count > 1 {
                        if innerComponents[0].contains("filename") {
                            return innerComponents[1]
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func isMimeTypeConfigured(_ mimeType:String) -> Bool {
        for record in self.mimeTypes {
            if mimeType.contains(record.type) {
                return true
            }
        }
        return false
    }
    
    private func moveDownloadedFile(url:URL, fileName:String) -> URL {
        let tempDir = NSTemporaryDirectory()
        let destinationPath = tempDir + fileName
        let destinationURL = URL(fileURLWithPath: destinationPath)
        try? FileManager.default.removeItem(at: destinationURL)
        try? FileManager.default.moveItem(at: url, to: destinationURL)
        return destinationURL
    }
}

extension WKWebviewDownloadHelper: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let mimeType = navigationResponse.response.mimeType {
            if isMimeTypeConfigured(mimeType) {
                if let url = navigationResponse.response.url {
                    if #available(iOS 14.5, *) {
                        decisionHandler(.download)
                    } else {
                        var fileName = getDefaultFileName(forMimeType: mimeType)
                        if let name = getFileNameFromResponse(navigationResponse.response) {
                            fileName = name
                        }
                        downloadData(fromURL: url, fileName: fileName) { success, destinationURL in
                            if success, let destinationURL = destinationURL {
                                self.delegate.fileDownloadedAtURL(url: destinationURL)
                            }
                        }
                        decisionHandler(.cancel)
                    }
                    return
                }
            }
        }
        decisionHandler(.allow)
    }

    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        print(" navigationresponse didbecome download ")
        download.delegate = self
    }
}

@available(iOS 14.5, *)
extension WKWebviewDownloadHelper: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let temporaryDir = NSTemporaryDirectory()
        let fileName = temporaryDir + "/" + suggestedFilename
        let url = URL(fileURLWithPath: fileName)
        fileDestinationURL = url
        completionHandler(url)
    }
    
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        print("download failed \(error)")
    }
    
    func downloadDidFinish(_ download: WKDownload) {
        print("download finish")
        if let url = fileDestinationURL {
            self.delegate.fileDownloadedAtURL(url: url)
        }
    }
}
