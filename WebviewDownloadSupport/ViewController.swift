//
//  ViewController.swift
//  WebviewDownloadSupport
//
//  Created by Nitin Bhatia on 02/02/22.
//

import UIKit
import WebKit
import WKDownloadHelper

let ss = """
<html>
<head>
<body>
<a target='_blank' href= 'https://docs.google.com/uc?export=download&amp;id=1y6bnJYuKcmw3jB7ER8s9kYRzuLU1sJ5d'> Download </a>
</body>
</html>

"""


class ViewController: UIViewController,WKNavigationDelegate,WKUIDelegate {

    @IBOutlet weak var webView: WKWebView!
    var downloadHelper: WKDownloadHelper!
    var delegate : WKDownloadHelperDelegate!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        //https://file-examples.com/index.php/sample-documents-download/sample-pdf-download/
        let link = URL(string:"https://www.learningcontainer.com/sample-pdf-files-for-testing/#")!
        let request = URLRequest(url: link)
        let mimeTypes = [MimeType(type: "ms-excel", fileExtension: "xls"),
                         MimeType(type: "pdf", fileExtension: "pdf")]
        downloadHelper = WKWebviewDownloadHelper(webView: webView, mimeTypes: mimeTypes, delegate: self)
        let x = Bundle.main.path(forResource: "Untitled", ofType: "html")!
        let y = try! String(contentsOfFile: x,encoding: .utf8)
        webView.load(request)
     // webView.loadHTMLString(y, baseURL: nil)
        webView.uiDelegate = self
       // webView.navigationDelegate = self
    }
    
    //target = _blank support in href usually
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
    
    
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.response.mimeType == "application/pdf" {
            decisionHandler(.download)
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.request.url!.absoluteString.contains("pdf") {
            print(navigationAction.request.url?.scheme)
            //decisionHandler(.download)
            UIApplication.shared.openURL(navigationAction.request.url!)
        } else {
            decisionHandler(.allow)
        }
    }
    
    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        print(" navigationresponse didbecome download ")
        download.delegate = self
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        let exceptions = SecTrustCopyExceptions(serverTrust)
        SecTrustSetExceptions(serverTrust, exceptions)
        completionHandler(.useCredential, URLCredential(trust: serverTrust));
    }
//
}

extension ViewController: WKWebViewDownloadHelperDelegate {
    
    func fileDownloadedAtURL(url: URL) {
        didDownloadFile(atUrl: url)
    }
    
    func canNavigate(toUrl: URL) -> Bool {
        true
    }
    
    func didFailDownloadingFile(error: Error) {
        print("error while downloading file \(error)")
    }
    
    func didDownloadFile(atUrl: URL) {
        print("did download file!")
        DispatchQueue.main.async {
            let activityVC = UIActivityViewController(activityItems: [atUrl], applicationActivities: nil)
            activityVC.popoverPresentationController?.sourceView = self.view
            activityVC.popoverPresentationController?.sourceRect = self.view.frame
            activityVC.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
            self.present(activityVC, animated: true, completion: nil)
        }
    }
}





@available(iOS 14.5, *)
extension ViewController: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let temporaryDir = NSTemporaryDirectory()
        let fileName = temporaryDir + "/" + suggestedFilename
        let url = URL(fileURLWithPath: fileName)
        //fileDestinationURL = url
        completionHandler(url)
    }
    
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        print("download failed \(error)")
    }
    
    func downloadDidFinish(_ download: WKDownload) {
        print("download finish")
//        if let url = fileDestinationURL {
//            self.delegate.fileDownloadedAtURL(url: url)
//        }
    }
}
