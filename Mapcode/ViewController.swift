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
    @IBOutlet weak var theAlternative: UIButton!
    @IBOutlet weak var theMapType: UISegmentedControl!

    let debugMask = 1
    let DEBUG = 1
    let INFO = 2
    let ERROR = 4
    let WARNING = 8

    let host: String = "http:/api.mapcode.com";     // Host name of REST API.
    let allowLog: String = "true";                  // Log requests.
    let client: String = "ios";                     // Client ID.

    let spanStartUpX = 60.0                         // Initial zoom.
    let spanStartUpY = 30.0

    let spanInitX = 1.0                             // Initial zoom.
    let spanInitY = 1.0

    let spanZoomedInX = 0.003                       // Zoomed in.
    let spanZoomedInY = 0.003

    let spanZoomedOutX = 0.4                        // Zoomed out.
    let spanZoomedOutY = 0.4

    let limitReverseGeocodingSecs = 1.0             // No more than x reqs per second.
    let limitMapcodeLookupSecs = 1.0                // No more than x reqs per second.

    let scheduleUpdateLocationsSecs = 120.0         // Schedule update locations every x secs.
    let distanceFilterMeters = 1000.0               // Distance filter (updates are stopped anyhow).

    // Provide a sensible screen if no user location is available (rather than mid Pacific).
    var mapcodeLocation = CLLocationCoordinate2D(latitude: 52.373293, longitude: 4.893718)

    var locationManager: CLLocationManager!
    var firstLocationSinceStarted = true            // First time fix is different.
    var moveMapToUserLocation = false               // True if map should auto-move to user location.
    var prevTextField: String!                      // Undo edits if something went wrong.
    var prevTerritory: String!                      // Previous territory, serves as default.

    var currentAlternativeMapcode = 0               // Index of current alternative; 0 = shortest
    var alternativeMapcodes = [String]()            // List of alternative mapcodes.

    var mapChangedFromUserInteraction = false       // True if map was panned by user.

    // Latest coordinate to look up in reverse geocoding (nil if none).
    var queuedCoordinateForReverseGeocode: CLLocationCoordinate2D!
    var queuedCoordinateForMapcodeLookup: CLLocationCoordinate2D!

    var timerReverseGeocoding = NSTimer()           // Timer to limit reverse geocoding.
    var timerLocationUpdates = NSTimer()            // Timer to limit location updates.

    var colorWaitingForUpdate = UIColor.lightGrayColor()


    /**
     * This method gets called when the view loads.
     */
    override func viewDidLoad() {
        super.viewDidLoad()

        // Reset alternative mapcode index.
        currentAlternativeMapcode = 0
        theAlternative.hidden = true

        // Setup our Map View.
        theMap.delegate = self
        theMap.mapType = MKMapType.Standard
        theMap.showsUserLocation = true
        theMap.showsScale = true
        theMap.showsBuildings = true

        // Set initial map and zoom.
        let newRegion = MKCoordinateRegion(center:  mapcodeLocation,
                                           span: MKCoordinateSpanMake(spanInitX, spanInitY))
        theMap.setRegion(newRegion, animated: false)

        // Setup up delegates for text input boxes.
        theAddress.delegate = self
        theLat.delegate = self
        theLon.delegate = self
        theMapcodeInternational.delegate = self
        theMapcodeLocal.delegate = self

        // Recognize tap on map.
        let tap1 = UITapGestureRecognizer(target: self, action: #selector(handleMapTap1))
        tap1.numberOfTapsRequired = 1
        let tap2 = UITapGestureRecognizer(target: self, action: #selector(handleMapTap2))
        tap2.numberOfTapsRequired = 2
        let tap3 = UITapGestureRecognizer(target: self, action: #selector(handleMapTap3))
        tap3.numberOfTapsRequired = 3

        theMap.addGestureRecognizer(tap1)
        theMap.addGestureRecognizer(tap2)
        theMap.addGestureRecognizer(tap3)

        // Setup our Location Manager: high accuracy, but stopping location updates whenever possible.
        // The distance filter is to reduce double updates even further, as they lead to more REST calls.
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = distanceFilterMeters
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        updateFieldsLatLon(mapcodeLocation)
        queueUpdateForFieldMapcode(mapcodeLocation)
        queueUpdateForFieldAddress(mapcodeLocation)

        // Schedule updates for reverse geocoding and Mapcdode REST API requests.
        timerReverseGeocoding = NSTimer.scheduledTimerWithTimeInterval(
            limitReverseGeocodingSecs, target: self,
            selector: #selector(periodicCheckToUpdateFieldAddress),
            userInfo: nil, repeats: true)

        timerReverseGeocoding = NSTimer.scheduledTimerWithTimeInterval(
            limitMapcodeLookupSecs, target: self,
            selector: #selector(periodicCheckToUpdateFieldMapcode),
            userInfo: nil, repeats: true)
    }


    /**
     * Helper method to check if a gesture recognizer was used.
     */
    func mapViewRegionDidChangeFromUserInteraction() -> Bool {
        let view = self.theMap.subviews[0]

        // Look through gesture recognizers to determine whether this region change is from user interaction.
        if let gestureRecognizers = view.gestureRecognizers {
            for recognizer in gestureRecognizers {
                if (recognizer.state == UIGestureRecognizerState.Began) || (recognizer.state == UIGestureRecognizerState.Ended) {
                    return true
                }
            }
        }
        return false
    }
    

    /**
     * Helper method to record if the map change was by user interaction.
     */
    func mapView(mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        mapChangedFromUserInteraction = mapViewRegionDidChangeFromUserInteraction()
    }


    /**
     * This method gets called whenever a location change is detected.
     */
    func mapView(mapView: MKMapView,
                 regionDidChangeAnimated animated: Bool) {

        // Stop auto-move.
        moveMapToUserLocation = false;
        if mapChangedFromUserInteraction {

            // Update fields.
            mapcodeLocation = mapView.centerCoordinate
            updateFieldsLatLon(mapcodeLocation);
            queueUpdateForFieldMapcode(mapcodeLocation)
            queueUpdateForFieldAddress(mapcodeLocation)
        }
        else {

            // Fields were already updated.
        }
    }


    /**
     * This method gets called when the user taps the map.
     */
    func handleMapTap1(gestureRecognizer: UITapGestureRecognizer) {

        // Don't auto-zoom to user location anymore.
        firstLocationSinceStarted = false

        // Get location of tap.
        let location = gestureRecognizer.locationInView(theMap)
        mapcodeLocation = theMap.convertPoint(location, toCoordinateFromView: theMap)

        // Set map center and update fields.
        theMap.setCenterCoordinate(mapcodeLocation, animated: true)

        // The map view will move and consequently fields get updated by regionDidChangeAnimated.
        updateFieldsLatLon(mapcodeLocation);
        queueUpdateForFieldMapcode(mapcodeLocation)
        queueUpdateForFieldAddress(mapcodeLocation)
    }
    
    
    /**
     * This method gets called when the user double taps the map.
     */
    func handleMapTap2(gestureRecognizer: UITapGestureRecognizer) {

        // Auto zoom-in on lat tap. No need to update fields - single tap has already been handled.
        let newRegion = MKCoordinateRegion(center: mapcodeLocation,
                                           span: MKCoordinateSpanMake(spanZoomedInX, spanZoomedInY))
        theMap.setRegion(newRegion, animated: true)
    }

    
    /**
     * This method gets called when the user triple taps the map.
     */
    func handleMapTap3(gestureRecognizer: UITapGestureRecognizer) {

        // Auto zoom-in on lat tap. No need to update fields - single tap has already been handled.
        let newRegion = MKCoordinateRegion(center: mapcodeLocation,
                                           span: MKCoordinateSpanMake(spanZoomedOutX, spanZoomedOutY))
        theMap.setRegion(newRegion, animated: true)
    }


    /**
     * This gets called whenever the use switches between map types.
     */
    @IBAction func segmentedControlAction(sender: UISegmentedControl!) {
        switch sender.selectedSegmentIndex {

        case 0:
            theMap.mapType = .Standard

        case 1:
            theMap.mapType = .Satellite

        default:
            theMap.mapType = .Hybrid
        }
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
        firstLocationSinceStarted = false

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
            print("textFieldShouldReturn: Unknown text field, tag=\(textField.tag)")
        }
        return true
    }


    /**
     * Address box was edited.
     */
    func useAddress(address: String) {

        // Geocode address.
        debug(INFO, msg: "Call Forward Geocoding API: \(address)")
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address, completionHandler: {
            (placemarks, error) -> Void in
            if (error != nil) || (placemarks == nil) || (placemarks?.first == nil) || (placemarks?.first?.location == nil) {
                print("useAddress: Geocode failed, address=\(address), error=\(error)")
                self.showAlert("Incorrect address", message: "Can't find a location for\n'\(address)'", button: "OK")

                // Reset address field; need to do a new reverse geocode as previous text is lost.
                dispatch_async(dispatch_get_main_queue()) {
                    self.queueUpdateForFieldAddress(self.mapcodeLocation)
                }
            }
            else {

                // Found location.
                let coordinate = (placemarks?.first!.location!.coordinate)!
                dispatch_async(dispatch_get_main_queue()) {

                    // Update location.
                    self.mapcodeLocation = coordinate
                    self.theMap.setCenterCoordinate(coordinate, animated: false)
                    self.updateFieldsLatLon(coordinate)
                    self.queueUpdateForFieldMapcode(coordinate)
                    self.queueUpdateForFieldAddress(coordinate)
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
        lat = max(-90.0, min(90.0, lat!))
        lon = max(-180.0, min(180.0, lon!))

        // Update location.
        mapcodeLocation = CLLocationCoordinate2D(latitude: lat!, longitude: lon!)
        theMap.setCenterCoordinate(mapcodeLocation, animated: false)
        updateFieldsLatLon(mapcodeLocation)
        queueUpdateForFieldMapcode(mapcodeLocation)
        queueUpdateForFieldAddress(mapcodeLocation)
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
            print("useMapcode: Bad URL, url=\(url)")
            return
        }

        // Get coordinate.
        debug(INFO, msg: "Call Mapcode API: url=\(url)")
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
                    let lat = (json["latDeg"]?.doubleValue)!
                    let lon = (json["lonDeg"]?.doubleValue)!
                    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)

                    // Update location and set map center.
                    dispatch_async(dispatch_get_main_queue()) {
                        self.mapcodeLocation = coordinate
                        self.theMap.setCenterCoordinate(coordinate, animated: false)
                        self.updateFieldsLatLon(coordinate)
                        self.queueUpdateForFieldMapcode(coordinate)
                        self.queueUpdateForFieldAddress(coordinate)
                    }
                }
                else {
                    print("useMapcode: Find mapcode failed, url=\(url), status=\(httpResponse?.statusCode), json=\(json)")

                    // Revert to previous mapcode; need to call REST API because previous text is lost.
                    dispatch_async(dispatch_get_main_queue()) {
                        self.queueUpdateForFieldMapcode(self.mapcodeLocation)
                    }
                }

            } catch {
                print("useMapcode: API call failed, url=\(url), error=\(error)")
            }
        }
    }


    /**
     * This method gets called when the "info" icon is pressed.
     */
    @IBAction func showInfo(sender: AnyObject) {
        let version = NSBundle.mainBundle().infoDictionary!["CFBundleShortVersionString"] as! String
        let build = NSBundle.mainBundle().infoDictionary!["CFBundleVersion"] as! String
        self.showAlert("Mapcode \(version) (build \(build))", message:
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

        // Invalidate timer.
        timerLocationUpdates.invalidate()

        // Set auto-move to user location and start collecting updates and update map.
        moveMapToUserLocation = true;

        // Turn on location updates.
        turnOnLocationManagerUpdates()
    }


    /**
     * This method gets called when the "other territory" button is pressed.
     */
    @IBAction func showAlternativeMapcode(sender: AnyObject) {
        if alternativeMapcodes.count > 1 {
            theAlternative.hidden = false
            theMapcodeLocal.text = alternativeMapcodes[currentAlternativeMapcode]
            if currentAlternativeMapcode == 0 {
                title = "Shortest (+ \(alternativeMapcodes.count - 1) alternatives)"
            }
            else {
                title = "Alternative \(currentAlternativeMapcode) of \(alternativeMapcodes.count - 1)"
            }
            theAlternative.setTitle(title, forState: UIControlState.Normal)
            currentAlternativeMapcode = (currentAlternativeMapcode + 1) % alternativeMapcodes.count
        }
        else {
            theAlternative.hidden = true
        }
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
     * Update latitude and logitude fields.
     */
    func updateFieldsLatLon(coordinate: CLLocationCoordinate2D) {

        // Update latitude and longitude.
        theLat.text = String(format: "%3.5f", coordinate.latitude)
        theLon.text = String(format: "%3.5f", coordinate.longitude)
    }


    /**
     * Queue reverse geocode request (to a max of 1 in the queue).
     */
    func queueUpdateForFieldAddress(coordinate: CLLocationCoordinate2D) {

        // Dim text.
        theAddress.textColor = colorWaitingForUpdate

        // Keep only the last coordinate.
        queuedCoordinateForReverseGeocode = coordinate;
    }


    /**
     * This method limits the calls to the Apple API to once every x secs.
     */
    func periodicCheckToUpdateFieldAddress() {

        // Check if there is a pending request.
        if let coordinate = queuedCoordinateForReverseGeocode {

            // Clear the request.
            queuedCoordinateForReverseGeocode = nil

            // Get address from reverse geocode.
            debug(INFO, msg: "Call Reverse Geocoding API: \(coordinate)")
            CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), completionHandler: {
                (placemarks, error) -> Void in
                if error != nil {

                    // Print an message to console, but don't show a user dialog (not an error).
                    print("updateFieldsLatLonAddress: No reverse geocode info, coordinate=\(coordinate), error=\(error!.localizedDescription)")
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
                        self.theAddress.textColor = UIColor.blackColor()
                        self.theAddress.text = address;
                    }
                } else {
                    print("updateFieldsLatLonAddress: No placemarks, coordinate=\(coordinate)")
                }
            })
        }
    }


    /**
     * Queue Mapcode REST API request (to a max of 1 in the queue).
     */
    func queueUpdateForFieldMapcode(coordinate: CLLocationCoordinate2D) {

        // Dim text.
        theMapcodeInternational.textColor = colorWaitingForUpdate
        theMapcodeLocal.textColor = colorWaitingForUpdate

        // Keep only the last coordinate.
        queuedCoordinateForMapcodeLookup = coordinate;
    }


    /**
     * Call Mapcode REST API to get mapcode codes from latitude, longitude.
     */
    func periodicCheckToUpdateFieldMapcode() {

        // Check if there is a pending request.
        if let coordinate = queuedCoordinateForMapcodeLookup {

            // Clear the request.
            queuedCoordinateForMapcodeLookup = nil

            // Create URL for REST API call to get mapcodes, URL-encode lat/lon.
            let encodedLatLon = "\(coordinate.latitude),\(coordinate.longitude)".stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
            let url = "\(host)/mapcode/codes/\(encodedLatLon)?client=\(client)&allowLog=\(allowLog)"

            guard let rest = RestController.createFromURLString(url) else {
                print("updateFieldsMapcodes: Bad URL, url=\(url)")
                theMapcodeLocal.text = ""
                theMapcodeInternational.text = ""
                return
            }

            // Get mapcodes from REST API.
            debug(INFO, msg: "Call Mapcode API: \(url)")
            rest.get {
                result, httpResponse in
                do {
                    var territory: String! = nil
                    var mcInternational = ""
                    var mcLocal = ""

                    // Get JSON response.
                    let json = try result.value()

                    // The JSON response indicated an error, territory is set to nil.
                    if json["errors"] != nil {
                        print("updateFieldsMapcodes: Can get mapcode, coordinate=\(coordinate)")
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

                    // Reset alternative mapcodes.
                    var altMapcodes = [String]()

                    // Get alternative mapcodes.
                    if (json["mapcodes"] != nil) && (json["mapcodes"]?.jsonArray != nil) {
                        let alt = (json["mapcodes"]?.jsonArray)!

                        // The international code is always there and must not be used here.
                        if alt.count >= 2 {

                            // Add the shortest local one (which should exist now).
                            altMapcodes.append(mcLocal)

                            // Add the alternatives.
                            for i in 0...alt.count - 2 {
                                let mapcode = "\((alt[i]!["territory"]?.stringValue)!) \((alt[i]!["mapcode"]?.stringValue)!)"
                                if (mapcode != mcLocal) {
                                    altMapcodes.append(mapcode)
                                }
                            }
                        }
                    }

                    // Update mapcode fields on main thread.
                    dispatch_async(dispatch_get_main_queue()) {
                        self.theMapcodeInternational.textColor = UIColor.blackColor()
                        self.theMapcodeLocal.textColor = UIColor.blackColor()
                        self.theMapcodeInternational.text = mcInternational
                        self.theMapcodeLocal.text = mcLocal
                        self.prevTerritory = territory
                        self.currentAlternativeMapcode = 0
                        self.alternativeMapcodes = altMapcodes
                        self.showAlternativeMapcode(self)
                    }
                } catch {
                    print("updateFieldsMapcodes: API call failed, url=\(url), error=\(error)")
                    
                    // Something went wrong, discard mapcodes.
                    dispatch_async(dispatch_get_main_queue()) {
                        self.theMapcodeInternational.text = ""
                        self.theMapcodeLocal.text = ""
                    }
                }
            }
        }
    }


    /**
     * This method gets called whenever a location change is detected.
     */
    func locationManager(locationManager: CLLocationManager,
                         didUpdateLocations locations:[CLLocation]) {

        // Get new location.
        let newLocation = locations[0].coordinate

        // Set default span.
        var spanX = spanZoomedInY
        var spanY = spanZoomedInY

        // If it's a valid coordinate and we need to auto-move or it's the first location, move.
        if isValidCoordinate(newLocation) {
            if firstLocationSinceStarted || moveMapToUserLocation {

                // Update location.
                mapcodeLocation = newLocation;

                // First time location ever? Override map zoom.
                if firstLocationSinceStarted {
                    spanX = spanInitX
                    spanY = spanInitY
                    firstLocationSinceStarted = false
                }
                moveMapToUserLocation = false

                // Change zoom level, pretty much zoomed out.
                let newRegion = MKCoordinateRegion(center: mapcodeLocation,
                                                   span: MKCoordinateSpanMake(spanX, spanY))

                // Move without animation.
                theMap.setRegion(newRegion, animated: true)

                // Update text fields.
                updateFieldsLatLon(mapcodeLocation)
                queueUpdateForFieldMapcode(mapcodeLocation)
                queueUpdateForFieldAddress(mapcodeLocation)
            }

            // Stop receiving updates after we get a first (decent) user location.
            locationManager.stopUpdatingLocation()

            // Schedule updating the location again in some time.
            timerLocationUpdates = NSTimer.scheduledTimerWithTimeInterval(scheduleUpdateLocationsSecs, target: self,
                                                           selector: #selector(turnOnLocationManagerUpdates),
                                                           userInfo: nil, repeats: false)
        }
    }


    /**
     * Method to switch on the location manager updates.
     */
    func turnOnLocationManagerUpdates() {
        locationManager.startUpdatingLocation()
    }


    /**
     * This method gets called when the location cannot be fetched.
     */
    func locationManager(locationManager: CLLocationManager,
                         didFailWithError error: NSError) {

        // Code 0 is returned when during debugging anyhow.
        if (error.code != 0) {
            print("LocationManager:didFailWithError, error=\(error)")
        }
    }


    /**
     * This method gets called when the location authorization changes.
     */
    func locationManager(locationManager: CLLocationManager,
                         didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        print("locationManager:didChangeAuthorizationStatus, status=\(status)")

        let allow: Bool!
        switch status {

        case CLAuthorizationStatus.AuthorizedWhenInUse:
            allow = true

        case CLAuthorizationStatus.AuthorizedAlways:
            allow = true

        default:
            allow = false
            locationManager.stopUpdatingLocation()
        }
        theHere.enabled = allow
        theHere.hidden = !allow
    }


    /**
     * This method gets called when the "open in maps" icon is pressed.
     */
    @IBAction func openInMapApplication(sender: AnyObject) {
        openMapApplication(mapcodeLocation, name: getCurrentMapcodeName())
    }


    /**
     * Method to return mapcode name based on input fields.
     */
    func getCurrentMapcodeName() -> String {
        let name: String
        if (theMapcodeLocal.text != nil) && !(theMapcodeLocal.text?.isEmpty)! {
            name = theMapcodeLocal.text!
        }
        else {
            name = theMapcodeInternational.text!
        }
        return name
    }


    /**
     * This method open the Apple Maps application.
     */
    func openMapApplication(coordinate: CLLocationCoordinate2D, name: String) {

        // Minic current map.
        let span = theMap.region.span
        let center = theMap.region.center
        let options = [
            MKLaunchOptionsMapCenterKey: NSValue(MKCoordinate: center),
            MKLaunchOptionsMapSpanKey: NSValue(MKCoordinateSpan: span)
        ]

        // Set a placemark at the mapcode location.
        let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: nil)
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
     * This method checks if a coordinate is valid or not.
     */
    func isValidCoordinate(coordinate: CLLocationCoordinate2D) -> Bool {

        // Skip things very close (0, 0). Unfortunately you get (0, 0) sometimes as a coordinate.
        return (abs(coordinate.latitude) > 0.1) || (abs(coordinate.latitude) > 0.1)
    }



    /**
     * Simple debug loggin.
     */
    func debug(level: Int, msg: String) {
        if (level & debugMask) != 0 {
            print("DEBUG: \(msg)")
        }
    }

    /**
     * This method gets called when on low memory.
     */
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("didReceiveMemoryWarning: Low memory warning")
    }
}
