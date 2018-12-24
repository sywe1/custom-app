import UIKIT
import WebKit

extension WKWebView {

   private var httpCookieStore: WKHTTPCookieStore  {
       return WKWebsiteDataStore.default().httpCookieStore
   }

   func getCookies(for domain: String? = nil, completion: @escaping ([String : Any])->())  {
       var cookieDict = [String : AnyObject]()
       httpCookieStore.getAllCookies { (cookies) in
           for cookie in cookies {
               if let domain = domain {
                   if cookie.domain.contains(domain) {
                       cookieDict[cookie.name] = cookie.properties as AnyObject?
                   }
               } else {
                   cookieDict[cookie.name] = cookie.properties as AnyObject?
               }
           }
           completion(cookieDict)
       }
   }
}

// Dump cookies
extension ProcessingViewController {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
       if let url = webView.url {
           webView.getCookies(for: ".app") {
               data in
               print("=========================================")
               print("\(url.absoluteString)")
               print(data)
               print("=========================================")
           }
       } else {
           print("Url not found")
       }
    } 
}

// Retrieve xhr
extension ProcessingViewController:  WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
       if let dict = message.body as? Dictionary<String, AnyObject>, let status = dict["status"] as? Int, let responseUrl = dict["responseURL"] as? String {
           print(status)
           print(responseUrl)
           print(dict)
       }
    }

   private func getScript() -> String {
       if let filepath = Bundle.main.path(forResource: "script", ofType: "js") {
           do {
               return try String(contentsOfFile: filepath)
           } catch {
               print(error)
           }
       } else {
           print("script.js not found!")
       }
       return ""
   }
}