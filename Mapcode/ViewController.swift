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

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, UITextFieldDelegate,
    UIGestureRecognizerDelegate {

    @IBOutlet weak var theMap: MKMapView!
    @IBOutlet weak var theMapcodeInternational: UITextField!
    @IBOutlet weak var theMapcodeLocal: UITextField!
    @IBOutlet weak var theLat: UITextField!
    @IBOutlet weak var theLon: UITextField!
    @IBOutlet weak var theFollow: UISwitch!
    @IBOutlet weak var theAddress: UITextField!
    @IBOutlet weak var theHere: UIButton!

    let host: String = "http:/localhost:8080";
    let debug: String = "true";

    var manager: CLLocationManager!
    var stopUpdatingLocation: Bool = false

    /**
     * This method gets called when the view loads.
     */
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup our Map View.
        theMap.delegate = self
        theMap.mapType = MKMapType.Standard
        theMap.showsUserLocation = true

        // Setup up delegates for text input boxes.
        theAddress.delegate = self
        theLat.delegate = self
        theLon.delegate = self
        theMapcodeInternational.delegate = self
        theMapcodeLocal.delegate = self

        theMap.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(ViewController.handleMapGesture(_:))))
        theMap.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(ViewController.handleMapGesture(_:))))
        theMap.addGestureRecognizer(UIRotationGestureRecognizer(target: self, action: #selector(ViewController.handleMapGesture(_:))))

        theMap.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(ViewController.handleMapTap(_:))))

        // Setup our Location Manager.
        manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    /**
     * This method gets called when the user pans the map.
     */
    func handleMapGesture(gestureRecognizer: UIPanGestureRecognizer) {
        stopUpdatingLocation = true
    }

    /**
     * This method gets called when the user taps the map.
     */
    func handleMapTap(gestureRecognizer: UITapGestureRecognizer) {
        stopUpdatingLocation = true
        let location = gestureRecognizer.locationInView(theMap)
        let coordinate = theMap.convertPoint(location,toCoordinateFromView: theMap)
        theMap.setCenterCoordinate(coordinate, animated: true)
        updateFieldsMapcodes(coordinate.latitude, lon: coordinate.longitude)
        updateFieldsLatLonAddress(coordinate.latitude, lon: coordinate.longitude)
    }

    /**
     * This method gets called when the "find here" icon is pressed.
     */
    @IBAction func findHere(sender: AnyObject) {
        print("find here")
        stopUpdatingLocation = true
        manager.startUpdatingLocation()
    }

    /**
     * This method gets called when user starts editing the address.
     */
    @IBAction func beginEdit(sender: UITextField) {
        theFollow.setOn(false, animated: true)
        manager.stopUpdatingLocation()
        sender.text = ""
    }

    /**
     * This method gets called when user ends editing the address.
     */
    @IBAction func endEdit(sender: UITextField) {
        // TODO
    }

    /**
     * This method gets called when the "follow" switch is toggled.
     */
    @IBAction func followChanged(sender: AnyObject) {
        if theFollow.on {
            stopUpdatingLocation = false
            manager.startUpdatingLocation()
            theAddress.text = "";
        }
        else {
            stopUpdatingLocation = true
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
            useAddress(theAddress.text)
        case theLat.tag:
            useLatLon(theLat.text, longitude: theLon.text)
        case theLon.tag:
            useLatLon(theLat.text, longitude: theLon.text)
        case theMapcodeInternational.tag:
            useMapcode(theMapcodeInternational.text)
        case theMapcodeLocal.tag:
            useMapcode(theMapcodeLocal.text)
        default:
            print("Unknown text field: \(textField.tag)")
        }
        return true
    }

    func useAddress(address: String?) {
        if address == nil {
            return
        }
        // TODO: search
    }

    func useLatLon(latitude: String?, longitude: String?) {
        if (latitude == nil) || (longitude == nil) {
            return
        }
        let lat = Double(latitude!)
        let lon = Double(longitude!)
        if (lat == nil) || (lon == nil) {
            return
        }
        theMap.setCenterCoordinate(CLLocationCoordinate2D(latitude: lat!, longitude: lon!), animated: false)
        self.updateFieldsMapcodes(lat!, lon: lon!)
        self.updateFieldsLatLonAddress(lat!, lon: lon!)
    }

    func useMapcode(mapcode: String?) {
        if mapcode == nil {
            return
        }

        // Create URL for REST API call to get mapcodes.
        let encodedMapcode = mapcode!.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
        let url = "\(host)/mapcode/coords/\(encodedMapcode)?debug=\(debug)"
        print("URL: \(url)")
        guard let rest = RestController.createFromURLString(url) else {
            print("Found bad URL: \(url)")
            return
        }

        // Get coordinate.
        rest.get {
            result, httpResponse in
            do {
                let json = try result.value()
                if (json["latDeg"] == nil) || (json["latDeg"]?.doubleValue == nil) {
                    return
                }
                if (json["lonDeg"] == nil) || (json["lonDeg"]?.doubleValue == nil) {
                    return
                }
                let lat = (json["latDeg"]?.doubleValue)!
                let lon = (json["lonDeg"]?.doubleValue)!
                dispatch_async(dispatch_get_main_queue()) {
                    self.theMap.setCenterCoordinate(CLLocationCoordinate2D(latitude: lat, longitude: lon), animated: false)
                    self.updateFieldsMapcodes(lat, lon: lon)
                    self.updateFieldsLatLonAddress(lat, lon: lon)
                }
            } catch {
                print("API /mapcode/coords called failed: \(error)")
            }
        }
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
            theAddress.text = "";
            theFollow.setOn(true, animated: false)
            theFollow.enabled = true
        }
        else {
            manager.stopUpdatingLocation()
            theAddress.text = "(Not allowed to fetch current location.)";
            theFollow.enabled = false
            theFollow.setOn(false, animated: false)
        }
    }

    /**
     * This method gets called whenever a location change is detected.
     */
    func mapView(mapView: MKMapView,
                 regionDidChangeAnimated animated: Bool) {

        // Stop updating if requested.
        if stopUpdatingLocation {
            manager.stopUpdatingLocation()
            theFollow.setOn(false, animated: true)
        }

        // Get latitude and longitude.
        let lat = mapView.centerCoordinate.latitude
        let lon = mapView.centerCoordinate.longitude

        theLat.text = "\(lat)"
        theLon.text = "\(lon)"

        // Dim mapcodes fields; these are outdated now.
        theMapcodeInternational.textColor = UIColor.grayColor();
        theMapcodeLocal.textColor = UIColor.grayColor();

        updateFieldsLatLonAddress(lat, lon: lon);
        updateFieldsMapcodes(lat, lon: lon)
    }

    /**
     * This method gets called whenever a location change is detected.
     */
    func locationManager(manager: CLLocationManager,
                         didUpdateLocations locations:[CLLocation]) {
        print("didUpdateLocation")

        // Show map.
        let spanX = 0.01
        let spanY = 0.01
        let newRegion = MKCoordinateRegion(center: theMap.userLocation.coordinate,
                                           span: MKCoordinateSpanMake(spanX, spanY))
         theMap.setRegion(newRegion, animated: true)
    }
    
    /**
     * This method updates the coordinates and address fields.
     */
    func updateFieldsLatLonAddress(lat: CLLocationDegrees, lon: CLLocationDegrees) {

        // Update latitude and longitude.
        theLat.text = "\(lat)"
        theLon.text = "\(lon)"

        // Get address from reverse geocode.
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: lat, longitude: lon),
                                            completionHandler: {
            (placemarks, error) -> Void in
            if error != nil {
                print("Reverse geocode failed: " + error!.localizedDescription)
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
                dispatch_async(dispatch_get_main_queue()) {
                    self.theAddress.text = address;
                }
            } else {
                print("No result from reverse geocode")
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
        let encodedLatLon = "\(lat),\(lon)".stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
        let url = "\(host)/mapcode/codes/\(encodedLatLon)?debug=\(debug)"
        print("URL: \(url)")
        guard let rest = RestController.createFromURLString(url) else {
            print("Found bad URL: \(url)")
            theMapcodeLocal.text = ""
            theMapcodeInternational.text = ""
            return
        }

        // Get mapcodes.
        rest.get {
            result, httpResponse in
            do {
                var mcInternational = ""
                var mcLocal = ""
                let json = try result.value()
                if json["international"] != nil {
                    if json["international"]?["mapcode"] != nil {
                        mcInternational = (json["international"]?["mapcode"]?.stringValue)!
                    }
                }
                if json["local"] != nil {
                    if json["local"]?["territory"] != nil {
                        mcLocal = "\((json["local"]?["territory"]?.stringValue)!) \((json["local"]?["mapcode"]?.stringValue)!)"
                    }
                }

                // Update mapcode fields.
                dispatch_async(dispatch_get_main_queue()) {
                    self.theMapcodeInternational.text = mcInternational
                    self.theMapcodeLocal.text = mcLocal
                }
            } catch {
                dispatch_async(dispatch_get_main_queue()) {
                    self.theAddress.text = ""
                    self.theMapcodeInternational.text = ""
                    self.theMapcodeLocal.text = ""
                }
                print("API call /mapcode/codes called failed: \(error)")
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
