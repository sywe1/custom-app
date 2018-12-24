//
//  Order.swift
//  custom_deliver
//
//  Created by S WEI on 2018-12-13.
//  Copyright © 2018 S WEI. All rights reserved.
//

import UIKit
import MapKit

class Order: Equatable {
    static func == (lhs: Order, rhs: Order) -> Bool {
        return lhs.supplyId == rhs.supplyId
    }
    
    var supplyId: String
    var storeName: String
    var fromSite: String
    var aimSite: String
    var clientName: String
    var distance: Double
    var freight: Double?
    var cash: Double?
    var tips: Double?
    var money: Double?
    var phone: String?
    var createTime: String?
    var mealTime: String?
    var appointTime: String?
    
    var storeToClientRoute: MKRoute?
    var toStoreRoute: MKRoute?
    var toClientRoute: MKRoute?
    
    var aimLnt: Double = 0.0
    var aimLat: Double = 0.0
    var fromLnt: Double = 0.0
    var fromLat: Double = 0.0
    
    var value: Double? {
        get {
            if storeToClientRoute == nil || toStoreRoute == nil {
                return nil
            } else {
                let distance: Double = (self.storeToClientRoute!.distance + self.toStoreRoute!.distance) / 1000
                let tips: Double = self.tips ?? 0.0
                let freight: Double = self.freight ?? 0.0
                let netDistance: Double = (self.storeToClientRoute!.distance) / 1000
                
                
                var cost: Double = distance * 0.4
                
                if netDistance > 9.9 {
                    cost += netDistance * 0.6
                }
                
                return tips + freight - cost
            }
        }
    }
    
    var storeCoordinate: CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D(latitude: fromLat, longitude: fromLnt)
        }
        set {
            fromLat = newValue.latitude
            fromLnt = newValue.longitude
        }
    }
    
    var clientCoordinate: CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D(latitude: aimLat, longitude: aimLnt)
        }
        set {
            aimLat = newValue.latitude
            aimLnt = newValue.longitude
        }
    }
    
    
    init(supplyId: String, fromSite: String, aimSite: String, clientName: String, phone: String, storeName: String, distance: Double) {
        self.supplyId = supplyId
        self.fromSite = fromSite
        self.aimSite = aimSite
        self.clientName = clientName
        self.phone = phone
        self.storeName = storeName
        self.distance = distance
    }
    
    init?(supplyId: String, freight: Double, cash: Double, tips: Double, distance: Double, clientName: String, aimSite: String, fromSite: String, storeName: String) {
        guard !supplyId.isEmpty else {
            return nil
        }
        
        self.storeName = storeName
        self.fromSite = fromSite
        self.aimSite = aimSite
        self.clientName = clientName
        self.distance = distance
        self.freight = freight
        self.cash = cash
        self.tips = tips
        self.supplyId = supplyId
    }
}
