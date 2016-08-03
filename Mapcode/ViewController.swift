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
    @IBOutlet weak var theMapcodeInternational: UITextField!
    @IBOutlet weak var theMapcodeLocal: UITextField!
    @IBOutlet weak var theLat: UITextField!
    @IBOutlet weak var theLon: UITextField!

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
        theLat.text = "\(lat)"
        theLon.text = "\(lon)"

        // Construct latitude, longitude string from coordinates.
        let stringLatLon = "\(lat),\(lon)"
        
        // Make sure we encode the URL correctly.
        let expectedCharSet = NSCharacterSet.URLQueryAllowedCharacterSet()
        let paramLatLon = stringLatLon.stringByAddingPercentEncodingWithAllowedCharacters(expectedCharSet)!
        let url = "http://localhost:8080/mapcode/codes/\(paramLatLon)?debug=true"

        print("--> Call url=\(url)")
        guard let rest = RestController.createFromURLString(url) else {
            print("--> Found bad URL: \(url)")
            return
        }

        rest.get {
            result, httpResponse in
            print("--> Callback, status=\(httpResponse?.statusCode)")
            do {
                let json = try result.value()
                let mapcodeInternational : String = (json["international"]?["mapcode"]?.stringValue)!
                let mapcodeLocalTerritory : String = (json["mapcodes"]?[0]?["territory"]?.stringValue)!
                let mapcodeLocalMapcode : String = (json["mapcodes"]?[0]?["mapcode"]?.stringValue)!
                let mapcodeLocal = "\(mapcodeLocalTerritory) \(mapcodeLocalMapcode)"

                print("--> Got mapcodes: '\(mapcodeInternational)', '\(mapcodeLocal)'")
                dispatch_async(dispatch_get_main_queue()) {
                    self.theMapcodeInternational.text = mapcodeInternational
                    self.theMapcodeLocal.text = mapcodeLocal
                }
            } catch {
                self.theError.text = "ERROR: \(error)"
                print("API called failed: \(error)")
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
