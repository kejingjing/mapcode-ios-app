//
// ViewController.swift
// Mapcode
//
// Copyright (C) 2016 Stichting Mapcode Foundation (http://www.mapcode.com)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import UIKit
import CoreLocation
import MapKit

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {

    @IBOutlet weak var theMap: MKMapView!
    @IBOutlet weak var theError: UILabel!
    @IBOutlet weak var theCoordinates: UILabel!
    @IBOutlet weak var theMapcode: UILabel!
    
    let defaultSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
    var dataTask: NSURLSessionDataTask?
    
    var manager: CLLocationManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup our Location Manager.
        manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        
        // Setup our Map View.
        theMap.delegate = self
        theMap.mapType = MKMapType.Standard
        theMap.showsUserLocation = true
    }
    
    func locationManager(manager: CLLocationManager,
                         didUpdateLocations locations:[CLLocation]) {
        let lat = locations[0].coordinate.latitude
        let lon = locations[0].coordinate.longitude
        
        // Show map.
        let spanX = 0.01
        let spanY = 0.01
        let newRegion = MKCoordinateRegion(center: theMap.userLocation.coordinate,
                                           span: MKCoordinateSpanMake(spanX, spanY))
        theMap.setRegion(newRegion, animated: true)
        
        theError.text = ""
        theCoordinates.text = "latitude=\(lat)\nlongitude=\(lon)"
        
        // Don't ask for mapcode if already busy.
        if (dataTask != nil) {
            dataTask?.cancel()
            theError.text = "Cancelled request..."
            return
        }

        // Construct latitude, longitude string from coordinates.
        let stringLatLon = "\(lat),\(lon)"
        
        // Make sure we encode the URL correctly.
        let expectedCharSet = NSCharacterSet.URLQueryAllowedCharacterSet()
        let paramLatLon = stringLatLon.stringByAddingPercentEncodingWithAllowedCharacters(expectedCharSet)!
        
        // Create the REST API URL.
        if let url = NSURL(string: "http://localhost:8080/mapcode/codes/\(paramLatLon))/international?debug=true") {
            if let data = try? NSData(contentsOfURL: url, options: []) {
                let json = JSON(data: data)
                
                if json["mapcode"] != nil {
                    theMapcode.text = json["mapcode"].stringValue
                }
                else {
                    theMapcode.text = "ERROR"
                }
            }
        }
    }
    
    func mapView(mapView: MKMapView,
                 rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        let polylineRenderer = MKPolylineRenderer(overlay: overlay)
        polylineRenderer.strokeColor = UIColor.blueColor()
        polylineRenderer.lineWidth = 4
        return polylineRenderer
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
