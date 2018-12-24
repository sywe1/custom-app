//
//  GrabService.swift
//  custom_deliver
//
//  Created by S WEI on 2018-12-15.
//  Copyright © 2018 S WEI. All rights reserved.
//

import Foundation

class GrabService: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    
    func getLoginRequest() -> URLRequest {
        guard let url = URL(string: "URL") else {
            fatalError("Fail to parse login url")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.addValue("URL", forHTTPHeaderField: "Referer")
        request.addValue("zh-CN;q=0.9,en-US;q=0.8,zh;q=0.7", forHTTPHeaderField: "Accept-Language")
        request.addValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.addValue("1", forHTTPHeaderField: "DNT")
        request.addValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue("37", forHTTPHeaderField: "Content-Length")
        request.addValue("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        request.httpBody = "phone=PHONE&pwd=PWD".data(using: String.Encoding.utf8)
        
        print("Request body: " + String(data: request.httpBody!, encoding: String.Encoding.utf8)!)
        
        return request
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        if response.statusCode >= 300 && response.statusCode < 400 {
            print("Server redirect, try login")
            
        }
        completionHandler(nil)
    }
    
    func login() {
        let request = getLoginRequest()
        let session = URLSession(configuration: .default)
        
        let loginTask = session.dataTask(with: request) {
            (data, response, error) in
            if let error = error {
                print("[ERROR]GrabService.login(): " + error.localizedDescription)
            } else if let data = data, let response = response as? HTTPURLResponse {
                if response.statusCode != 200 {
                    print("[ERROR]GrabSerivce.login(): Expect response code is 200, but actual is \(response.statusCode)")
                } else {
                    do {
                        let resultObj = try JSONSerialization.jsonObject(with: data, options: [])
                        print(resultObj)
                        
                    } catch {print("Unable to parse json")}
                }
            }
        }
        loginTask.resume()
    }
    
    func grab(){
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        if let grabUrl = URL(string: "URL") {
            
            var urlRequest = URLRequest(url: grabUrl)
            
            urlRequest.httpMethod = "GET"
            urlRequest.addValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
            urlRequest.addValue("URL", forHTTPHeaderField: "Referer")
            urlRequest.addValue("zh-CN;q=0.9,en-US;q=0.8,zh;q=0.7", forHTTPHeaderField: "Accept-Language")
            urlRequest.addValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
            urlRequest.addValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
            
            let dataTask = session.dataTask(with: urlRequest) {
                (data, response, error) in
                if let error = error {
                    print("GrabService: ERROR: " + error.localizedDescription)
                } else if let data = data, let response = response as? HTTPURLResponse {
                    if response.statusCode >= 300 && response.statusCode < 400 {
                        print("Response: \(response.statusCode), login required!")
                    }
                } else {
                    print("GrabService: ERROR: Cannot convert data, response")
                }
            }
            
            dataTask.resume()
        }
    }
}
