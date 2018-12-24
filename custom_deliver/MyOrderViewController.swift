//
//  MyOrderViewController.swift
//  custom_deliver
//
//  Created by S WEI on 2018-12-22.
//  Copyright © 2018 S WEI. All rights reserved.
//

import UIKit
import MapKit
import os

class MyOrderViewController: UIViewController {
    let logSubsystem = "com.xws."
    let logCategory = "MyOrderViewController"
    @IBOutlet weak var trackedOrdersTableView: UITableView!
    weak var mapPopUpController: MapPopUpViewController?

    var trackedOrders:[Order] = []
    override func viewDidLoad() {
        let log = OSLog(subsystem: logSubsystem, category: logCategory + ".viewDidLoad")
        super.viewDidLoad()
        trackedOrdersTableView.delegate = self
        trackedOrdersTableView.dataSource = self
        // Do any additional setup after loading the view.
        
        // Get a reference to my tracking orders
        guard let grabViewController = self.tabBarController!.viewControllers![0] as? GrabViewController else {
            os_log(.error, log: log, "Cannot cast first bar item to GrabViewController")
            return
        }
        mapPopUpController = grabViewController.mapViewController
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let log = OSLog(subsystem: logSubsystem, category: logCategory + ".viewDidAppear")
        os_log(.debug, log: log, "Number of tracked orders: %d", trackedOrders.count)
        trackedOrdersTableView.reloadData()
        if trackedOrders.count > 0 {
            trackedOrdersTableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
        }
    }

    func onLocationUpdate(mylocation: CLLocationCoordinate2D) {
        let log = OSLog(subsystem: logSubsystem, category: logCategory + ".onLocationUpdate")
        os_log(.debug, log: log, "Update route infos for tracked orders")
        
        if self.mapPopUpController == nil {
            os_log(.error, log: log, "mapViewController is nil, update aborting")
            return
        }
        
        for order in self.trackedOrders {
            if order.fromLat != 0 && order.fromLnt != 0 {
                self.mapPopUpController!.calculateRoute(from: mylocation, to: order.storeCoordinate) { (route) in
                    if let route = route {
                        order.toStoreRoute = route
                        os_log(.debug, log: log, "[order %{public}s]: Done to store route updating", order.supplyId)
                    } else {
                        os_log(.error, log: log, "[order %{public}s]: To client store updating failed", order.supplyId)
                        return
                    }
                    guard let index = self.trackedOrders.firstIndex(of: order) else {
                        os_log(.error, log: log, "[order %{public}s]: Done store route updating, but order is not in grabResults", order.supplyId)
                        return
                    }
                    
                    if self.viewIfLoaded?.window != nil {
                        let indexPath = IndexPath(row: index, section: 0)
                        self.trackedOrdersTableView.reloadRows(at: [indexPath], with: .none)
                    }
                }
            }
            
            if order.aimLat != 0 && order.aimLnt != 0 {
                self.mapPopUpController!.calculateRoute(from: mylocation, to: order.clientCoordinate) { (route) in
                    if let route = route {
                        order.toClientRoute = route
                        os_log(.debug, log: log, "[order %{public}s]: Done to client route updating", order.supplyId)
                    } else {
                        os_log(.error, log: log, "[order %{public}s]: To client route updating failed", order.supplyId)
                        return
                    }
                    guard let index = self.trackedOrders.firstIndex(of: order) else {
                        os_log(.error, log: log, "[order %{public}s]: Done client route updating, but order is not in grabResults", order.supplyId)
                        return
                    }
                    if self.viewIfLoaded?.window != nil {
                        let indexPath = IndexPath(row: index, section: 0)
                        self.trackedOrdersTableView.reloadRows(at: [indexPath], with: .none)
                    }
                }
            }
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func onClearAll(_ sender: UIButton) {
        trackedOrders.removeAll()
        self.trackedOrdersTableView.reloadData()
    }
}

extension MyOrderViewController: TrackedOrderCellDelegate {
    func onRestaurantRouteRequest(_ cell: TrackedOrderCell) {
        let log = OSLog(subsystem: logSubsystem, category: logCategory + ".onRestaurantRouteReqeust")
        if mapPopUpController == nil {
            os_log(.error, log: log, "mapPopUpController is nil")
            return
        }
        
        guard let supplyId = cell.supplyId else {
            os_log(.error, log: log, "cell supplyId is nil")
            return
        }
        
        guard let order = self.trackedOrders.first(where: {$0.supplyId == supplyId}) else {
            os_log(.error, log: log, "[order %{public}s] is not in trackedOrders", supplyId)
            return
        }
        
        cell.storeNavigationButton.isEnabled = false
        self.mapPopUpController!.navigateTo(order: order, destination: .store) { (success) in
            cell.storeNavigationButton.isEnabled = true
        }
    }
    
    func onClientRouteRequest(_ cell: TrackedOrderCell) {
        let log = OSLog(subsystem: logSubsystem, category: logCategory + ".onClientRouteReqeust")
        
        if mapPopUpController == nil {
            os_log(.error, log: log, "mapPopUpController is nil")
            return
        }
        
        guard let supplyId = cell.supplyId else {
            os_log(.error, log: log, "cell supplyId is nil")
            return
        }
        
        guard let order = self.trackedOrders.first(where: {$0.supplyId == supplyId}) else {
            os_log(.error, log: log, "[order %{public}s] is not in trackedOrders", supplyId)
            return
        }
        
        cell.clientNavigationButton.isEnabled = false
        self.mapPopUpController!.navigateTo(order: order, destination: .client) { (success) in
            cell.clientNavigationButton.isEnabled = true
        }
    }
    
    func onMapButtonPressed(_ cell: TrackedOrderCell) {
        let log = OSLog(subsystem: logSubsystem, category: logCategory)
        guard let supplyId = cell.supplyId else{
            os_log(.error, log: log, "cell supply id is nil")
            return
        }
        
        guard let order = self.trackedOrders.first(where: {$0.supplyId == supplyId}) else {
            os_log(.error, log: log, "No tracked order has supply id %{public}s", supplyId)
            return
        }
        
        if self.mapPopUpController == nil {
            os_log(.error, log: log, "mapPopUpViewController is nil, try get reference")
            guard let grabViewController = self.tabBarController!.viewControllers![0] as? GrabViewController else {
                os_log(.error, log: log, "Cannot cast first bar item to GrabViewController")
                return
            }
            mapPopUpController = grabViewController.mapViewController
        } else {
            self.present(self.mapPopUpController!, animated: true, completion: nil)
            self.mapPopUpController!.showLocationsAndRoute(order: order)
        }
    }
}

extension MyOrderViewController:  UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return trackedOrders.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "trackedOrder"
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? TrackedOrderCell else {
            fatalError("The dequeued cell is not an instance of GrabbedOrderCell.")
        }
        
        let order = self.trackedOrders[indexPath.row]
        cell.delegate = self
        cell.layer.cornerRadius = 15
        cell.aimSiteLabel.text = order.aimSite
        cell.clientNameLabel.text = order.clientName
        cell.storeNameLabel.text = order.storeName
        cell.fromSiteLabel.text = order.fromSite
        cell.distanceLabel.text = String(order.distance) + " km"
        cell.clientPhoneLabel.text = order.phone
        cell.supplyId = order.supplyId
        cell.createTimeLabel.text = order.createTime
        cell.mealTimeLabel.text = order.mealTime
        cell.appointTimeLabel.text = order.appointTime
        cell.tipsLabel.text = order.tips != nil ? "\(order.tips!)" : ""
        cell.freightLabel.text = order.freight != nil ? "\(order.freight!)" : ""
        cell.cashLabel.text = order.cash != nil ? "\(order.cash!)" : ""
        cell.subtotalLabel.text = order.money != nil ? "\(order.money!)" : ""
        
        
        if order.cash != nil && order.money != nil && order.tips != nil && order.cash == 0 {
            cell.tipsRateLabel.text = String(format: "%.1f", order.tips! / order.money! * 100) + "%"
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
        
        if order.toClientRoute != nil {
            let eta = round(order.toClientRoute!.expectedTravelTime / 60)
            let distance = order.toClientRoute!.distance / 1000
            let arrivalTime = Date() + order.toClientRoute!.expectedTravelTime
            let dfmt = DateFormatter()
            dfmt.dateFormat = "hh:mm"
            let arrivalTimeString = dfmt.string(from: arrivalTime)
            
            cell.timeToClientLabel.text = "\(arrivalTimeString)   \(eta) min  " + String(format: "%.1f", distance) + " km"
        } else {
            cell.timeToClientLabel.text = ""
        }
        
        if order.toStoreRoute != nil {
            let eta = round(order.toStoreRoute!.expectedTravelTime / 60)
            let distance = order.toStoreRoute!.distance / 1000
            let arrivalTime = Date() + order.toStoreRoute!.expectedTravelTime
            let dfmt = DateFormatter()
            dfmt.dateFormat = "hh:mm"
            let arrivalTimeString = dfmt.string(from: arrivalTime)
            
            cell.timeToStoreLabel.text = "\(arrivalTimeString)   \(eta) min  " + String(format: "%.1f", distance) + " km"
        } else {
            cell.timeToStoreLabel.text = ""
        }

        return cell
    }
}
