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

import CoreLocation
import MapKit
import UIKit

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, UITextFieldDelegate {

    @IBOutlet weak var theMap: MKMapView!
    @IBOutlet weak var theMapcodeInternational: UITextField!
    @IBOutlet weak var theMapcodeLocal: UITextField!
    @IBOutlet weak var theLat: UITextField!
    @IBOutlet weak var theLon: UITextField!
    @IBOutlet weak var theGenerate: UIButton!
    @IBOutlet weak var theFollow: UISwitch!
    @IBOutlet weak var theAddress: UITextField!

    let host: String = "http://api.mapcode.com";
    var manager: CLLocationManager!

    /**
     * This method gets called when the view loads.
     */
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

        theAddress.tag = 1
        theAddress.delegate = self
        theLat.tag = 2
        theLat.delegate = self
        theLon.delegate = self
        theLon.tag = 3
        theMapcodeInternational.delegate = self
        theMapcodeInternational.tag = 4
        theMapcodeLocal.delegate = self
        theMapcodeLocal.tag = 5
    }

    /**
     * This method gets called when user starts editing the address.
     */
    @IBAction func beginEditAddress(sender: AnyObject) {
        theFollow.setOn(false, animated: true)
        manager.stopUpdatingLocation()
        theAddress.text = ""
    }

    /**
     * This method gets called when user ends editing the address.
     */
    @IBAction func endEditAddress(sender: AnyObject) {
        print("Edited address: \(theAddress.text)");
    }

    /**
     * This method gets called when the "follow" switch is toggled.
     */
    @IBAction func followChanged(sender: AnyObject) {
        if theFollow.on {
            manager.startUpdatingLocation()
            theAddress.text = "";
        }
        else {
            manager.stopUpdatingLocation()
            theAddress.text = "";
        }
    }

    /**
     * This method gets called when the Return key is pressed in a text edit field.
     */
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        print("Return-key for: \(textField.tag)")
        textField.resignFirstResponder()
        switch textField.tag {
        case theAddress.tag:
            print("Got address: \(textField.text)")
        case theLat.tag:
            print("Got latitude: \(textField.text)")
        case theLon.tag:
            print("Got longitude: \(textField.text)")
        case theMapcodeInternational.tag:
            print("Got international mapcode: \(textField.text)")
        case theMapcodeLocal.tag:
            print("Got local mapcode: \(textField.text)")
        default:
            print("Unknown text field: \(textField.tag)")
        }
        return true
    }

    /**
     * This method gets called when the location cannot be fetched.
     */
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        manager.stopUpdatingLocation()
        print("Location manager failed: \(error.localizedDescription)")
    }

    /**
     * This method gets called when the location authorization changes.
     */
    func locationManager(manager: CLLocationManager,
                         didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        var allow = false

        switch status {
        case CLAuthorizationStatus.AuthorizedWhenInUse:
            allow = true
        case CLAuthorizationStatus.AuthorizedAlways:
            allow = true
        default:
            allow = false
        }
        if allow {
            manager.startUpdatingLocation()
            dispatch_async(dispatch_get_main_queue()) {
                self.theAddress.text = "";
                self.theFollow.setOn(true, animated: false)
                self.theFollow.enabled = true
            }
        }
        else {
            manager.stopUpdatingLocation()
            dispatch_async(dispatch_get_main_queue()) {
                self.theAddress.text = "(Not allowed to fetch current location.)";
                self.theFollow.enabled = false
                self.theFollow.setOn(false, animated: false)
            }
        }
    }

    /**
     * This method gets called whenever a location change is detected.
     */
    func locationManager(manager: CLLocationManager,
                         didUpdateLocations locations:[CLLocation]) {

        // Get latitude and longitude.
        let lat = locations[0].coordinate.latitude
        let lon = locations[0].coordinate.longitude
        
        // Show map.
        let spanX = 0.02
        let spanY = 0.02
        let newRegion = MKCoordinateRegion(center: theMap.userLocation.coordinate,
                                           span: MKCoordinateSpanMake(spanX, spanY))
        theMap.setRegion(newRegion, animated: true)

        // Dim mapcodes fields; these are outdated now.
        theMapcodeInternational.textColor = UIColor.grayColor();
        theMapcodeLocal.textColor = UIColor.grayColor();

        // Update button text.
        theGenerate.setTitle("Get mapcode from position", forState: UIControlState.Normal)

        updateFieldsLatLonAddress(lat, lon: lon);
        updateFieldsMapcodes(lat, lon: lon)
    }

    /**
     * This method updates the coordinates and address fields.
     */
    func updateFieldsLatLonAddress(lat: CLLocationDegrees, lon: CLLocationDegrees) {

        // Update latitude and longitude.
        theLat.text = "\(lat)"
        theLon.text = "\(lon)"

        // Get address from reverse geocode.
        CLGeocoder().reverseGeocodeLocation(manager.location!, completionHandler: {
            (placemarks, error) -> Void in
            if error != nil {
                print("Reverse geocode failed: " + error!.localizedDescription)
                dispatch_async(dispatch_get_main_queue()) {
                    self.theAddress.text = "\(error!.localizedDescription)"
                }
                return
            }

            if placemarks!.count > 0 {
                let pm = placemarks![0] as CLPlacemark
                var address: String = "";
                if pm.thoroughfare != nil {
                    address = pm.thoroughfare!
                }
                if pm.subThoroughfare != nil {
                    address = "\(address) \(pm.subThoroughfare!)";
                }
                if pm.locality != nil {
                    address = "\(address), \(pm.locality!)";
                }
                if pm.ISOcountryCode != nil {
                    address = "\(address), \(pm.ISOcountryCode!)";
                }

                // Update address fields.
                print("Addess=\(address)")
                dispatch_async(dispatch_get_main_queue()) {
                    self.theAddress.text = address;
                }
            } else {
                print("No result from reverse geocode")
                dispatch_async(dispatch_get_main_queue()) {
                    self.theAddress.text = ""
                }
            }
        })
    }
    

    /**
     * This method updates the mapcodes fields.
     */
    func updateFieldsMapcodes(lat: CLLocationDegrees, lon: CLLocationDegrees) {

        // Reset mapcodes fields.
        theMapcodeInternational.textColor = UIColor.blackColor();
        theMapcodeLocal.textColor = UIColor.blackColor();

        // Create URL for REST API call to get mapcodes.
        let url = "\(host)/mapcode/codes/\(lat),\(lon)?debug=true"
        guard let rest = RestController.createFromURLString(url) else {
            print("Found bad URL: \(url)")
            theMapcodeLocal.text = ""
            theMapcodeInternational.text = ""
            return
        }

        // Get mapcodes.
        rest.get {
            result, httpResponse in
            print("Callback, status=\(httpResponse?.statusCode)")
            do {
                let json = try result.value()
                let mcInternational : String = (json["international"]?["mapcode"]?.stringValue)!
                let mcLocalTerritory : String = (json["mapcodes"]?[0]?["territory"]?.stringValue)!
                let mcLocalMapcode : String = (json["mapcodes"]?[0]?["mapcode"]?.stringValue)!
                let mcLocal = "\(mcLocalTerritory) \(mcLocalMapcode)"

                // Update mapcode fields.
                print("Got mapcodes: '\(mcInternational)', '\(mcLocal)'")
                dispatch_async(dispatch_get_main_queue()) {
                    self.theMapcodeInternational.text = mcInternational
                    self.theMapcodeLocal.text = mcLocal
                }
            } catch {
                dispatch_async(dispatch_get_main_queue()) {
                    self.theAddress.text = "\(error)"
                    self.theMapcodeInternational.text = ""
                    self.theMapcodeLocal.text = ""
                }
                print("API called failed: \(error)")
            }
        }
    }
    
    /**
     * This method gets called when on low memory.
     */
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("Low memory warning")
    }
}
