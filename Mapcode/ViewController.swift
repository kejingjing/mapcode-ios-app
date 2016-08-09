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
    @IBOutlet weak var theCopyMapcodeInternational: UIButton!
    @IBOutlet weak var theCopyMapcodeLocal: UIButton!
    @IBOutlet weak var theCopyLatitude: UIButton!
    @IBOutlet weak var theCopyLongitude: UIButton!

    let host: String = "http:/api.mapcode.com";     // Host name of REST API.
    let allowLog: String = "true";                  // Log requests.
    let client: String = "ios";                     // Client ID.

    let spanStartUpX = 60.0     // Initial zoom.
    let spanStartUpY = 30.0

    let spanInitX = 1.0         // Initial zoom.
    let spanInitY = 1.0

    let spanZoomedInX = 0.003   // Zoomed in.
    let spanZoomedInY = 0.003

    let spanZoomedOutX = 0.4    // Zoomed out.
    let spanZoomedOutY = 0.4

    // provide a sensible screen if no user location is available (rather than mid Pacific).
    let initialLocation = CLLocationCoordinate2D(latitude: 52.373293, longitude: 4.893718)

    var manager: CLLocationManager!
    var firstTimeLocation = true                    //
    var prevTerritory: String!                      // Previous territory, serves as default.
    var prevTextField: String!                      // Undo edits if something went wrong.
    var tapCoordinate: CLLocationCoordinate2D!;     // Coordinate of first tap (in multi-tap).

    /**
     * This method gets called when the view loads.
     */
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup our Map View.
        theMap.delegate = self
        theMap.mapType = MKMapType.Standard
        theMap.showsUserLocation = true
        theMap.showsScale = true
        theMap.showsBuildings = true

        // Set initial map and zoom.
        let newRegion = MKCoordinateRegion(center:  initialLocation,
                                           span: MKCoordinateSpanMake(spanInitX, spanInitY))
        theMap.setRegion(newRegion, animated: false)

        // Setup up delegates for text input boxes.
        theAddress.delegate = self
        theLat.delegate = self
        theLon.delegate = self
        theMapcodeInternational.delegate = self
        theMapcodeLocal.delegate = self

        // Recognize tap on map.
        let tap1 = UITapGestureRecognizer(target: self, action: #selector(ViewController.handleMapTap1(_:)))
        tap1.numberOfTapsRequired = 1
        let tap2 = UITapGestureRecognizer(target: self, action: #selector(ViewController.handleMapTap2(_:)))
        tap2.numberOfTapsRequired = 2
        let tap3 = UITapGestureRecognizer(target: self, action: #selector(ViewController.handleMapTap3(_:)))
        tap3.numberOfTapsRequired = 3

        theMap.addGestureRecognizer(tap1)
        theMap.addGestureRecognizer(tap2)
        theMap.addGestureRecognizer(tap3)

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
    func handleMapTap1(gestureRecognizer: UITapGestureRecognizer) {

        // Don't auto-zoom to user location anymore.
        firstTimeLocation = false

        // Get location of tap.
        let location = gestureRecognizer.locationInView(theMap)
        let coordinate = theMap.convertPoint(location, toCoordinateFromView: theMap)
        tapCoordinate = coordinate

        // Set map center.
        theMap.setCenterCoordinate(coordinate, animated: true)

        // Update other fields.
        updateFieldsMapcodes(coordinate.latitude, lon: coordinate.longitude)
        updateFieldsLatLonAddress(coordinate.latitude, lon: coordinate.longitude)
    }

    /**
     * This method gets called when the user double taps the map.
     */
    func handleMapTap2(gestureRecognizer: UITapGestureRecognizer) {

        // Auto zoom-in on lat tap. No need to update fields - single tap has already been handled.
        let newRegion = MKCoordinateRegion(center: tapCoordinate != nil ? tapCoordinate : theMap.centerCoordinate,
                                           span: MKCoordinateSpanMake(spanZoomedInX, spanZoomedInY))
        theMap.setRegion(newRegion, animated: true)
    }
    
    /**
     * This method gets called when the user triple taps the map.
     */
    func handleMapTap3(gestureRecognizer: UITapGestureRecognizer) {

        // Auto zoom-in on lat tap. No need to update fields - single tap has already been handled.
        let newRegion = MKCoordinateRegion(center: tapCoordinate != nil ? tapCoordinate : theMap.centerCoordinate,
                                           span: MKCoordinateSpanMake(spanZoomedOutX, spanZoomedOutY))
        theMap.setRegion(newRegion, animated: true)
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
            self.prevTextField = textField.text
        }
    }

    /**
     * This method gets called when the Return key is pressed in a text edit field.
     */
    func textFieldShouldReturn(textField: UITextField) -> Bool {

        // Hide keyboard.
        textField.resignFirstResponder()

        // Do not process empty fields.
        if (textField.text == nil) || (textField.text?.isEmpty)! {

            // Restore contents of field.
            textField.text = prevTextField
            return true
        }

        // Don't auto-zoom to user location anymore.
        firstTimeLocation = false

        switch textField.tag {

        case theAddress.tag:
            useAddress(theAddress.text!)

        case theLat.tag:
            useLatLon(theLat.text!, longitude: theLon.text!)

        case theLon.tag:
            useLatLon(theLat.text!, longitude: theLon.text!)

        case theMapcodeInternational.tag:
            useMapcode(theMapcodeInternational.text!)

        case theMapcodeLocal.tag:
            useMapcode(theMapcodeLocal.text!)

        default:
            print("Unknown text field: \(textField.tag)")
        }
        return true
    }

    /**
     * Address box was edited.
     */
    func useAddress(address: String) {

        // Geocode address.
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address, completionHandler: {
            (placemarks, error) -> Void in
            if error != nil {
                print("Geocode failed, address=\(address), error=\(error)")
                self.showAlert("Incorrect address", message: "Can't find a location for\n'\(address)'", button: "OK")

                // Reset address field.
                dispatch_async(dispatch_get_main_queue()) {
                    let lat = self.truncToMicroDegrees(self.theMap.centerCoordinate.latitude)
                    let lon = self.truncToMicroDegrees(self.theMap.centerCoordinate.longitude)
                    self.updateFieldsLatLonAddress(lat, lon: lon)
                }
            }
            else {

                // Get location.
                if let placemark = placemarks?.first {
                    let coordinates: CLLocationCoordinate2D = placemark.location!.coordinate
                    let lat = self.truncToMicroDegrees(coordinates.latitude)
                    let lon = self.truncToMicroDegrees(coordinates.longitude)

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
    func useLatLon(latitude: String, longitude: String) {
        var lat = Double(latitude)
        var lon = Double(longitude)
        if (lat == nil) || (lon == nil) {
            return
        }

        // Limit range.
        lat = max(-90.0, min(90.0, truncToMicroDegrees(lat!)))
        lon = max(-180.0, min(180.0, truncToMicroDegrees(lon!)))

        theMap.setCenterCoordinate(CLLocationCoordinate2D(latitude: lat!, longitude: lon!), animated: false)
        updateFieldsMapcodes(lat!, lon: lon!)
        updateFieldsLatLonAddress(lat!, lon: lon!)
    }

    /**
     * Call Mapcode REST API to get coordinate from mapcode.
     */
    func useMapcode(mapcode: String) {

        // Prefix previous territory for local mapcodes.
        var fullMapcode = mapcode;
        if (prevTerritory != nil) && (mapcode.characters.count < 10) && !mapcode.containsString(" "){
            fullMapcode = "\(prevTerritory) \(mapcode)"
        }

        // Create URL for REST API call to get mapcodes.
        let encodedMapcode = fullMapcode.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
        let url = "\(host)/mapcode/coords/\(encodedMapcode)?client=\(client)&allowLog=\(allowLog)"
        guard let rest = RestController.createFromURLString(url) else {
            print("Found bad URL: \(url)")
            return
        }

        // Get coordinate.
        rest.get {
            result, httpResponse in
            do {
                let json = try result.value()

                let status = httpResponse?.statusCode
                if (status != 200) || (json["errors"] != nil) {
                    self.showAlert("Incorrect mapcode", message: "Mapcode '\(mapcode)' does not exist", button: "OK")
                }

                // Check status OK
                if (status == 200) &&
                    (json["errors"] == nil) &&
                    (json["latDeg"] != nil) && (json["latDeg"]?.doubleValue != nil) &&
                    (json["lonDeg"] != nil) && (json["lonDeg"]?.doubleValue != nil) {
                    let lat = self.truncToMicroDegrees((json["latDeg"]?.doubleValue)!)
                    let lon = self.truncToMicroDegrees((json["lonDeg"]?.doubleValue)!)

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
                        let lat = self.truncToMicroDegrees(self.theMap.centerCoordinate.latitude)
                        let lon = self.truncToMicroDegrees(self.theMap.centerCoordinate.longitude)
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
        let lat = truncToMicroDegrees(mapView.centerCoordinate.latitude)
        let lon = truncToMicroDegrees(mapView.centerCoordinate.longitude)

        updateFieldsLatLonAddress(lat, lon: lon);
        updateFieldsMapcodes(lat, lon: lon)
    }

    /**
     * This method gets called when the "info" icon is pressed.
     */
    @IBAction func showInfo(sender: AnyObject) {
        let nsObject: AnyObject? = NSBundle.mainBundle().infoDictionary!["CFBundleShortVersionString"]
        let version = nsObject as! String
        self.showAlert("About Mapcode \(version)", message:
            "Copyright (C) 2016\n" +
            "Rijn Buve, Mapcode Foundation\n\n" +

            "Get a mapcode by entering an address or coordinate, or moving the map around. You can tap " +
            "once to move directly to a location, twice to zoom in and three times to zoom out.\n\n" +

            "Show a mapcode on the map by entering it in one of the mapcode input boxes. If you omit " +
            "the territory for a local mapcode, the current territory is automatically assumed.\n\n" +

            "Plan a route to a mapcode by enter it and then tapping on the 'map' icon at the bottom right of the map.\n\n" +

            "For more info on mapcodes in general, visit us at: http://mapcode.com\n\n________\n" +

            "Note that some usage data may be collected to improve the Mapcode REST API service " +
            "(not used for commercial purposes).", button: "OK")
    }

    /**
     * This method gets called when the "find here" icon is pressed.
     */
    @IBAction func findHere(sender: AnyObject) {

        // Change zoom level.
        let userLocation = theMap.userLocation.coordinate
        let newRegion = MKCoordinateRegion(center: userLocation,
                                           span: MKCoordinateSpanMake(spanZoomedInX, spanZoomedInY))
        theMap.setRegion(newRegion, animated: true)
        manager.startUpdatingLocation()
    }

    /**
     * This method gets called when a "copy to clipboard" icon is pressed.
     */
    @IBAction func copyToClipboard(sender: AnyObject) {
        var copytext: String!
        switch sender.tag {

        case 1:
            copytext = theMapcodeInternational.text

        case 2:
            copytext = theMapcodeLocal.text

        case 3:
            copytext = theLat.text

        case 4:
            copytext = theLon.text

        default:
            copytext = nil

        }
        if copytext != nil {
            UIPasteboard.generalPasteboard().string = copytext
        }
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

                // Print an message to console, but don't show a user dialog (not an error).
                print("No reverse geocode info for \(lat,lon), error=\(error!.localizedDescription)")
                return
            }

            // Construct address
            if placemarks!.count > 0 {
                let pm = placemarks![0] as CLPlacemark
                var address: String = "";
                if pm.thoroughfare != nil {
                    address = pm.thoroughfare!
                    if pm.subThoroughfare != nil {
                        if (self.useStreetThenNumber()) {
                            address = "\(address) \(pm.subThoroughfare!)";
                        }
                        else {
                            address = "\(pm.subThoroughfare!) \(address)";
                        }
                    }
                }
                if pm.locality != nil {
                    if (!address.isEmpty) {
                        address = "\(address), ";
                    }
                    address = "\(address)\(pm.locality!)";
                }
                if pm.ISOcountryCode != nil {
                    if (!address.isEmpty) {
                        address = "\(address), ";
                    }
                    address = "\(address)\(pm.ISOcountryCode!)";
                }

                // Update address fields.
                dispatch_async(dispatch_get_main_queue()) {
                    self.theAddress.text = address;
                }
            } else {
                print("No placemarks for \(lat,lon)")
            }
        })
    }

    /**
     * Call Mapcode REST API to get mapcode codes from latitude, longitude.
     */
    func updateFieldsMapcodes(lat: CLLocationDegrees, lon: CLLocationDegrees) {

        // Create URL for REST API call to get mapcodes, URL-encode lat/lon.
        let encodedLatLon = "\(lat),\(lon)".stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!

        // Add context parameter if a previous territory was found. This should
        // bias resolving mapcode towards the previous territory context.
        var paramTerritory: String;
        if prevTerritory == nil {
            paramTerritory = ""
        }
        else {
            paramTerritory = "&territory=\(prevTerritory)"
        }

        let url = "\(host)/mapcode/codes/\(encodedLatLon)?client=\(client)&allowLog=\(allowLog)\(paramTerritory)"

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
                var territory: String! = nil
                var mcInternational = ""
                var mcLocal = ""
                let json = try result.value()

                // The JSON response indicated an error, territory is set to nil.
                if json["errors"] != nil {
                    print("Can get mapcode for: \(lat,lon)")
                }

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
                        territory = json["local"]?["territory"]?.stringValue
                    }
                }

                // Update mapcode fields on main thread.
                dispatch_async(dispatch_get_main_queue()) {
                    self.theMapcodeInternational.text = mcInternational
                    self.theMapcodeLocal.text = mcLocal
                    self.prevTerritory = territory
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
     * This method gets called whenever a location change is detected.
     */
    func locationManager(manager: CLLocationManager,
                         didUpdateLocations locations:[CLLocation]) {

        // First time? Set map zoom.
        if firstTimeLocation {

            // When the first user location is received, we'll move to that. Filter out garbage from (0, 0).
            if ((Int(theMap.userLocation.coordinate.latitude) != 0) ||
                (Int(theMap.userLocation.coordinate.longitude) != 0)) {
                firstTimeLocation = false

                // Change zoom level.
                let userLocation = theMap.userLocation.coordinate
                let newRegion = MKCoordinateRegion(center: userLocation,
                                                   span: MKCoordinateSpanMake(spanInitX, spanInitY))

                // Move without animation.
                theMap.setRegion(newRegion, animated: true)
            }
        }
        else {

            // Stop receiving updates after we get a first (decent) user location.
            manager.stopUpdatingLocation()
        }
    }

    /**
     * This method gets called when the location cannot be fetched.
     */
    func locationManager(manager: CLLocationManager,
                         didFailWithError error: NSError) {

        // Code 0 is returned when during debugging anyhow.
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
     * This method gets called when the "open in maps" icon is pressed.
     */
    @IBAction func openInMapApplication(sender: AnyObject) {
        let lat = truncToMicroDegrees(theMap.centerCoordinate.latitude)
        let lon = truncToMicroDegrees(theMap.centerCoordinate.longitude)
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
        let span = theMap.region.span
        let center = theMap.region.center
        let coordinates = CLLocationCoordinate2DMake(lat, lon)
        let options = [
            MKLaunchOptionsMapCenterKey: NSValue(MKCoordinate: center),
            MKLaunchOptionsMapSpanKey: NSValue(MKCoordinateSpan: span)
        ]
        let placemark = MKPlacemark(coordinate: coordinates, addressDictionary: nil)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMapsWithLaunchOptions(options)
    }

    /**
     * Method to show an alert.
     */
    func showAlert(title: String, message: String, button: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: button, style: UIAlertActionStyle.Default, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }

    /**
     * Round degrees to microdegree precision.
     */
    func truncToMicroDegrees(deg: Double) -> Double {
        return round(deg * 1.0e6) / 1.0e6;
    }

    /**
     * Returns true of the house number is to be put after the street name. False otherwise.
     * The selection is based on a selected number of country codes (incomplete).
     */
    func useStreetThenNumber() -> Bool {
        let locale = NSLocale.currentLocale()
        if let country = locale.objectForKey(NSLocaleCountryCode) as? String {
            if country == "AU" || country == "NZ" || country == "UK" || country == "US" || country == "VN" {
                return false
            }
        }
        return true
    }

    /**
     * This method gets called when on low memory.
     */
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("Low memory warning")
    }
}
