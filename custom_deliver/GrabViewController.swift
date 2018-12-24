//
//  FirstViewController.swift
//  custom_deliver
//
//  Created by S WEI on 2018-12-01.
//  Copyright © 2018 S WEI. All rights reserved.
//

import UIKit
import CoreLocation
import os
import MapKit

enum NotificationCategory {
    case info
    case error
}

class GrabViewController: UIViewController, GrabbedOrderCellDelegate, CLLocationManagerDelegate{
    
    let logSubSystem = "com.xws."
    let logCategory = "GrabViewController"
    
    @IBOutlet weak var responseAnimationView: UIView!
    @IBOutlet weak var notificationLabel: UILabel!
    @IBOutlet weak var grabbedListView: UITableView!
    @IBOutlet weak var autoModeSwitch: UIButton!
    var timer = Timer()
    var gpsTimer = Timer()
    var grabTimer = Timer()
    var grabResults = [Order]()
    var dismissBottomBannerTimer = Timer()
    let locationManager = CLLocationManager()
    var networkManager = NetworkManager()
    var mapViewController: MapPopUpViewController?
    weak var myOrdersViewController: MyOrderViewController!

    var myCoordinates: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
    
    var autoTick: Bool = false {
        willSet (switchAutoTick) {
            self.onAutoTickSwitch(on: switchAutoTick)
            autoModeSwitch.setTitle(String(self.autoTickTipsBar), for: .normal)
        }
    }
    var autoTickTipsBar: Double = 10.0 {
        willSet (bar) {
            autoModeSwitch.setTitle(String(bar), for: .normal)
        }
    }
    var autoTickWeightBar: Double = 10.0
    var autoTickOnTipsGTFreight: Bool = true {
        willSet (enable) {
            if self.autoTick {
                if enable {
                    self.responseAnimationView.backgroundColor = UIColor.red
                } else {
                    self.responseAnimationView.backgroundColor = UIColor.orange
                }
            }
        }
    }

    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        configLayouts()

        grabbedListView.delegate = self
        grabbedListView.dataSource = self
        
        // Request location authrization
        locationManager.requestAlwaysAuthorization()
        locationManager.requestWhenInUseAuthorization()
        
        // Set location delegate to self and set location accuracy
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        }
        
        // Instantiate map pop up
        mapViewController = self.storyboard?.instantiateViewController(withIdentifier: "mapPopUpViewController") as? MapPopUpViewController
        if mapViewController == nil {
            os_log(.error, log: OSLog(subsystem: logSubSystem, category: logCategory), "Cannot construct MapPopUpViewController")
        }
        
        // Get a reference to my tracking orders
        myOrdersViewController = self.tabBarController!.viewControllers![1] as? MyOrderViewController
        if myOrdersViewController == nil {
            os_log(.error, log: OSLog(subsystem: ".GrabViewController", category: "viewDidLoad"), "cannot cast second bar item to MyOrderViewController")
        }
        
        // Try login to  first.
        tryLogin(continueTo: nil)
    }
    
    
    func configLayouts() {
        responseAnimationView.layer.cornerRadius = 5.0
        autoModeSwitch.setTitleColor(UIColor.white, for: .normal)
        autoTickTipsBar = 8.0
        autoTick = false
        notificationLabel.isHidden = true
        notificationLabel.backgroundColor = UIColor.green
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let log = OSLog(subsystem: logSubSystem, category: logCategory + ".locationManager")
        guard let locValue: CLLocationCoordinate2D = manager.location?.coordinate else {
            os_log(.error, log: log, "Cannot get location")
            return
        }
        self.myCoordinates = locValue
        
        if self.mapViewController != nil {
            self.mapViewController!.setCurrentLocation(locValue)
        }
        manager.stopUpdatingLocation()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        // Dispose of any resources that can be recreated.
    }
    
    func tryLogin(continueTo: (()->())?) {
        let log = OSLog(subsystem: logSubSystem, category: logCategory + ".tryLogin")
        self.networkManager.login(phone: "PHONE", password: "123456") { (err, msg) in
            if err == 0 {
                if continueTo != nil {
                    DispatchQueue.main.async {
                        continueTo!()
                    }
                } else {
                    self.showBottomBanner(category: .info, message: "\(msg)", color: UIColor(red: 0.3, green: 0.72, blue: 0.25, alpha: 1.0), expiresIn: 2.5)
                    DispatchQueue.main.async {
                        self.startGrabOrders()
                        self.startUpdatePos()
                        self.getCurrentLocation()
                    }
                }
            } else {
                os_log(.error, log: log, "Login failed with %{public}s", msg)
            }
        }
    }
    
    func onLocationUpdate() {
        let log = OSLog(subsystem: logSubSystem, category: logCategory + ".onLocationUpdate")
        os_log(.debug, log: log, "Update route infos for grabbed orders")
        
        if self.mapViewController == nil {
            os_log(.error, log: log, "mapViewController is nil, update aborting")
            return
        }
        
        for order in self.grabResults {
            if order.fromLat != 0 && order.fromLnt != 0 {
                self.mapViewController!.calculateRoute(from: self.myCoordinates, to: order.storeCoordinate) { (route) in
                    if let route = route {
                        order.toStoreRoute = route
                        os_log(.debug, log: log, "[order %{public}s]: Done to store route updating", order.supplyId)
                    } else {
                        os_log(.error, log: log, "[order %{public}s]: To store route updating failed", order.supplyId)
                        return
                    }
                    guard let index = self.grabResults.firstIndex(of: order) else {
                        os_log(.error, log: log, "[order %{public}s]: Done store route updating, but order is not in grabResults", order.supplyId)
                        return
                    }
                    let indexPath = IndexPath(row: index, section: 0)
                    self.grabbedListView.reloadRows(at: [indexPath], with: .none)
                }
            }
            
            if order.aimLat != 0 && order.aimLnt != 0 {
                self.mapViewController!.calculateRoute(from: self.myCoordinates, to: order.clientCoordinate) { (route) in
                    if let route = route {
                        order.toClientRoute = route
                        os_log(.debug, log: log, "[order %{public}s]: Done to client route updating", order.supplyId)
                    } else {
                        os_log(.error, log: log, "[order %{public}s]: To client route updating failed", order.supplyId)
                        return
                    }
                    guard let index = self.grabResults.firstIndex(of: order) else {
                        os_log(.error, log: log, "[order %{public}s]: Done client route updating, but order is not in grabResults", order.supplyId)
                        return
                    }
                    let indexPath = IndexPath(row: index, section: 0)
                    self.grabbedListView.reloadRows(at: [indexPath], with: .none)
                }
            }
        }
    }
    
    func updateRouteInfo() {
        let log = OSLog(subsystem: logSubSystem, category: logCategory + ".updateRouteInfo")
        
        if self.mapViewController == nil {
            os_log(.error, log: log, "mapViewController is nil, update aborting")
            return
        }
        
        for order in self.grabResults {
            if order.fromLat == 0.0 || order.fromLnt == 0.0 {
                self.mapViewController!.geoCodeSite(address: order.fromSite) { (coordinate) in
                    if let coordinate = coordinate {
                        order.storeCoordinate = coordinate
                        os_log(.debug, log: log, "[order %{public}s]: Successfully reverse geocode store site %{public}s", order.supplyId, order.fromSite)
                        
                        if order.aimLat != 0.0 && order.aimLnt != 0.0 {
                            self.mapViewController!.calculateRoute(from: coordinate, to: order.clientCoordinate, completion: { (route) in
                                if let route = route {
                                    os_log(.debug, log: log, "[order %{public}s]: receive route info: destination(%f), ETA(%f)", order.supplyId, route.distance, route.expectedTravelTime)
                                    order.storeToClientRoute = route
                                    
                                    guard let index = self.grabResults.firstIndex(of: order) else {
                                        os_log(.error, log: log, "[order %{public}s]:Done store to client route calculation, but order is not in grabResults", order.supplyId)
                                        return
                                    }
                                    let indexPath = IndexPath(row: index, section: 0)
                                    self.grabbedListView.reloadRows(at: [indexPath], with: .none)
                                }
                            })
                        }
                    } else {
                        os_log(.error, log: log, "[order %{public}s]: reverse geocode store address %{public}s failed", order.supplyId, order.fromSite)
                    }
                }
            }
            
            if order.aimLat == 0.0 || order.aimLnt == 0.0 {
                self.mapViewController!.geoCodeSite(address: order.aimSite) { (coordinate) in
                    if let coordinate = coordinate {
                        order.clientCoordinate = coordinate
                        os_log(.debug, log: log, "[order %{public}s]: Successfully reverse geocode client site %{public}s", order.supplyId, order.aimSite)
                        
                        if order.fromLat != 0.0 && order.fromLnt != 0.0 {
                            self.mapViewController!.calculateRoute(from: order.storeCoordinate, to: coordinate, completion: { (route) in
                                if let route = route {
                                    os_log(.debug, log: log, "[order %{public}s]: receive route info: destination(%f), ETA(%f)", order.supplyId, route.distance, route.expectedTravelTime)
                                    order.storeToClientRoute = route
                                    
                                    guard let index = self.grabResults.firstIndex(of: order) else {
                                        os_log(.error, log: log, "[order %{public}s]:Done store to client route calculation, but order is not in grabResults", order.supplyId)
                                        return
                                    }
                                    let indexPath = IndexPath(row: index, section: 0)
                                    self.grabbedListView.reloadRows(at: [indexPath], with: .none)
                                }
                            })
                        }
                    } else {
                        os_log(.error, log: log, "[order %{public}s]: reverse geocode store address %{public}s failed", order.supplyId, order.aimSite)
                    }
                }
            }
            
            if order.storeToClientRoute == nil {
                if order.aimLat != 0 && order.aimLnt != 0 && order.fromLat != 0 && order.fromLnt != 0 {
                    self.mapViewController!.calculateRoute(from: order.storeCoordinate, to: order.clientCoordinate) { (route) in
                        if let route = route {
                            os_log(.debug, log: log, "[order %{public}s]: receive route info: destination(%f), ETA(%f)", order.supplyId, route.distance, route.expectedTravelTime)
                            order.storeToClientRoute = route
                            
                            guard let index = self.grabResults.firstIndex(of: order) else {
                                os_log(.error, log: log, "[order %{public}s]:Done store to client route calculation, but order is not in grabResults", order.supplyId)
                                return
                            }
                            let indexPath = IndexPath(row: index, section: 0)
                            self.grabbedListView.reloadRows(at: [indexPath], with: .none)
                        }
                    }
                }
            }
            
            if order.toStoreRoute == nil {
                if order.fromLat != 0 && order.fromLnt != 0 {
                    self.mapViewController!.calculateRoute(from: self.myCoordinates, to: order.storeCoordinate) { (route) in
                        if let route = route {
                            order.toStoreRoute = route
                            os_log(.debug, log: log, "[order %{public}s]: Done to store route initialize", order.supplyId)
                        } else {
                            os_log(.error, log: log, "[order %{public}s]: To store route updating failed", order.supplyId)
                            return
                        }
                        guard let index = self.grabResults.firstIndex(of: order) else {
                            os_log(.error, log: log, "[order %{public}s]: Done store route calculation, but order is not in grabResults", order.supplyId)
                            return
                        }
                        let indexPath = IndexPath(row: index, section: 0)
                        self.grabbedListView.reloadRows(at: [indexPath], with: .none)
                    }
                }
            }
            
            if order.toClientRoute == nil {
                if order.aimLat != 0 && order.aimLnt != 0 {
                    self.mapViewController!.calculateRoute(from: self.myCoordinates, to: order.clientCoordinate) { (route) in
                        if let route = route {
                            order.toClientRoute = route
                            os_log(.debug, log: log, "[order %{public}s]: Done to client route initialize", order.supplyId)
                        } else {
                            os_log(.error, log: log, "[order %{public}s]: To client route updating failed", order.supplyId)
                            return
                        }
                        guard let index = self.grabResults.firstIndex(of: order) else {
                            os_log(.error, log: log, "[order %{public}s]: Done client route calculation, but order is not in grabResults", order.supplyId)
                            return
                        }
                        let indexPath = IndexPath(row: index, section: 0)
                        self.grabbedListView.reloadRows(at: [indexPath], with: .none)
                    }
                }
            }
        }
    }
    
    func showBottomBanner(category: NotificationCategory, message: String, color: UIColor? = nil, expiresIn: Double = 3.0) {
        notificationLabel.textColor = UIColor.white
        notificationLabel.text = message
        
        switch category {
        case .info:
            if color == nil {
                self.notificationLabel.backgroundColor = UIColor.blue
            } else {
                self.notificationLabel.backgroundColor = color
            }
        case .error:
            if color == nil {
                self.notificationLabel.backgroundColor = UIColor.red
            } else {
                self.notificationLabel.backgroundColor = color
            }
        }
        UIView.transition(with: self.notificationLabel, duration: 0.5, options: .transitionFlipFromTop, animations: {self.notificationLabel.isHidden = false})
        self.dismissBottomBannerTimer.invalidate()
        
        if category == .info {
            self.dismissBottomBannerTimer = Timer.scheduledTimer(withTimeInterval: expiresIn, repeats: false, block: { timer in
                self.notificationLabel.isHidden = true
            })
        }
    }
    
    func animateGrabResponse() {
        UIView.animate(withDuration: 0.6, animations: {
            self.responseAnimationView.transform = CGAffineTransform(scaleX: 1.5, y: 1.0)
        }) { (done) in
            UIView.animate(withDuration: 0.6, animations: {
                self.responseAnimationView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            })
        }
    }
    
    func onGrabResponse(err:Int?, results: [Order]?, action: RequireAction) {
        let log = OSLog(subsystem: logSubSystem, category: logCategory + ".onGrabResponse")
        
        switch action {
        case .none:
            guard let results = results else {
                os_log(.error, log: log, "Grab results is nil")
                return
            }
            
            if self.grabResults != results {
                // Get the common orders in current orders list and new orders list.
                self.grabResults = self.grabResults.filter( { results.contains($0) })
                
                os_log(.debug, log: log, "Current result size: %d", self.grabResults.count)
                
                // Get the orders in new orders list but not in current orders list
                let tobeAdded = results.filter( { !self.grabResults.contains($0) })
                os_log(.debug, log: log, "To be added  size: %d", tobeAdded.count)
                // Append the new orders to the current orders list.
                self.grabResults.append(contentsOf: tobeAdded)
                self.grabResults.sort(by: { $0.tips! > $1.tips! })
                self.grabbedListView.reloadData()
                updateRouteInfo()
            }
            os_log(.debug, log: log, "OK")
            animateGrabResponse()
            if autoTick {
                autoTickScan()
            }
            self.autoModeSwitch.setTitle("当前 " + String(self.grabResults.count) + " 单 (\(self.autoTickTipsBar))", for: .normal)
        case .login:
            self.showBottomBanner(category: .info, message: "需要重新登陆", color: UIColor.green)
            self.tryLogin() {
                self.grabOrders()
            }
        case .dataParseError:
            self.showBottomBanner(category: .error, message: "订单内容解析失败")
        case .unexpectResponseError:
            self.showBottomBanner(category: .error, message: "未知HTTP代码")
        default:
            os_log(.error, log: log, "Unexpected action")
        }
    }

    
    @IBAction func changeAutoMode(_ sender: UIButton) {
        print("Change autoTick status")
        autoTick = !autoTick
    }

    
    func onAutoTickSwitch(on: Bool) {
        if on {
            if autoTickOnTipsGTFreight {
                self.responseAnimationView.backgroundColor = UIColor.red
            } else {
                self.responseAnimationView.backgroundColor = UIColor.orange
            }
        } else {
            self.responseAnimationView.backgroundColor = UIColor.gray
        }
        UIView.transition(with: self.responseAnimationView, duration: 1.0, options: .transitionFlipFromTop, animations: nil)
    }


    func tickButtonPressedFrom(_ cell: GrabbedOrderCell) {
        let log = OSLog(subsystem: logSubSystem, category: logCategory + ".tickButtonPressedFrom")
        guard let supplyId = cell.supplyId else {
            os_log(.error, log: log, "Cell does not have supplyId property")
            return
        }
        tickOrder(withId: supplyId)
    }
    

    func mapButtonPressedFrom(_ cell: GrabbedOrderCell) {
        let log = OSLog(subsystem: logSubSystem, category: logCategory + ".mapButtonPressedFrom")
        if mapViewController == nil {
            os_log(.error, log: log, "mapPopUpViewController is nil")
            self.showBottomBanner(category: .error, message: "地图组件初始化失败", color: nil, expiresIn: 2.0)
            return
        }
        
        guard let supplyId = cell.supplyId else {
            os_log(.error, log: log, "Cell supply id is nil, give up navigation")
            self.showBottomBanner(category: .error, message: "订单ID为空", color: nil, expiresIn: 2.0)
            return
        }
        
        guard let targetOrder = self.grabResults.first(where: {$0.supplyId == supplyId}) else {
            os_log(.error, log:log, "Target order not found")
            self.showBottomBanner(category: .error, message: "订单详情未找到", color: nil, expiresIn: 2.0)
            return
        }
        
        self.present(mapViewController!, animated: true, completion: nil)
        self.mapViewController!.showLocationsAndRoute(order: targetOrder)
    }
    
    func autoTickScan() {
        for order in self.grabResults {
            if order.tips != nil {
                if order.tips! >= autoTickTipsBar {
                    if autoTickOnTipsGTFreight {
                        if order.tips! >= order.freight! {
                            tickOrder(withId: order.supplyId)
                            self.autoTick = false
                            break
                        }
                    } else {
                        tickOrder(withId: order.supplyId)
                        self.autoTick = false
                        break
                    }
                }
            }
        }
    }
    
    func tickOrder(withId: String) {
        let log = OSLog(subsystem: logSubSystem, category: logCategory + ".tickOrder")
        networkManager.tick(id: withId ) {
            (status, info, action) in
            switch action {
            case .none:
                os_log(.info, log: log, "Tick order result: %{public}s", info!)
                self.showBottomBanner(category: .info, message: "抢单完成： \(info!)")
                if status != 0 {
                    if self.myOrdersViewController != nil {
                        if let targetOrder = self.grabResults.first(where: {$0.supplyId == withId}) {
                            self.myOrdersViewController!.trackedOrders.insert(targetOrder, at: 0)
                            self.grabResults = self.grabResults.filter { $0.supplyId != withId }
                            self.grabbedListView.reloadData()
                        } else {
                            os_log(.error, log: log, "Target order %{public}s not found in grabResults", withId)
                        }
                    } else {
                        os_log(.error, log: log, "myOrderViewController is nil")
                    }
                }
            case .login:
                self.showBottomBanner(category: .info, message: "重新登陆", color: UIColor.green)
                self.tryLogin() {
                    self.tickOrder(withId: withId)
                }
            case .dataParseError:
                self.showBottomBanner(category: .error, message: "抢单返回内容解析失败")
            case .unexpectResponseError:
                self.showBottomBanner(category: .error, message: "抢单返回未知HTTP代码")
            default:
                os_log(.error, log: log, "Unhandled case")
            }
        }
    }
    
    func startGrabOrders() {
        grabTimer.invalidate()
        grabTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(GrabViewController.grabOrders), userInfo: nil, repeats: true)
    }
    
    func startUpdatePos() {
        gpsTimer.invalidate()
        gpsTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: (#selector(GrabViewController.getCurrentLocation)), userInfo: nil, repeats: true)
    }
    
    @objc func grabOrders() {
        networkManager.grab(lat: self.myCoordinates.latitude, lng: self.myCoordinates.longitude, completion: self.onGrabResponse(err:results:action:))
    }
    
    @objc func getCurrentLocation() {
        locationManager.startUpdatingLocation()
        self.onLocationUpdate()
        self.myOrdersViewController.onLocationUpdate(mylocation: self.myCoordinates)
    }

}


extension GrabViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.grabResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "availableOrder"
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? GrabbedOrderCell else {
            fatalError("The dequeued cell is not an instance of GrabbedOrderCell.")
        }
        cell.tickButton.layer.cornerRadius = 13
        cell.tickButton.layer.masksToBounds = true
        
        cell.delegate = self
        let order = grabResults[indexPath.row]
        cell.layer.cornerRadius = 15
        cell.aimSiteLabel.text = order.aimSite
        cell.clientNameLabel.text = order.clientName
        cell.storeNameLabel.text = order.storeName
        cell.fromSiteLabel.text = order.fromSite
        cell.clientPhoneLabel.text = order.phone
        cell.supplyId = order.supplyId
        cell.createTimeLabel.text = order.createTime
        cell.appointTimeLabel.text = order.appointTime
        cell.mealTimeLabel.text = order.mealTime
        cell.tipsLabel.text = order.tips != nil ? "\(order.tips!)" : ""
        cell.freightLabel.text = order.freight != nil ? "\(order.freight!)" : ""
        cell.cashLabel.text = order.cash != nil ? "\(order.cash!)" : ""
        cell.subtotalLabel.text = order.money != nil ? "\(order.money!)" : ""
        
        cell.tipsLabel.textColor = UIColor.black
        cell.tipsLabel.font = UIFont.systemFont(ofSize: 17)
        
        if order.tips != nil {
            if order.tips! > 7 {
                cell.tipsLabel.font = UIFont.boldSystemFont(ofSize: 17)
            }
            if order.tips! > 10 {
                cell.tipsLabel.textColor = UIColor.red
            }
        }
        
        if order.cash != nil && order.money != nil && order.tips != nil && order.cash == 0 {
            cell.tipsRateLabel.text = String(format: "%.1f", order.tips! / order.money! * 100.0) + "%"
        } else {
            cell.tipsRateLabel.text = ""
        }
        
        if order.storeToClientRoute == nil {
            cell.distanceLabel.text = String(order.distance) + " km"
            cell.etaLabel.text = ""
            cell.valueLabel.text = ""
        } else {
            let eta = round(order.storeToClientRoute!.expectedTravelTime / 60)
            let distance = order.storeToClientRoute!.distance / 1000
            cell.distanceLabel.text = String(format: "%.1f", distance) + " km"
            cell.etaLabel.text =  String(eta) + " min"
            cell.distanceLabel.font = UIFont.italicSystemFont(ofSize: 15)
            cell.etaLabel.font = UIFont.italicSystemFont(ofSize: 15)
            cell.valueLabel.text = order.value == nil ? "" : String(format: "%.2f", order.value!)
        }
        
        if order.toStoreRoute != nil {
            let eta = round(order.toStoreRoute!.expectedTravelTime / 60)
            let distance = order.toStoreRoute!.distance / 1000
            let arrivalTime = Date() + order.toStoreRoute!.expectedTravelTime
            let dfmt = DateFormatter()
            dfmt.dateFormat = "hh:mm"
            let arrivalTimeString = dfmt.string(from: arrivalTime)
            cell.timeToStoreLabel.text = "\(arrivalTimeString)   \(eta) min  " + String(format: "%.1f", distance) + " km"
            
            if order.storeToClientRoute != nil {
                let toClientTime = order.toStoreRoute!.expectedTravelTime + order.storeToClientRoute!.expectedTravelTime + 180
                let toClientDistance = distance + order.storeToClientRoute!.distance / 1000
                let clientArrivalTime = Date() + toClientTime
                let clientArrivalTimeString = dfmt.string(from: clientArrivalTime)
                cell.timeToClientLabel.text = "\(clientArrivalTimeString)   \(round(toClientTime / 60)) min  " + String(format: "%.1f", toClientDistance) + " km"
            } else {
                cell.timeToClientLabel.text = ""
            }
            
        } else {
            cell.timeToStoreLabel.text = ""
        }
        
        return cell
    }
}
