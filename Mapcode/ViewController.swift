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
    @IBOutlet weak var theAddress: UITextField!
    @IBOutlet weak var theHere: UIButton!

    let host: String = "http:/api.mapcode.com";
    let debug: String = "true";

    let spanX = 0.005
    let spanY = 0.005
    let initialLocation = CLLocationCoordinate2D(latitude: 52.3731476, longitude: 4.8925322)

    var manager: CLLocationManager!
    var firstTimeLocation = true

    /**
     * This method gets called when the view loads.
     */
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup our Map View.
        theMap.delegate = self
        theMap.mapType = MKMapType.Standard
        theMap.showsUserLocation = true

        // Set initial map and zoom.
        let newRegion = MKCoordinateRegion(center:  initialLocation,
                                           span: MKCoordinateSpanMake(spanX, spanY))
        theMap.setRegion(newRegion, animated: false)

        // Setup up delegates for text input boxes.
        theAddress.delegate = self
        theLat.delegate = self
        theLon.delegate = self
        theMapcodeInternational.delegate = self
        theMapcodeLocal.delegate = self

        // Recognize tap on map.
        theMap.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(ViewController.handleMapTap(_:))))

        // Setup our Location Manager.
        manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    /**
     * This method gets called when the user taps the map.
     */
    func handleMapTap(gestureRecognizer: UITapGestureRecognizer) {
        let location = gestureRecognizer.locationInView(theMap)
        let coordinate = theMap.convertPoint(location,toCoordinateFromView: theMap)
        theMap.setCenterCoordinate(coordinate, animated: true)
        updateFieldsMapcodes(coordinate.latitude, lon: coordinate.longitude)
        updateFieldsLatLonAddress(coordinate.latitude, lon: coordinate.longitude)
    }

    /**
     * This method moves the screen up or down when a field gets edited.
     */
    func animateTextField(textField: UITextField, up: Bool) {
        let movementDistance: CGFloat = -250
        let movementDuration: Double = 0.3

        var movement: CGFloat = 0
        if up {
            movement = movementDistance
        }
        else {
            movement = -movementDistance
        }
        UIView.beginAnimations("animateTextField", context: nil)
        UIView.setAnimationBeginsFromCurrentState(true)
        UIView.setAnimationDuration(movementDuration)
        self.view.frame = CGRectOffset(self.view.frame, 0, movement)
        UIView.commitAnimations()
    }

    /**
     * This method moves the screen up or down when a field gets edited.
     */
    func textFieldDidBeginEditing(textField: UITextField) {
        self.animateTextField(textField, up: true)
    }

    func textFieldDidEndEditing(textField: UITextField) {
        self.animateTextField(textField, up: false)
    }
    
    /**
     * This method gets called when user starts editing the address.
     */
    @IBAction func beginEdit(textField: UITextField) {
        dispatch_async(dispatch_get_main_queue()) {
            textField.becomeFirstResponder()
            textField.selectedTextRange = textField.textRangeFromPosition(textField.beginningOfDocument, toPosition: textField.endOfDocument)
        }
    }

    /**
     * This method gets called when user ends editing the address.
     */
    @IBAction func endEdit(sender: UITextField) {
        // No action.
    }

    /**
     * This method gets called when the Return key is pressed in a text edit field.
     */
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        switch textField.tag {

        case theAddress.tag:
            useAddress(textField)

        case theLat.tag:
            useLatLon(theLat.text, longitude: theLon.text)

        case theLon.tag:
            useLatLon(theLat.text, longitude: theLon.text)

        case theMapcodeInternational.tag:
            useMapcode(textField)

        case theMapcodeLocal.tag:
            useMapcode(textField)

        default:
            print("Unknown text field: \(textField.tag)")
        }
        return true
    }

    /**
     * Address box was edited.
     */
    func useAddress(textField: UITextField) {
        if textField.text == nil {
            return
        }
        let address = textField.text

        // Geocode address.
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address!, completionHandler: {
            (placemarks, error) -> Void in
            if error != nil {
                print("Geocode failed, address=\(address), error=\(error)")

                // Reset address field.
                dispatch_async(dispatch_get_main_queue()) {
                    textField.text = ""
                    let lat = self.theMap.centerCoordinate.latitude
                    let lon = self.theMap.centerCoordinate.longitude
                    self.updateFieldsLatLonAddress(lat, lon: lon)
                }
            }
            else {

                // Get location.
                if let placemark = placemarks?.first {
                    let coordinates: CLLocationCoordinate2D = placemark.location!.coordinate
                    let lat = coordinates.latitude
                    let lon = coordinates.longitude

                    dispatch_async(dispatch_get_main_queue()) {
                        self.theMap.setCenterCoordinate(CLLocationCoordinate2D(latitude: lat, longitude: lon), animated: false)
                        self.updateFieldsMapcodes(lat, lon: lon)
                        self.updateFieldsLatLonAddress(lat, lon: lon)
                    }
                }
            }
        })
    }

    /**
     * Lat or lon box was edited.
     */
    func useLatLon(latitude: String?, longitude: String?) {
        if (latitude == nil) || (longitude == nil) {
            return
        }
        var lat = Double(latitude!)
        var lon = Double(longitude!)
        if (lat == nil) || (lon == nil) {
            return
        }

        // Limit range.
        lat = max(-90.0, min(90.0, lat!))
        lon = max(-180.0, min(180.0, lon!))

        theMap.setCenterCoordinate(CLLocationCoordinate2D(latitude: lat!, longitude: lon!), animated: false)
        updateFieldsMapcodes(lat!, lon: lon!)
        updateFieldsLatLonAddress(lat!, lon: lon!)
    }

    /**
     * Call Mapcode REST API to get coordinate from mapcode.
     */
    func useMapcode(textField: UITextField) {
        if textField.text == nil {
            return
        }
        let mapcode = textField.text!

        // Create URL for REST API call to get mapcodes.
        let encodedMapcode = mapcode.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
        let url = "\(host)/mapcode/coords/\(encodedMapcode)?debug=\(debug)"
        guard let rest = RestController.createFromURLString(url) else {
            print("Found bad URL: \(url)")
            textField.text = ""
            return
        }

        // Get coordinate.
        rest.get {
            result, httpResponse in
            do {
                let json = try result.value()

                // Check status OK
                if (httpResponse?.statusCode == 200) &&
                    (json["errors"] == nil) &&
                    (json["latDeg"] != nil) && (json["latDeg"]?.doubleValue != nil) &&
                    (json["lonDeg"] != nil) && (json["lonDeg"]?.doubleValue != nil) {
                    let lat = (json["latDeg"]?.doubleValue)!
                    let lon = (json["lonDeg"]?.doubleValue)!

                    // Set map center.
                    dispatch_async(dispatch_get_main_queue()) {
                        self.theMap.setCenterCoordinate(CLLocationCoordinate2D(latitude: lat, longitude: lon), animated: false)
                        self.updateFieldsMapcodes(lat, lon: lon)
                        self.updateFieldsLatLonAddress(lat, lon: lon)
                    }
                }
                else {
                    print("Find mapcode failed: url=\(url), status=\(httpResponse?.statusCode), json=\(json)")
                    dispatch_async(dispatch_get_main_queue()) {
                        let lat = self.theMap.centerCoordinate.latitude
                        let lon = self.theMap.centerCoordinate.longitude
                        self.updateFieldsMapcodes(lat, lon: lon)
                    }
                }

            } catch {
                print("API call failed: url=\(url), error=\(error)")
            }
        }
    }

    /**
     * This method gets called whenever a location change is detected.
     */
    func mapView(mapView: MKMapView,
                 regionDidChangeAnimated animated: Bool) {

        // Get latitude and longitude.
        let lat = mapView.centerCoordinate.latitude
        let lon = mapView.centerCoordinate.longitude

        updateFieldsLatLonAddress(lat, lon: lon);
        updateFieldsMapcodes(lat, lon: lon)
    }

    /**
     * This method gets called when the "find here" icon is pressed.
     */
    @IBAction func findHere(sender: AnyObject) {

        // Change zoom level.
        let newRegion = MKCoordinateRegion(center: theMap.userLocation.coordinate,
                                           span: MKCoordinateSpanMake(spanX, spanY))
        theMap.setRegion(newRegion, animated: true)
        manager.startUpdatingLocation()
    }

    /**
     * This method gets called whenever a location change is detected.
     */
    func locationManager(manager: CLLocationManager,
                         didUpdateLocations locations:[CLLocation]) {

        // First time? Set map zoom.
        if firstTimeLocation {
            if ((Int(theMap.userLocation.coordinate.latitude) != 0) ||
                (Int(theMap.userLocation.coordinate.longitude) != 0)) {
                firstTimeLocation = false

                // Change zoom level.
                let newRegion = MKCoordinateRegion(center: theMap.userLocation.coordinate,
                                                   span: MKCoordinateSpanMake(spanX, spanY))
                theMap.setRegion(newRegion, animated: false)
            }
        }
        else {
            manager.stopUpdatingLocation()
        }
    }
    
    /**
     * This method gets called when the location cannot be fetched.
     */
    func locationManager(manager: CLLocationManager,
                         didFailWithError error: NSError) {
        manager.stopUpdatingLocation()
        print("Location manager failed: \(error.localizedDescription)")
    }

    /**
     * This method gets called when the location authorization changes.
     */
    func locationManager(manager: CLLocationManager,
                         didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        let allow: Bool!

        switch status {

        case CLAuthorizationStatus.AuthorizedWhenInUse:
            allow = true

        case CLAuthorizationStatus.AuthorizedAlways:
            allow = true

        default:
            allow = false
            manager.stopUpdatingLocation()
        }
        theHere.enabled = allow
        theHere.hidden = !allow
    }
    
    /**
     * Call Apple reverse geocoding API to get coordinates from address.
     */
    func updateFieldsLatLonAddress(lat: CLLocationDegrees, lon: CLLocationDegrees) {

        // Update latitude and longitude.
        theLat.text = "\(lat)"
        theLon.text = "\(lon)"
        theAddress.text = "Searching..."

        // Get address from reverse geocode.
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: lat, longitude: lon), completionHandler: {
            (placemarks, error) -> Void in
            if error != nil {
                print("Reverse geocode failed: lat/lon=\(lat,lon), error=\(error!.localizedDescription)")
                return
            }

            // Construct address
            if placemarks!.count > 0 {
                let pm = placemarks![0] as CLPlacemark
                var address: String = "";
                if pm.thoroughfare != nil {
                    address = pm.thoroughfare!
                    if pm.subThoroughfare != nil {
                        address = "\(address) \(pm.subThoroughfare!)";
                    }
                }
                if pm.locality != nil {
                    if (pm.thoroughfare != nil) {
                        address = "\(address), ";
                    }
                    address = "\(address)\(pm.locality!)";
                }
                if pm.ISOcountryCode != nil {
                    address = "\(address), \(pm.ISOcountryCode!)";
                }

                // Update address fields.
                dispatch_async(dispatch_get_main_queue()) {
                    self.theAddress.text = address;
                }
            } else {
                print("No results from reverse geocode: lat/lon=\(lat,lon)")
            }
        })
    }

    /**
     * Call Mapcode REST API to get mapcode codes from latitude, longitude.
     */
    func updateFieldsMapcodes(lat: CLLocationDegrees, lon: CLLocationDegrees) {

        // Create URL for REST API call to get mapcodes, URL-encode lat/lon.
        let encodedLatLon = "\(lat),\(lon)".stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
        let url = "\(host)/mapcode/codes/\(encodedLatLon)?debug=\(debug)"

        guard let rest = RestController.createFromURLString(url) else {
            print("Found bad URL: \(url)")
            theMapcodeLocal.text = ""
            theMapcodeInternational.text = ""
            return
        }

        // Get mapcodes from REST API.
        rest.get {
            result, httpResponse in
            do {
                var mcInternational = ""
                var mcLocal = ""
                let json = try result.value()

                // Get international mapcode.
                if json["international"] != nil {
                    if json["international"]?["mapcode"] != nil {
                        mcInternational = (json["international"]?["mapcode"]?.stringValue)!
                    }
                }

                // Get shortest local mapcode.
                if json["local"] != nil {
                    if (json["local"]?["territory"] != nil) && (json["local"]?["mapcode"] != nil) {
                        mcLocal = "\((json["local"]?["territory"]?.stringValue)!) \((json["local"]?["mapcode"]?.stringValue)!)"
                    }
                }

                // Update mapcode fields on main thread.
                dispatch_async(dispatch_get_main_queue()) {
                    self.theMapcodeInternational.text = mcInternational
                    self.theMapcodeLocal.text = mcLocal
                }
            } catch {
                print("API call failed: url=\(url), error=\(error)")

                // Something went wrong, discard mapcodes.
                dispatch_async(dispatch_get_main_queue()) {
                    self.theMapcodeInternational.text = ""
                    self.theMapcodeLocal.text = ""
                }
            }
        }
    }

    /**
     * This method gets called when the "open in maps" icon is pressed.
     */
    @IBAction func openInMapApplication(sender: AnyObject) {
        let lat = theMap.centerCoordinate.latitude
        let lon = theMap.centerCoordinate.longitude
        let name: String
        if (theMapcodeLocal.text != nil) && !(theMapcodeLocal.text?.isEmpty)! {
            name = theMapcodeLocal.text!
        }
        else {
            name = theMapcodeInternational.text!
        }
        openMapApplication(lat, lon: lon, name: name)
    }
    
    /**
     * This method open the Apple Maps application.
     */
    func openMapApplication(lat: CLLocationDegrees, lon: CLLocationDegrees, name: String) {
        let regionDistance: CLLocationDistance = 2000
        let coordinates = CLLocationCoordinate2DMake(lat, lon)
        let regionSpan = MKCoordinateRegionMakeWithDistance(coordinates, regionDistance, regionDistance)
        let options = [
            MKLaunchOptionsMapCenterKey: NSValue(MKCoordinate: regionSpan.center),
            MKLaunchOptionsMapSpanKey: NSValue(MKCoordinateSpan: regionSpan.span)
        ]
        let placemark = MKPlacemark(coordinate: coordinates, addressDictionary: nil)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMapsWithLaunchOptions(options)
    }

    /**
     * This method gets called when on low memory.
     */
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("Low memory warning")
    }
}
