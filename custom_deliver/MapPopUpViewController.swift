//
//  MapPopUpViewController.swift
//  custom_deliver
//
//  Created by S WEI on 2018-12-25.
//  Copyright © 2018 S WEI. All rights reserved.
//

import UIKit
import MapKit
import os

enum RouteStatus {
    case calculating, done
}

enum NavigationDestination {
    case client, store
}

class StoreAnnotaion: MKPointAnnotation {
    let image = "restaurant"
}

class ClientAnnotation: MKPointAnnotation {
    let image = "client"
}

class DeliverAnnotation: MKPointAnnotation {
    let image = "ferrari"
}

class RouteQueryTask {
    let from: CLLocationCoordinate2D
    let to: CLLocationCoordinate2D
    let completion: ((MKRoute?) -> Void)
    
    init(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, compl: @escaping (MKRoute?) -> Void) {
        self.from = from
        self.to = to
        self.completion = compl
    }
}

class MapPopUpViewController: UIViewController, MKMapViewDelegate {
    // Logs
    let logSubsystem = "com.xws."
    let logCategory = "MapPopUpViewController"
    var taskQueue:[RouteQueryTask] = []
    
    var currentLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 48.448032, longitude: -123.349598)
    
    @IBOutlet weak var mapView: MKMapView!
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        // Without delegate, overlays wont shown
        self.mapView.delegate = self
        self.mapView.setRegion(MKCoordinateRegion(center: currentLocation, latitudinalMeters: 6000, longitudinalMeters: 6000), animated: true)
        self.view.bringSubviewToFront(mapView)
        self.mapView.showsUserLocation = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        os_log(.debug, log: OSLog(subsystem: logSubsystem, category: "Map appear"), "Map appear")
    }
    
    func queryRoute() {
        let log = OSLog(subsystem: logSubsystem, category: logCategory + ".queryRoute")
        if !taskQueue.isEmpty {
            let task = self.taskQueue.first!
            let from = task.from
            let to = task.to
            let completion = task.completion
            let restaurantPlacemark = MKPlacemark(coordinate: from)
            let clientPlacemark = MKPlacemark(coordinate: to)
            
            let restaurantMapItem = MKMapItem(placemark: restaurantPlacemark)
            let clientMapItem = MKMapItem(placemark: clientPlacemark)
            
            let directionRequest = MKDirections.Request()
            
            directionRequest.source = restaurantMapItem
            directionRequest.destination = clientMapItem
            directionRequest.transportType = .automobile
            
            let directions = MKDirections(request: directionRequest)
            directions.calculate { (response, error) in
                guard let response = response else {
                    if let error = error {
                        os_log(.error, log: log, "Direction from (%f, %f) to (%f, %f) request error: %{public}s",
                               from.latitude, from.longitude, to.latitude, to.longitude,
                               error.localizedDescription)
                        DispatchQueue.main.async { completion(nil) }
                    } else {
                        os_log(.error, log: log, "Direction with unknown error")
                        DispatchQueue.main.async { completion(nil) }
                    }
                    return
                }
                
                let route = response.routes[0]
                DispatchQueue.main.async { completion(route) }
            }
        }
    }
    
    func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, completion: @escaping (MKRoute?) -> Void ) {
        let log = OSLog(subsystem: logSubsystem, category: logCategory + ".calculateRoute")
        
        let restaurantPlacemark = MKPlacemark(coordinate: from)
        let clientPlacemark = MKPlacemark(coordinate: to)
        
        let restaurantMapItem = MKMapItem(placemark: restaurantPlacemark)
        let clientMapItem = MKMapItem(placemark: clientPlacemark)
        
        let directionRequest = MKDirections.Request()
        
        directionRequest.source = restaurantMapItem
        directionRequest.destination = clientMapItem
        directionRequest.transportType = .automobile
        
        let directions = MKDirections(request: directionRequest)
        directions.calculate { (response, error) in
            guard let response = response else {
                if let error = error {
                    os_log(.error, log: log, "Direction from (%f, %f) to (%f, %f) request error: %{public}s",
                           from.latitude, from.longitude, to.latitude, to.longitude,
                           error.localizedDescription)
                    DispatchQueue.main.async { completion(nil) }
                } else {
                    os_log(.error, log: log, "Direction with unknown error")
                    DispatchQueue.main.async { completion(nil) }
                }
                return
            }
            
            let route = response.routes[0]
            DispatchQueue.main.async { completion(route) }
        }
    }

    func setCurrentLocation(_ loc: CLLocationCoordinate2D) {
        self.currentLocation = loc
    }
    
    func geoCodeSite(address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        let log = OSLog(subsystem: logSubsystem, category: logCategory + ".geoCodeSite")
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { (placemarks, error) in
            if error == nil {
                if let placemark = placemarks?[0] {
                    let location = placemark.location!
                    DispatchQueue.main.async {completion(location.coordinate)}
                } else {
                    os_log(.error, log: log, "Address %{public}s empty geocoding results", address)
                    DispatchQueue.main.async {completion(nil)}
                }
            } else {
                os_log(.error, log: log, "Address %{public}s geocoding error: %{public}s", address, error!.localizedDescription)
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    func launchMapsAppToNavigate(coordinate: CLLocationCoordinate2D, name: String) {
        // let log = OSLog(subsystem: logSubsystem, category: logCategory)
        let placeMark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placeMark)
        mapItem.name = name
        let options = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        mapItem.openInMaps(launchOptions: options)
    }
    
    func navigateTo(order: Order, destination: NavigationDestination, completion: @escaping (Bool) -> () = { _ in }) {
        let log = OSLog(subsystem: logSubsystem, category: logCategory + ".navigateToClient")
        let coordinate: CLLocationCoordinate2D?
        let name: String?
        switch destination {
        case .client:
            coordinate = order.clientCoordinate
            name = order.aimSite
        default:
            coordinate = order.storeCoordinate
            name = order.fromSite
        }
        
        if coordinate!.latitude == 0.0 || coordinate!.longitude == 0.0 {
            os_log(.debug, log: log, "[order %{public}s] convert client address", order.supplyId)
            self.geoCodeSite(address: order.aimSite) { (finalCoordinate) in
                if let finalCoordinate = finalCoordinate {
                    if CLLocationCoordinate2DIsValid(finalCoordinate) {
                        completion(true)
                        self.launchMapsAppToNavigate(coordinate: finalCoordinate, name: name!)
                    } else {
                        os_log(.error, log: log, "[order %{public}s] address geocoded to invalid coordinates", order.supplyId)
                        completion(false)
                    }
                } else {
                    os_log(.error, log: log, "[order %{public}s] address geocoding error", order.supplyId)
                    completion(false)
                }
            }
        } else {
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(CLLocation(latitude: coordinate!.latitude, longitude: coordinate!.longitude)) { (placemarks, error) in
                if error == nil {
                    guard let location = placemarks?[0] else {
                        os_log(.error, log: log, "[order %{public}s] coordinates reverse geocode returned empty placemarks", order.supplyId)
                        completion(false)
                        return
                    }
                    completion(true)
                    self.launchMapsAppToNavigate(coordinate: coordinate!, name: location.name ?? "Unknown")
                } else {
                    os_log(.error, log: log, "[order %{public}s] %{public}s coordiantes reverse geocode failed", order.supplyId, name!)
                    completion(false)
                }
            }
        }
    }
    
    func renderRestaurantClient(restaurantLoc: CLLocationCoordinate2D, clientLoc: CLLocationCoordinate2D) {
        let annotations = self.mapView.annotations

        self.mapView.removeAnnotations(annotations)
        
        let restaurantPlacemark = MKPlacemark(coordinate: restaurantLoc)
        let restaurantAnnotation = StoreAnnotaion()
        
        if let location = restaurantPlacemark.location {
            restaurantAnnotation.coordinate = location.coordinate
        }
        
        let clientPlacemark = MKPlacemark(coordinate: clientLoc)
        let clientAnnotation = ClientAnnotation()
        if let location = clientPlacemark.location {
            clientAnnotation.coordinate = location.coordinate
        }

        if CLLocationCoordinate2DIsValid(clientLoc) {
            let rect = self.calculateMapRegion(coordinates: [self.currentLocation, restaurantLoc, clientLoc])
            self.mapView.setRegion(rect, animated: true)
            self.mapView.addAnnotations([restaurantAnnotation, clientAnnotation])
        } else {
            let rect = self.calculateMapRegion(coordinates: [self.currentLocation, restaurantLoc])
            self.mapView.setRegion(rect, animated: true)
            self.mapView.addAnnotations([restaurantAnnotation])
        }
    }
    
    func renderRoute(route: MKRoute?) {
        let overlays = self.mapView.overlays
        self.mapView.removeOverlays(overlays)
        
        if route != nil {
            self.mapView.addOverlay(route!.polyline, level: MKOverlayLevel.aboveRoads)
        }
    }
    
    func showLocationsAndRoute(order: Order) {
        let log = OSLog(subsystem: logSubsystem, category: logCategory + ".showLocationsAndRoute")
        
        if order.storeToClientRoute == nil {
            let group = DispatchGroup()
            group.enter()
            
            let startWaitingTime = Date()
            os_log(.debug, log: log, "[order %{public}s]: Waiting navigation info calculating...", order.supplyId)
            DispatchQueue.main.async {
                while true {
                    if order.storeToClientRoute != nil {
                        break
                    }
                    
                    if startWaitingTime.timeIntervalSinceNow > 5 {
                        os_log(.info, log: log, "[order %{public}s]: Waiting route calculating done timeout", order.supplyId)
                        break
                    }
                    
                    usleep(100000)
                }
                group.leave()
            }
            
            group.notify(queue: .main) {
                self.renderRestaurantClient(restaurantLoc: order.storeCoordinate, clientLoc: order.clientCoordinate)
                self.renderRoute(route: order.storeToClientRoute)
            }
        } else {
            self.renderRestaurantClient(restaurantLoc: order.storeCoordinate, clientLoc: order.clientCoordinate)
            self.renderRoute(route: order.storeToClientRoute)
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = UIColor(red: 17.0/255.0, green: 147.0/255.0, blue: 255.0/255.0, alpha: 1)
        renderer.lineWidth = 5.0
        return renderer
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let log = OSLog(subsystem: logSubsystem, category: logCategory + ".viewForAnnotation")
        
        if let annotation = annotation as? ClientAnnotation {
            os_log(.debug, log: log, "Add client annotation")
            let identifier = "client"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView!.annotation = annotation
            }
            
            annotationView?.image = UIImage(named: annotation.image)
            return annotationView
        } else if let annotation = annotation as? StoreAnnotaion {
            os_log(.debug, log: log, "Add restaurant annotation")
            let identifier = "store"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView!.annotation = annotation
            }
            
            annotationView?.image = UIImage(named: annotation.image)
            return annotationView
        } else if let annotation = annotation as? DeliverAnnotation{
            os_log(.debug, log: log, "Add restaurant annotation")
            let identifier = "deliver"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView!.annotation = annotation
            }
            
            annotationView?.image = UIImage(named: annotation.image)
            return annotationView
        } else {
            os_log(.error, log: log, "Annotation cannot cast to client or store")
            return nil
        }
    }
    
    func calculateMapRegion(coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        var maxLatDelta = 0.0
        var maxLngDelta = 0.0
        var centerLat = 0.0
        var centerLng = 0.0
        
        for coordinate in coordinates {
            let lat = coordinate.latitude
            let lng = coordinate.longitude
            
            centerLat += lat
            centerLng += lng
        }
        centerLat /= Double(coordinates.count)
        centerLng /= Double(coordinates.count)
        
        for coordinate in coordinates {
            let latDelta = (centerLat - coordinate.latitude).magnitude
            let lngDelta = (centerLng - coordinate.longitude).magnitude
            
            if latDelta > maxLatDelta {
                maxLatDelta = latDelta
            }
            
            if lngDelta > maxLngDelta {
                maxLngDelta = lngDelta
            }
        }

        let maxDelta = maxLatDelta > maxLngDelta ? maxLatDelta : maxLngDelta
        
        return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: centerLat,
                                                                 longitude: centerLng),
                                  span: MKCoordinateSpan(latitudeDelta: maxDelta * 2.3,
                                                         longitudeDelta: maxDelta * 2.3))
    }
    

    @IBAction func onTapCloseMapPopUp(_ sender: UITapGestureRecognizer) {
        self.dismiss(animated: true, completion: nil)
    }
}
