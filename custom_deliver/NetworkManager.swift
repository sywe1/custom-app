//
//  NetworkManager.swift
//  custom_deliver
//
//  Created by S WEI on 2018-12-16.
//  Copyright © 2018 S WEI. All rights reserved.
//

import Foundation
import os

enum RequireAction {
    case login
    case retry
    case none
    case dataParseError
    case unexpectResponseError
}

class NetworkManager: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    let logSubSystem = "com.xws.APP"
    let logCategory = "Network"
    let log = OSLog(subsystem: "com.xws.APP", category: "Network")
    let grabParseLog = OSLog(subsystem: "com.xws.APP", category: "Network.parseGrabData")
    typealias JSONDictionary = [String: Any]
    typealias GrabResult = (Int?, [Order]?, RequireAction) -> ()
    typealias TickResult = (Int?, String?, RequireAction) -> ()
    typealias LoginResult = (Int, String) -> ()
    
    var grabSession: URLSession?
    var tickSession: URLSession?
    var updateAppSession: URLSession?
    
    
    override init() {
        super.init()
        let langCookie = HTTPCookie(properties: [HTTPCookiePropertyKey.value: "zh-cn",
                                                 HTTPCookiePropertyKey.name: "lang",
                                                 HTTPCookiePropertyKey.domain: "www.APP.app",
                                                 HTTPCookiePropertyKey.path: "/",
                                                 HTTPCookiePropertyKey.expires: "2021-12-31 23:59:59 +0000"])
        HTTPCookieStorage.shared.setCookie(langCookie!)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {

        os_log(.debug, log: log, "On redirection")
        
        if response.statusCode >= 300 && response.statusCode < 400 {
            if (request.url!.description.contains("a=login")){
                completionHandler(nil)
            } else {
                os_log(.error, log: log, "Unexpected redirect url: %{public}s", request.url!.description)
            }
        } else {
            os_log(.error, log: log, "Unexpected redirect response code: %d", response.statusCode)
            completionHandler(nil)
        }
    }
    
    func login(phone: String, password: String, completion: @escaping LoginResult) {
        let loginSessin = URLSession(configuration: .default)
        let loginRequest = getLoginRequest(phone: phone, password: password)

        let loginTask = loginSessin.dataTask(with: loginRequest) { (data, response, error) in
            if let error = error {
                os_log(.error, log: self.log, "Login error: ", error.localizedDescription)
            } else if let data = data, let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    let (succeed, error, msg) = self.parseLoginData(data)
                    if succeed {
                        DispatchQueue.main.async {
                            completion(error!, msg!)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(-1, "Fail to parse login data")
                        }
                    }
                } else {
                    os_log(.error, log: self.log, "Unexpected login http resposne code %d", response.statusCode)
                    DispatchQueue.main.async {
                        completion(-1, "Unexpect login response code")
                    }
                }
            } else {
                os_log(.error, log: self.log, "Fail to unwrap login response, data")
                DispatchQueue.main.async {
                    completion(-1, "Cannot unwrap login response, data")
                }
            }
        }
        loginTask.resume()
    }
    
    func grab(lat: Double, lng: Double, completion: @escaping GrabResult){
        if grabSession  == nil {
            grabSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        }
        
        let grabRequest = getGrabRequest(lat: lat, lng: lng)
        let grabTask = grabSession!.dataTask(with: grabRequest) {
            (data, response, error) in
            if let error = error {
                os_log(.error, log: self.log, "Grab request error: %{public}s", error.localizedDescription)
            } else if let data = data, let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    let (succeed, errCode, grabbedOrders) = self.parseGrabData(data)
                    if succeed {
                        DispatchQueue.main.async { completion(errCode!, grabbedOrders!, .none) }
                    } else {
                        DispatchQueue.main.async { completion(nil, nil, .dataParseError)}
                    }
                } else if response.statusCode >= 300 && response.statusCode < 400 {
                    DispatchQueue.main.async {
                        completion(nil, nil, .login)
                    }
                } else {
                    os_log(.error, log: self.log, "Unexpected grab http resposne code %d", response.statusCode)
                    DispatchQueue.main.async { completion(-1, [], .unexpectResponseError)}
                }
            } else {
                os_log(.error, log: self.log, "Fail to unwrap grab response, data")
                DispatchQueue.main.async { completion(-1, [], .unexpectResponseError)}
            }
        }
        grabTask.resume()
    }
    
    func updateApp(lat: Double, lng: Double) {
//        if updateAppSession == nil {
//            updateAppSession = URLSession(configuration: .default)
//        }
//        let updateAppRequest = getUpdateAppRequest(lat: lat, lng: lng)
//
//        let updateAppTask = updateAppSession!.dataTask(with: updateAppRequest) { (data, response, error) in
//            if let error = error {
//                os_log(.error, log: self.log, "Update app request error: %{public}s", error.localizedDescription)
//            } else if let _ = data, let response = response as? HTTPURLResponse {
//                if response.statusCode != 200 {
//                    os_log(.error, log: self.log, "Unexpected updateapp http resposne code %d", response.statusCode)
//                }
//            } else {
//                os_log(.error, log: self.log, "Fail to unwrap updateapp response, data")
//            }
//        }
//        updateAppTask.resume()
    }
    
    func tick(id: String, completion: @escaping TickResult) {

        if tickSession == nil {
            tickSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        }
        let tickReqeust = getTickRequest(id: id)
        let tickOrder = tickSession!.dataTask(with: tickReqeust) { (data, response, error) in
            if let error = error {
                os_log(.error, log: self.log, "Tick request error: %{public}s", error.localizedDescription)
            } else if let data = data, let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    let (succeed, status, message) = self.parseTickData(data)
                    if succeed {
                        DispatchQueue.main.async {
                            completion(status!, message!, .none)
                        }
                    } else {
                        os_log(.error, log: self.log, "Fail to parse tick http response data")
                        DispatchQueue.main.async { completion(nil, nil, .dataParseError)}
                    }
                } else if response.statusCode >= 300 && response.statusCode < 400 {
                    DispatchQueue.main.async {
                        completion(nil, nil, .login)
                    }
                } else {
                    os_log(.error, log: self.log, "Unexpected tick http resposne code %d", response.statusCode)
                    DispatchQueue.main.async { completion(-1, "", .unexpectResponseError)}
                }
            } else {
                os_log(.error, log: self.log, "Fail to unwrap tick response, data")
                DispatchQueue.main.async { completion(-1, "", .unexpectResponseError)}
            }
        }
        tickOrder.resume()
    }
    
    func parseGrabData(_ data: Data) -> (succeed: Bool, errCode: Int?, grabbedOrders: [Order]?){
        var response: JSONDictionary?

        do {
            response = try JSONSerialization.jsonObject(with: data, options: []) as? JSONDictionary
        } catch let parseError as NSError {
            os_log(.error, log: self.grabParseLog, "JSONSerialization error: %{public}s", parseError.localizedDescription)
            return (false, nil, nil)
        }
        
        // Clear all orders first
        var grabbedOrders: [Order] = []

        guard let errCode = response!["err_code"] as? Int else {
            os_log(.error, log: self.grabParseLog, "Grab response dose not have err_code key")
            return (false, nil, nil)
        }
        
        os_log(.debug, log: self.grabParseLog, "Grab err_code %d", errCode)
        
        if errCode == 0 {
            guard let ordersListInResponse = response!["list"] as? [Any] else {
                os_log(.error, log: self.grabParseLog, "grab response dose not have list key")
                os_log(.error, log: self.grabParseLog, "grab response is: %s", response!.description)
                return (false, nil, nil)
            }
            for order in ordersListInResponse {
                if let order = order as? JSONDictionary {
                    guard let supplyId = order["supply_id"] as? String else {
                        os_log(.error, log: self.grabParseLog, "grabbed order dose not have supply_id key")
                        return (false, nil, nil)
                    }
                    guard let fromSite = order["from_site"] as? String else {
                        os_log(.error, log: self.grabParseLog, "grabbed order dose not have from_site key")
                        return (false, nil, nil)
                    }
                    guard let aimSite = order["aim_site"] as? String else {
                        os_log(.error, log: self.grabParseLog, "grabbed order dose not have aim_site key")
                        return (false, nil, nil)
                    }
                    guard let clientName = order["name"] as? String else {
                        os_log(.error, log: self.grabParseLog, "grabbed order dose not have client_name key")
                        return (false, nil, nil)
                    }
                    guard let phone = order["phone"] as? String else {
                        os_log(.error, log: self.grabParseLog, "grabbed order dose not have phone key")
                        return (false, nil, nil)
                    }
                    guard let storeName = order["store_name"] as? String else {
                        os_log(.error, log: self.grabParseLog, "grabbed order dose not have store_name key")
                        return (false, nil, nil)
                    }
                    guard let createTime = order["create_time"] as? String else {
                        os_log(.error, log: self.grabParseLog, "grabbed order dose not have create_time key")
                        return (false, nil, nil)
                    }
                    guard let appointTime = order["appoint_time"] as? String else {
                        os_log(.error, log: self.grabParseLog, "grabbed order dose not have appoint_time key")
                        return (false, nil, nil)
                    }
                    guard let distance = order["distance"] as? Double else {
                        os_log(.error, log: self.grabParseLog, "grabbed order dose not have distance key")
                        return (false, nil, nil)
                    }
                    
                    let orderItem = Order(supplyId: supplyId, fromSite: fromSite, aimSite: aimSite, clientName: clientName, phone: phone, storeName: storeName, distance: distance)
                    
                    orderItem.createTime = createTime
                    orderItem.appointTime = appointTime
                    
                    
                    let deliverCash = order["deliver_cash"] as? Double
                    let money = order["money"] as? String
                    let tipCharge = order["tip_charge"] as? String
                    let freightCharge = order["freight_charge"] as? Double
                    let fromLongitude = order["from_lnt"] as? String
                    let fromLatitude = order["from_lat"] as? String
                    let aimLongitude = order["aim_lnt"] as? String
                    let aimLatitude = order["aim_lat"] as? String
                    let mealTime = order["meal_time"] as? String
                    
                    orderItem.cash = deliverCash
                    orderItem.money = money != nil ? Double(money!) : nil
                    orderItem.tips = tipCharge != nil ? Double(tipCharge!) : -1.0
                    orderItem.freight = freightCharge != nil ? Double(freightCharge!) : nil
                    orderItem.aimLat = Double(aimLatitude ?? "0.0")!
                    orderItem.aimLnt = Double(aimLongitude ?? "0.0")!
                    orderItem.fromLat = Double(fromLatitude ?? "0.0")!
                    orderItem.fromLnt = Double(fromLongitude ?? "0.0")!
                    orderItem.mealTime = mealTime
                    grabbedOrders.append(orderItem)
                    
                } else {
                    os_log(.error, log: self.grabParseLog, "unable to convert order to JSON")
                    os_log(.error, log: self.grabParseLog, "order is %@", ordersListInResponse)
                    return (false, nil, nil)
                }
            }
            grabbedOrders.sort(by: { $0.tips! > $1.tips! })
            os_log(.debug, log: log, "Grabbed orders size: %d", grabbedOrders.count)
        }
        return (true, errCode, grabbedOrders)
    }

    func parseLoginData(_ data: Data) -> (succeed: Bool, error: Int?, msg: String?) {
        
        let customLog = OSLog(subsystem: self.logSubSystem, category: self.logCategory + ".parseLoginData")

        if let response = try? JSONSerialization.jsonObject(with: data, options: []) as? JSONDictionary {
            guard let error = response!["error"] as? Int else {
                os_log(.error, log: customLog, "Login response does not have error key")
                os_log(.error, log: customLog, "Login response is: %{public}s", response!.description)
                return (false, nil, nil)
            }
            guard let msg = response!["msg"] as? String else {
                os_log(.error, log: customLog, "Login response does not have msg key")
                os_log(.error, log: customLog, "Login response is: %{public}s", response!.description)
                return (false, nil, nil)
            }
            os_log(.debug, log: customLog, "Login response %{public}s", msg)
            return (true, error, msg)
        } else {
            os_log(.error, log: customLog, "Cannot convert login response as JSON")
            return (false, nil, nil)
        }
    }
    
    func parseTickData(_ data: Data) -> (succeed: Bool, status: Int?, info: String?) {
        let customLog = OSLog(subsystem: logSubSystem, category: logCategory + ".parseTickData")
        var response: JSONDictionary?
        
        do {
            response = try JSONSerialization.jsonObject(with: data, options: []) as? JSONDictionary
        } catch let parseError as NSError {
            os_log(.error, log: customLog, "JSONSerialization error: %{public}s", parseError.localizedDescription)
            return (false, nil, "JSONSerialization failed")
        }

        guard let status = response!["status"] as? Int else {
            os_log(.error, log: customLog, "Tick response dose not have err_code key")
            return (false, nil, "No err_code key in tick response")
        }

        guard let msg = response!["info"] as? String else {
            os_log(.error, log: customLog, "Tick response dose not have info key")
            return (false, nil, "No info key in tick response")
        }
        os_log(.info, log: customLog, "Tick result: STATUS: %d, INFO: %{public}s", status, msg)
       
        return (true, status, msg)
    }
    
    func getLoginRequest(phone: String, password: String) -> URLRequest {
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
        request.addValue("URL", forHTTPHeaderField: "Referer")
        request.addValue("Mozilla/5.0 (iPhone; CPU iPhone OS 12_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        request.httpBody = ("phone=" + phone + "&pwd=" + password).data(using: String.Encoding.utf8)
        return request
    }
    
    func getUpdateAppRequest(lat: Double, lng: Double) -> URLRequest {
        guard let url = URL(string: "URL") else {
            fatalError("Fail to parse login url")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("*/*", forHTTPHeaderField: "Accept")
        request.addValue("URL", forHTTPHeaderField: "Referer")
        request.addValue("zh-CN;q=0.9,en-US;q=0.8,zh;q=0.7", forHTTPHeaderField: "Accept-Language")
        request.addValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.addValue("1", forHTTPHeaderField: "DNT")
        request.addValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue("Mozilla/5.0 (iPhone; CPU iPhone OS 12_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        let body = "lat=" + String(lat) + "&lng=" + String(lng)
        request.httpBody = body.data(using: String.Encoding.utf8)

        return request
    }
    
    func getGrabRequest(lat: Double, lng: Double) -> URLRequest {
        let urlStr = "URL"
        let grabUrl = URL(string: urlStr)!
        
        var grabRequest = URLRequest(url: grabUrl)
        grabRequest.httpMethod = "GET"
        grabRequest.addValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        grabRequest.addValue("URL", forHTTPHeaderField: "Referer")
        grabRequest.addValue("zh-CN;q=0.9,en-US;q=0.8,zh;q=0.7", forHTTPHeaderField: "Accept-Language")
        grabRequest.addValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        grabRequest.addValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        grabRequest.addValue("Mozilla/5.0 (iPhone; CPU iPhone OS 12_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        return grabRequest
    }

    func getTickRequest(id: String) -> URLRequest {
        let urlStr = "URL"
        let tickUrl = URL(string: urlStr)!
        
        var tickRequest = URLRequest(url: tickUrl)
        tickRequest.httpMethod = "POST"
        tickRequest.addValue("*/*", forHTTPHeaderField: "Accept")
        tickRequest.addValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        tickRequest.addValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        tickRequest.addValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        tickRequest.addValue("zh-CN;q=0.9,zh;q=0.8,en-US;q=0.7", forHTTPHeaderField: "Accept-Language")
        tickRequest.addValue("Mozilla/5.0 (iPhone; CPU iPhone OS 12_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        let order_id = "supply_id=" + id
        tickRequest.httpBody = order_id.data(using: .utf8)
        return tickRequest
    }
}

