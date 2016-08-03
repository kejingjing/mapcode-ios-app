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

        updateMapcode(lat, lon: lon);
    }

    func updateMapcode(lat: CLLocationDegrees, lon: CLLocationDegrees) {

        CLGeocoder().reverseGeocodeLocation(manager.location!, completionHandler: {
            (placemarks, error) -> Void in
            if (error != nil) {
                print("Reverse geocoder failed with error" + error!.localizedDescription)
                return
            }

            if placemarks!.count > 0 {
                let pm = placemarks![0] as CLPlacemark
                let address : String = "\(pm.thoroughfare) \(pm.subThoroughfare)\n\(pm.locality)\n\(pm.country)"
                print("Addess=\(address)")
                dispatch_async(dispatch_get_main_queue()) {
                    self.theError.text = address;
                }
            } else {
                print("Problem with the data received from geocoder")
            }
        })
        return

        // Construct latitude, longitude string from coordinates.
        let url = "http://localhost:8080/mapcode/codes/\(lat),\(lon)?debug=true"
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
                let mcInternational : String = (json["international"]?["mapcode"]?.stringValue)!
                let mcLocalTerritory : String = (json["mapcodes"]?[0]?["territory"]?.stringValue)!
                let mcLocalMapcode : String = (json["mapcodes"]?[0]?["mapcode"]?.stringValue)!
                let mcLocal = "\(mcLocalTerritory) \(mcLocalMapcode)"

                print("--> Got mapcodes: '\(mcInternational)', '\(mcLocal)'")
                dispatch_async(dispatch_get_main_queue()) {
                    self.theMapcodeInternational.text = mcInternational
                    self.theMapcodeLocal.text = mcLocal
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
