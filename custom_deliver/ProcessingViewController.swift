//
//  SecondViewController.swift
//  custom_deliver
//
//  Created by S WEI on 2018-12-01.
//  Copyright © 2018 S WEI. All rights reserved.
//

import UIKit
import WebKit


class ProcessingViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, WKHTTPCookieStoreObserver {
    
    @IBOutlet weak var web_container: UIView!
    var web_view: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // This view controller conforms to WKHTTPCookieStoreObserver protocol
        WKWebsiteDataStore.default().httpCookieStore.add(self)
        
        let webConfiguration = WKWebViewConfiguration()
        
        web_view = WKWebView(frame: self.web_container.bounds, configuration: webConfiguration)
        web_view.uiDelegate = self
        web_view.navigationDelegate = self
        web_view.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 12_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1"
        self.web_container.addSubview(web_view)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        for cookie in cookies {
            if cookie.domain.contains("APP") && cookie.name.contains("PHP") {
                WKWebsiteDataStore.default().httpCookieStore.setCookie(cookie) {
                    let request = self.getPickRequest()
                    self.web_view.load(request)
                }
            }
        }
    }
    
    // MARK: WKHTTPCookieStoreObserver protocol method
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
//        cookieStore.getAllCookies { (cookies) in
//            print("On cookie change, retrieve all cookies")
//            for cookie in cookies {
//                if cookie.domain.contains("APP") {
//                    print("Get cookie -- ", cookie.name, ": ", cookie.value)
//                }
//            }
//        }
    }
    
    
    // MARK: Enable tel
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.request.url?.scheme == "tel" {
            DispatchQueue.main.async {
                UIApplication.shared.open(navigationAction.request.url!, options: [:]) {
                    res in
                }
            }
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
    

    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func wenGoForward(_ sender: UIButton) {
        self.web_view.goForward()
    }

    @IBAction func webGoBackward(_ sender: UIButton) {
        self.web_view.goBack()
    }

    @IBAction func webReload(_ sender: UIButton) {
        self.web_view.reload()
    }

    func getPickRequest() -> URLRequest {
        let urlStr = "https://www.SERVER.app/wap.php?g=Wap&c=Deliver&a=pick"
        let url = URL(string: urlStr)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.addValue("zh-CN;q=0.9,en-US;q=0.8,zh;q=0.7", forHTTPHeaderField: "Accept-Language")
        request.addValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        return request
    }
}

