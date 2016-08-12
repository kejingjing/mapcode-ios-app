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

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate,
    UITextFieldDelegate, UIGestureRecognizerDelegate {

    /**
     * List of UI controls that we need to access from code.
     */
    @IBOutlet weak var theMap: MKMapView!
    @IBOutlet weak var theHere: UIButton!
    @IBOutlet weak var theMapType: UISegmentedControl!
    @IBOutlet weak var theZoomIn: UIButton!
    @IBOutlet weak var theZoomOut: UIButton!
    @IBOutlet weak var theShare: UIButton!
    @IBOutlet weak var theAddress: UITextField!
    @IBOutlet weak var theContext: UITextView!
    @IBOutlet weak var theContextLabel: UILabel!
    @IBOutlet weak var theNextContext: UIButton!
    @IBOutlet weak var theMapcode: UITextView!
    @IBOutlet weak var theMapcodeLabel: UILabel!
    @IBOutlet weak var theNextMapcode: UIButton!
    @IBOutlet weak var theLat: UITextField!
    @IBOutlet weak var theLon: UITextField!

    let debugMask = 0xFF    // Current debug messages mask.
    let DEBUG = 1
    let INFO = 2
    let WARN = 4
    let ERROR = 8

    let host: String = "http:/api.mapcode.com";     // Host name of Mapcode REST API.
    let allowLog: String = "true";                  // API: Allow logging requests.
    let client: String = "ios";                     // API: Client ID.

    let keyVersionBuild = "versionBuild"            // Version and build (for what's new).

    let mapcodeTerritoryFont = "HelveticaNeue"      // Font definitions.
    let mapcodeCodeFont = "HelveticaNeue-Bold"
    let mapcodeInternationalFont = "HelveticaNeue-Bold"
    let contextFont = "HelveticaNeue-Medium"
    let mapcodeTerritoryFontSize: CGFloat = 14.0;
    let mapcodeCodeFontSize: CGFloat = 16.0;
    let mapcodeInternationalFontSize: CGFloat = 16.0;
    let contextFontSize: CGFloat = 16.0;
    let mapcodeFontKern = 0.75
    let mapcodeTerritoryColor = UIColor.grayColor()
    let mapcodeInternationalColor = UIColor.darkGrayColor()

    var colorWaitingForUpdate = UIColor.lightGrayColor()    // Color for 'outdated' fields, waiting for update.

    // Provide a sensible screen if no user location is available (rather than mid Pacific).
    var mapcodeLocation = CLLocationCoordinate2D(latitude: 52.373293, longitude: 4.893718)

    let zoomFactor = 2.5                            // Factor for zoom in/out.

    let spanInitX = 1.0                             // Initial zoom, "country level".
    let spanInitY = 1.0

    let spanZoomedInX = 0.003                       // Zoomed in, after double tap.
    let spanZoomedInY = 0.003

    var locationManager: CLLocationManager!         // Controls and receives location updates.

    let scheduleUpdateLocationsSecs = 300.0         // Switch on update locations every x secs.
    let distanceFilterMeters = 10000.0              // Not interested in local position updates.

    var waitingForFirstLocationSinceStarted = true  // First location is different: auto-move to it.
    var moveMapToUserLocation = false               // True if map should auto-move to user location.

    var undoTextFieldEdit: String!                  // Undo edits if something went wrong.
    var mapChangedFromUserInteraction = false       // True if map was panned by user, rather than auto-move.

    var allMapcodes = [String]()                    // List of all mapcodes for current location (cannot be empty).
    var currentMapcodeIndex = 0                     // Index of current alternative; 0 = shortest, last = int'l.
    var nextMapcodeTapAdvances = true               // True if tapping advances through mapcodesor just tupdates field.

    var allContexts = [String]()                    // List of all contexts for current location (can be empty).
    var currentContextIndex = 0                     // Index of current context.

    var territoryFullNames = [String: String]()     // List of territory alpha codes and full names. Can be empty.

    var queuedCoordinateForReverseGeocode: CLLocationCoordinate2D!  // Queue of 1, for periodic rev. geocoding. Nil if none.
    var queuedCoordinateForMapcodeLookup: CLLocationCoordinate2D!   // Queue of 1, for mapcode lookup. Nil if none.

    var prevQueuedCoordinateForReverseGeocode: CLLocationCoordinate2D!  // Keep previous one, to skip new one if we can.
    var prevQueuedCoordinateForMapcodeLookup: CLLocationCoordinate2D!   // Ditto.

    var prevTimeForReverseGeocodeSecs: NSTimeInterval = 0.0   // Last time a request was made, to limit number of requests
    var prevTimeForMapcodeLookupSecs: NSTimeInterval = 0.0    // but react immediately after time of inactivity.

    let limitReverseGeocodingSecs = 1.0             // Limit webservice API's to no
    let limitMapcodeLookupSecs = 1.0                // more than x requests per second.

    var timerReverseGeocoding = NSTimer()           // Timer to schedule/limit reverse geocoding.
    var timerLocationUpdates = NSTimer()            // Timer to schedule/limit location updates.

    var mapcodeRegex = try! NSRegularExpression(    // Pattern to match mapcodes: XXX[-XXX] XXXXX.XXXX[-XXXXXXXX]
        pattern: "\\A\\s*(?:[a-zA-Z0-9]{2,3}(?:[-][a-zA-Z0-9]{2,3})?\\s+)?[a-zA-Z0-9]{2,5}[.][a-zA-Z0-9]{2,4}(?:[-][a-zA-Z0-9]{1,8})?\\s*\\Z",
        options: [])

    let territoryInternationalAlphaCode = "AAA"         // Territory code for international context.
    let territoryInternationalFullName = "Earth"        // Territory full name for international context.

    // Texts in dialogs.
    let textCopiedToClipboard = "COPIED TO CLIPBOARD"
    let textShortest = "SHORTEST"
    let textAlternative = "ALTERNATIVE"
    let textTerritory = "TERRITORY"
    let textInternational = "INTERNATIONAL"
    let textOf = "OF"
    let textAlternativeShort = "ALT."
    let textNoTerritoriesFound = "No territories found"
    let textLoadingTerritories = "Loading territories..."


    /**
     * This method gets called when the view loads. It is called exactly once.
     */
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup our Map View.
        theMap.delegate = self
        theMap.mapType = MKMapType.Standard
        theMap.showsUserLocation = true
        theMap.showsScale = true
        theMap.showsBuildings = true

        // Set initial map and zoom. Pick a decent location to start with until a real location is found.
        let newRegion = MKCoordinateRegion(center:  mapcodeLocation,
                                           span: MKCoordinateSpanMake(spanInitX, spanInitY))
        theMap.setRegion(newRegion, animated: false)

        // Setup up delegates for text input boxes, so events are handled.
        theAddress.delegate = self
        theLat.delegate = self
        theLon.delegate = self

        // Set text fields.
        theAddress.text = ""
        theContext.text = ""
        theContextLabel.text = "TERRITORY"
        theNextContext.hidden = true
        theMapcode.text = ""
        theMapcodeLabel.text = "SHORTEST"
        theNextMapcode.hidden = true
        theLat.text = ""
        theLon.text = ""

        // Disabled the "share" button.
        theShare.hidden = true

        // Recognize 1 or 2 taps on map.
        let tapMap1 = UITapGestureRecognizer(target: self, action: #selector(handleMapTap1))
        theMap.addGestureRecognizer(tapMap1)

        let tapMap2 = UITapGestureRecognizer(target: self, action: #selector(handleMapTap2))
        tapMap2.numberOfTapsRequired = 2
        theMap.addGestureRecognizer(tapMap2)

        // Recognize 1 tap on mapcode.
        let tapMapcode = UITapGestureRecognizer(target: self, action: #selector(handleMapcodeTap))
        theMapcode.addGestureRecognizer(tapMapcode)

        // Recognize 1 tap on context and mapcode label
        let tapContextLabel = UITapGestureRecognizer(target: self, action: #selector(handleContextLabelTap))
        theContextLabel.addGestureRecognizer(tapContextLabel)
        let tapMapcodeLabel = UITapGestureRecognizer(target: self, action: #selector(handleMapcodeLabelTap))
        theMapcodeLabel.addGestureRecognizer(tapMapcodeLabel)

        // Setup our Location Manager. Only 1 location update is requested when the user presses
        // the "Find My Location" button. Updates are switched off immediately after that. Only
        // once every couple of minutes it is switched on for a single event again (or finding your
        // position would take longer or be less accurate). The large distance filter causes the
        // code not be called for local udpates, as that might lead to more REST calls.
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = distanceFilterMeters
        locationManager.requestWhenInUseAuthorization()     // Only when app is active.
        locationManager.startUpdatingLocation()             // Try to get the first location.

        // Show the current lat/lon and queue webservice calls for the location.
        showLatLon(mapcodeLocation)
        queueUpdateForMapcode(mapcodeLocation)
        queueUpdateForAddress(mapcodeLocation)

        // Schedule periodic updates for reverse geocoding and Mapcdode REST API requests.
        timerReverseGeocoding = NSTimer.scheduledTimerWithTimeInterval(
            limitReverseGeocodingSecs, target: self,
            selector: #selector(periodicCheckToUpdateAddress),
            userInfo: nil, repeats: true)

        timerReverseGeocoding = NSTimer.scheduledTimerWithTimeInterval(
            limitMapcodeLookupSecs, target: self,
            selector: #selector(periodicCheckToUpdateMapcode),
            userInfo: nil, repeats: true)
    }


    /**
     * This method gets called when the view is displayed.
     */
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        // Show initial what's new dialog (if this is a new version).
        showWhatsNew()
    }


    /**
     * This method presents the 'What's new" box.
     */
    func showWhatsNew() {
        let version = NSBundle.mainBundle().infoDictionary!["CFBundleShortVersionString"] as! String
        let build = NSBundle.mainBundle().infoDictionary!["CFBundleVersion"] as! String
        let versionBuild = "\(version, build)"

        let defaults = NSUserDefaults.standardUserDefaults()
        let prevVersionBuild = defaults.stringForKey(keyVersionBuild)

        // Check if the app was updated.
        if (prevVersionBuild == nil) || (prevVersionBuild != versionBuild) {

            defaults.setValue(versionBuild, forKey: keyVersionBuild)
            defaults.synchronize()

            self.showAlert("What's New", message: "Improvements in version \(version)\n(build \(build))\n" +
                "* Tap on the mapcode field to copy it to clipboard.\n" +
                "* Tap on icon or label to show next territory or mapcode.\n" +
                "* Zoom buttons have larger touch areas.\n" +
                "* Improved responsiveness to get address/mapcode.\n" +
                "* Improved battery life, optimized location updates and web service calls.\n" +
                "* Increased font size of text fields.\n" +
                "* Fixed a bug which prevented international code showing up sometimes.\n" +
                "* New icon to move to next territory or mapcode (should be clearer now).",
                           button: "Dismiss")
        }
    }


    /**
     * This method gets called when the "info" icon is pressed.
     */
    @IBAction func showInfo(sender: AnyObject) {
        let version = NSBundle.mainBundle().infoDictionary!["CFBundleShortVersionString"] as! String
        let build = NSBundle.mainBundle().infoDictionary!["CFBundleVersion"] as! String
        self.showAlert("Mapcode \(version) (build \(build))", message: "Copyright (C) 2016\n" +
            "Rijn Buve, Mapcode Foundation\n\n" +

            "Get a mapcode by entering an address or coordinate, or moving the map around. You can tap " +
            "the map to move directly to a location and show the mapcode. Tap twice to zoom in really deep.\n\n" +

            "Move to the next territory or mapcode by clicking on the fast-forward icon or simply on the label. " +
            "Copy the mapcode to the clipboard by tapping the mapcode box.\n\n" +

            "Show a mapcode on the map by entering it in the address box. Tip: If you omit " +
            "the territory for a local mapcode, the current territory is automatically assumed.\n\n" +

            "Plan a route to a mapcode by entering it and then tapping on the 'map' icon at the bottom right of the map.\n\n" +

            "For more info on mapcodes in general, visit us at: http://mapcode.com\n\n________\n" +

            "Note that some usage data may be collected to improve the Mapcode REST API service " +
            "(not used for commercial purposes).", button: "Dismiss")
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
     * Delegate method to record if the map change was by user interaction.
     */
    func mapView(mapView: MKMapView,
                 regionWillChangeAnimated animated: Bool) {
        mapChangedFromUserInteraction = mapViewRegionDidChangeFromUserInteraction()
    }


    /**
     * Delegate method gets called whenever a location change is detected.
     */
    func mapView(mapView: MKMapView,
                 regionDidChangeAnimated animated: Bool) {

        // Stop auto-move, we don't want to keep auto-moving.
        moveMapToUserLocation = false;
        if mapChangedFromUserInteraction {

            // Update fields.
            mapcodeLocation = mapView.centerCoordinate
            showLatLon(mapcodeLocation);
            queueUpdateForMapcode(mapcodeLocation)
            queueUpdateForAddress(mapcodeLocation)
        }
        else {

            // Fields were already updated, this map movement is a result of that.
        }
    }


    /**
     * Gesture recognizer: this method gets called when the user taps the map once.
     */
    func handleMapTap1(gestureRecognizer: UITapGestureRecognizer) {

        // Don't auto-zoom to user location anymore.
        waitingForFirstLocationSinceStarted = false

        // Get location of tap.
        let location = gestureRecognizer.locationInView(theMap)
        mapcodeLocation = theMap.convertPoint(location, toCoordinateFromView: theMap)

        // Set map center and update fields.
        theMap.setCenterCoordinate(mapcodeLocation, animated: true)

        // The map view will move and consequently fields get updated by regionDidChangeAnimated.
        showLatLon(mapcodeLocation);
        queueUpdateForMapcode(mapcodeLocation)
        queueUpdateForAddress(mapcodeLocation)
    }
    
    
    /**
     * Gesture recognizer: this method gets called when the user taps the map twice. Mind you:
     * The first tap has already been handled by the "tap once" recognizer.
     */
    func handleMapTap2(gestureRecognizer: UITapGestureRecognizer) {

        // Auto zoom-in on lat tap. No need to update fields - single tap has already been handled.
        let newRegion = MKCoordinateRegion(center: mapcodeLocation,
                                           span: MKCoordinateSpanMake(spanZoomedInX, spanZoomedInY))
        theMap.setRegion(newRegion, animated: true)
    }

    
    /**
     * Gesture recognizer: this method gets called when the user taps the mapcode.
     */
    func handleMapcodeTap(gestureRecognizer: UITapGestureRecognizer) {
        UIPasteboard.generalPasteboard().string = theMapcode.text
        theMapcodeLabel.text = textCopiedToClipboard

        // Do not advance next at next tap; just update field.
        nextMapcodeTapAdvances = false;
    }

    
    /**
     * This gets called whenever the use switches between nromal and hybrid map types.
     */
    @IBAction func segmentedControlAction(sender: UISegmentedControl!) {
        switch sender.selectedSegmentIndex {

        case 0:
            theMap.mapType = .Standard

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
     * This method moves the screen up when editing starts.
     */
    func textFieldDidBeginEditing(textField: UITextField) {
        self.animateTextField(textField, up: true)
    }


    /**
     * This method moves the screen down when editing is done.
     */
    func textFieldDidEndEditing(textField: UITextField) {
        self.animateTextField(textField, up: false)
    }

    
    /**
     * This method gets called when user starts editing a text field. Keep the previous
     * value for undo. Careful though: the undo text is shared for all fields.
     */
    @IBAction func beginEdit(textField: UITextField) {
        dispatch_async(dispatch_get_main_queue()) {
            textField.becomeFirstResponder()
            textField.selectedTextRange = textField.textRangeFromPosition(
                textField.beginningOfDocument, toPosition: textField.endOfDocument)
            self.undoTextFieldEdit = textField.text
        }
    }


    /**
     * Delegate method gets called when the Return key is pressed in a text edit field.
     */
    func textFieldShouldReturn(textField: UITextField) -> Bool {

        // Hide keyboard.
        textField.resignFirstResponder()

        // Do not process empty fields.
        if (textField.text == nil) || (textField.text?.isEmpty)! {

            // Restore contents of field.
            textField.text = undoTextFieldEdit
            return true
        }

        // Don't auto-zoom to user location anymore.
        waitingForFirstLocationSinceStarted = false

        // Determine which field we're in.
        switch textField.tag {

        case theAddress.tag:

            // Check if the user entered a mapcode instead of an address.
            let matches = mapcodeRegex.matchesInString(
                theAddress.text!, options: [],
                range: NSRange(location: 0, length: theAddress.text!.characters.count))
            if matches.count == 1 {
                debug(DEBUG, msg: "textFieldShouldReturn: Entered mapcode, mapcode=\(theAddress.text!)")
                mapcodeWasEntered(theAddress.text!)
            }
            else {
                debug(DEBUG, msg: "textFieldShouldReturn: Entered address, address=\(theAddress.text!)")
                addressWasEntered(theAddress.text!)
            }

        case theLat.tag:

            // Check if we can actually convert this to a double.
            if Double(theLat.text!) != nil {
                coordinateWasEntered(theLat.text!, longitude: theLon.text!)
            }
            else {
                theLat.text = undoTextFieldEdit
            }

        case theLon.tag:

            // Check if we can actually convert this to a double.
            if Double(theLon.text!) != nil {
                coordinateWasEntered(theLat.text!, longitude: theLon.text!)
            }
            else {
                theLon.text = undoTextFieldEdit
            }

        default:
            debug(ERROR, msg: "textFieldShouldReturn: Unknown text field, tag=\(textField.tag)")
        }
        return true
    }


    /**
     * This method gets called when an address was entered.
     */
    func addressWasEntered(address: String) {

        // Geocode address.
        debug(INFO, msg: "addressWasEntered: Call Forward Geocoding API: \(address)")
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address, completionHandler: {
            (placemarks, error) -> Void in

            if (error != nil) || (placemarks == nil) || (placemarks?.first == nil) || (placemarks?.first?.location == nil) {
                self.debug(self.INFO, msg: "addressWasEntered: Geocode failed, address=\(address), error=\(error)")

                dispatch_async(dispatch_get_main_queue()) {
                    self.showAlert("Incorrect address", message: "Can't find a location for\n'\(address)'", button: "Dismiss")

                    // Force call to reset address field; need to do a new reverse geocode as previous text is lost.
                    self.prevQueuedCoordinateForReverseGeocode = nil
                    self.queueUpdateForAddress(self.mapcodeLocation)
                }
            }
            else {

                // Found location.
                let coordinate = (placemarks?.first!.location!.coordinate)!
                dispatch_async(dispatch_get_main_queue()) {

                    // Update location.
                    self.mapcodeLocation = coordinate
                    self.theMap.setCenterCoordinate(coordinate, animated: false)
                    self.showLatLon(coordinate)
                    self.queueUpdateForMapcode(coordinate)
                    self.queueUpdateForAddress(coordinate)
                }
            }
        })
    }

    /**
     * This method gets called when a mapcode was entered.
     */
    func mapcodeWasEntered(mapcode: String) {

        // Prefix previous territory for local mapcodes.
        var fullMapcode = mapcode;
        if (mapcode.characters.count < 10) && !mapcode.containsString(" ") && !allContexts.isEmpty {
            fullMapcode = "\(allContexts[currentContextIndex]) \(mapcode)"
        }

        // Create URL for REST API call to get mapcodes.
        let encodedMapcode = fullMapcode.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
        let url = "\(host)/mapcode/coords/\(encodedMapcode)?client=\(client)&allowLog=\(allowLog)"
        guard let rest = RestController.createFromURLString(url) else {
            debug(ERROR, msg: "mapcodeWasEntered: Bad URL, url=\(url)")
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
                    self.debug(self.INFO, msg: "mapcodeWasEntered: Incorrect mapcode=\(mapcode)")
                    dispatch_async(dispatch_get_main_queue()) {
                        self.showAlert("Incorrect mapcode", message: "Mapcode '\(mapcode)' does not exist", button: "Dismiss")
                    }
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
                        self.showLatLon(coordinate)
                        self.queueUpdateForMapcode(coordinate)
                        self.queueUpdateForAddress(coordinate)
                    }
                }
                else {
                    self.debug(self.INFO, msg: "mapcodeWasEntered: Find mapcode failed, url=\(url), status=\(httpResponse?.statusCode), json=\(json)")

                    // Revert to previous address; need to call REST API because previous text is lost.
                    dispatch_async(dispatch_get_main_queue()) {

                        // Force call.
                        self.prevQueuedCoordinateForReverseGeocode = nil
                        self.queueUpdateForAddress(self.mapcodeLocation)
                    }
                }

            } catch {
                self.debug(self.WARN, msg: "mapcodeWasEntered: API call failed, url=\(url), error=\(error)")
            }
        }
    }
    
    
    /**
     * This method gets called when the lat or lon box was edited.
     */
    func coordinateWasEntered(latitude: String, longitude: String) {
        var lat = Double(latitude)
        var lon = Double(longitude)
        if (lat != nil) && (lon != nil) {

            // Limit range.
            lat = truncLatitude(lat!)
            lon = truncLongitude(lon!)

            // Update location.
            mapcodeLocation = CLLocationCoordinate2D(latitude: lat!, longitude: lon!)
            theMap.setCenterCoordinate(mapcodeLocation, animated: false)
            showLatLon(mapcodeLocation)
            queueUpdateForMapcode(mapcodeLocation)
            queueUpdateForAddress(mapcodeLocation)
        }
    }


    /**
     * Call Mapcode REST API to get territory names.
     */
    func fetchTerritoryNamesFromServer() {

        // Fetch territory information from server.
        let url = "\(host)/mapcode/territories/?client=\(client)&allowLog=\(allowLog)"
        guard let rest = RestController.createFromURLString(url) else {
            debug(ERROR, msg: "fetchTerritoryNamesFromServer: Bad URL, url=\(url)")
            return
        }

        // Get territories.
        debug(INFO, msg: "Call Mapcode API: url=\(url)")
        rest.get {
            result, httpResponse in
            do {
                // Get JSON response.
                let json = try result.value()

                // The JSON response indicated an error, territory is set to nil.
                if (json["errors"] != nil) || (json["territories"] == nil) || ((json["territories"]?.jsonArray == nil)) {
                    self.debug(self.WARN, msg: "fetchTerritoryNamesFromServer: Can get territories from server, errors=\(json["errors"])")
                }

                // Get territories and add to our map.
                var newTerritoryFullNames = [String: String]()
                let territories = (json["territories"]?.jsonArray)!
                for territory in territories {
                    let alphaCode = territory["alphaCode"]?.stringValue
                    let fullName = territory["fullName"]?.stringValue
                    newTerritoryFullNames[alphaCode!] = fullName!
                }
                newTerritoryFullNames[self.territoryInternationalAlphaCode] = self.territoryInternationalFullName

                // Update mapcode fields on main thread.
                dispatch_async(dispatch_get_main_queue()) {

                    // Pass territories to main and update context field.
                    self.territoryFullNames = newTerritoryFullNames
                    self.updateContext()
                }
            } catch {
                self.debug(self.WARN, msg: "fetchTerritoryNamesFromServer: API call failed, url=\(url), error=\(error)")
            }
        }
    }


    /**
     * This method gets called when the "find here" icon is pressed.
     */
    @IBAction func findHere(sender: AnyObject) {

        // Invalidate timer: cancels next scheduled update. Will automatically be-rescheduled.
        timerLocationUpdates.invalidate()

        // Set auto-move to user location and start collecting updates and update map.
        moveMapToUserLocation = true;

        // Turn on location updates.
        turnOnLocationManagerUpdates()
    }
    
    
    /**
     * This method gets called when the "zoom in" icon is pressed.
     */
    @IBAction func zoomIn(sender: AnyObject) {
        var region = theMap.region
        let lat = region.span.latitudeDelta / zoomFactor
        let lon = region.span.longitudeDelta / zoomFactor
        region.span.latitudeDelta  = max(0.0, lat)
        region.span.longitudeDelta = max(0.0, lon)
        theMap.setRegion(region, animated: true)
    }


    /**
     * This method gets called when the "zoom out" icon is pressed.
     */
    @IBAction func zoomOut(sender: AnyObject) {
        var region = theMap.region
        let lat = region.span.latitudeDelta * zoomFactor
        let lon = region.span.longitudeDelta * zoomFactor
        region.span.latitudeDelta  = min(120.0, lat)
        region.span.longitudeDelta = min(160,0, lon)
        theMap.setRegion(region, animated: true)
    }


    /**
     * This method gets called when the user taps the context label, which means: next item.
     */
    func handleContextLabelTap(gestureRecognizer: UITapGestureRecognizer) {
        nextContext(self)
    }


    /**
     * This method gets called when the "toggle mapcode" button is pressed.
     */
    @IBAction func nextContext(sender: AnyObject) {

        // Move to next alternative next time we press the button.
        if allContexts.isEmpty {

            // There are no contexts. Reset index for next time there are contexts.
            currentContextIndex = 0
        }
        else {

            // Wrap when counting.
            currentContextIndex = (currentContextIndex + 1) % allContexts.count
        }

        // Reset mapcode index when changing context.
        currentMapcodeIndex = 0

        // Show current mapcode.
        updateContext()

        // Show mapcodes for context.
        updateMapcode()
    }
    
    
    /**
     * This method gets called when the user taps the mapcode label, which means: next item.
     */
    func handleMapcodeLabelTap(gestureRecognizer: UITapGestureRecognizer) {
        nextMapcode(self)
    }

    
    /**
     * This method gets called when the "toggle mapcode" button is pressed.
     */
    @IBAction func nextMapcode(sender: AnyObject) {

        // Move to next alternative next time we press the button.
        if nextMapcodeTapAdvances {

            // Move to next mapcode.
            currentMapcodeIndex += 1
        }
        else {

            // Only update (e.g. after copied to clipboard). Always reset flag after a tap.
            nextMapcodeTapAdvances = true;
        }

        // Show current mapcode, no need to update context field.
        updateMapcode()
    }

    
    /**
     * This method updates the mapcode and mapcode label fields.
     */
    func updateMapcode() {

        // Selected context.
        var context: String!
        if !allContexts.isEmpty && (currentContextIndex < (allContexts.count - 1)) {
            context = allContexts[currentContextIndex]
        }

        // Add mapcodes in territory only.
        var selection = [String]()
        for m in allMapcodes {

            // Add the code if the territory is OK, or the context is international and 
            // it's the international code.
            if m.containsString("\(context) ") ||
                ((context == nil) && !m.containsString(" ")) {
                selection.append(m)
            }
        }

        // Limit index to a place in this list.
        let count = selection.count
        if currentMapcodeIndex >= count {
            currentMapcodeIndex = 0
        }
        let mapcode = selection[currentMapcodeIndex]

        // Set the mapcode text.
        let attributedText = NSMutableAttributedString(string: mapcode)

        // Set defaults.
        let fullRange = NSMakeRange(0, mapcode.characters.startIndex.distanceTo(mapcode.characters.endIndex))
        attributedText.addAttributes([NSFontAttributeName: UIFont(name: mapcodeCodeFont, size: mapcodeCodeFontSize)!], range: fullRange)
        attributedText.addAttributes([NSKernAttributeName: mapcodeFontKern], range: fullRange)

        // If the code has a territory, make it look different.
        let index = mapcode.characters.indexOf(Character(" "))
        if index != nil {
            let count = mapcode.characters.startIndex.distanceTo(index!)
            attributedText.addAttributes([NSForegroundColorAttributeName: mapcodeTerritoryColor], range: NSMakeRange(0, count))
            attributedText.addAttributes([NSFontAttributeName: UIFont(name: mapcodeTerritoryFont, size: mapcodeTerritoryFontSize)!], range: NSMakeRange(0, count))
        }
        else {

            // If the code has no territory, it is the international code.
            attributedText.addAttributes([NSFontAttributeName: UIFont(name: mapcodeInternationalFont, size: mapcodeInternationalFontSize)!], range: fullRange)
            attributedText.addAttributes([NSForegroundColorAttributeName: mapcodeInternationalColor], range: fullRange)
        }
        theMapcode.attributedText = attributedText

        // Set the mapcode label text.
        if count == 1 {
            theNextMapcode.hidden = true
            if mapcode.containsString(" ") {
                theMapcodeLabel.text = textShortest
            }
            else {
                theMapcodeLabel.text = textInternational
            }
        }
        else {
            theNextMapcode.hidden = false
            if currentMapcodeIndex == 0 {
                theMapcodeLabel.text = "\(textShortest) (+\(count - 1) \(textAlternativeShort))"
            }
            else {
                theMapcodeLabel.text = "\(textAlternative) \(currentMapcodeIndex)"
            }
        }
    }


    /**
     * This method udpates the context and context label fields.
     */
    func updateContext() {

        // Get current context.
        var fullName: String!
        if !allContexts.isEmpty {

            // Find its full name.
            let alphaCode = allContexts[currentContextIndex]
            fullName = territoryFullNames[alphaCode]
            if fullName == nil {
                debug(ERROR, msg: "updateContext: Territory not found, alphaCode=\(alphaCode)")
            }
        }

        // Check if full name was found. Normally it is only not found if either the territories were
        // not loaded yet, or there are no contexts for this location.

        if fullName == nil {
            fullName = textLoadingTerritories
        }

        // Show full name.
        let attributedText = NSMutableAttributedString(string: fullName!)
        let fullRange = NSMakeRange(0, fullName!.characters.startIndex.distanceTo(fullName!.characters.endIndex))
        attributedText.addAttributes([NSFontAttributeName: UIFont(name: contextFont, size: contextFontSize)!], range: fullRange)

        // Use different color for international conext.
        if currentContextIndex == allContexts.count - 1 {
            attributedText.addAttributes([NSForegroundColorAttributeName: mapcodeInternationalColor], range: fullRange)
        }
        theContext.attributedText = attributedText

        // Set the mapcode label text.
        if allContexts.count <= 1 {
            theNextContext.hidden = true
            theContextLabel.text = textTerritory
        }
        else {
            theNextContext.hidden = false
            theContextLabel.text = "\(textTerritory) \(currentContextIndex + 1) \(textOf) \(allContexts.count)"
        }
    }


    /**
     * Update latitude and logitude fields.
     */
    func showLatLon(coordinate: CLLocationCoordinate2D) {

        // Update latitude and longitude, strip to microdegree precision.
        theLat.text = String(format: "%3.5f", coordinate.latitude)
        theLon.text = String(format: "%3.5f", coordinate.longitude)
    }


    /**
     * Queue reverse geocode request (to a max of 1 in the queue).
     */
    func queueUpdateForAddress(coordinate: CLLocationCoordinate2D) {

        // Keep only the last coordinate.
        queuedCoordinateForReverseGeocode = coordinate;

        // And try immediately.
        periodicCheckToUpdateAddress()
    }


    /**
     * This method limits the calls to the Apple API to once every x secs.
     */
    func periodicCheckToUpdateAddress() {

        // Bail out if nothing changed.
        if isEqualOrNil(queuedCoordinateForReverseGeocode, prevCoordinate: prevQueuedCoordinateForReverseGeocode) {
            return
        }

        // Make sure we do this, even if we go back to the same coordinate (because text field is dimmed).
        prevQueuedCoordinateForReverseGeocode = nil

        // Something to do, dim current field.
        theAddress.textColor = colorWaitingForUpdate

        // Now check if we're not flooding the web service calls.
        let now = NSDate().timeIntervalSince1970
        let timePassed = now - prevTimeForReverseGeocodeSecs
        if timePassed < limitReverseGeocodingSecs {
            debug(DEBUG, msg: "periodicCheckToUpdateAddress: Filtered (too soon), timePassed=\(timePassed)")
            return
        }

        // Update last time stamp and previous request.
        prevTimeForReverseGeocodeSecs = now
        prevQueuedCoordinateForReverseGeocode = queuedCoordinateForReverseGeocode

        // Keep coordinate local.
        let coordinate = queuedCoordinateForReverseGeocode!

        // Clear the request.
        queuedCoordinateForReverseGeocode = nil

        // Get address from reverse geocode.
        debug(INFO, msg: "periodicCheckToUpdateAddress: Call Reverse Geocoding API: \(coordinate)")
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), completionHandler: {
            (placemarks, error) -> Void in
            if error != nil {

                // Print an message to console, but don't show a user dialog (not an error).
                self.debug(self.INFO, msg: "periodicCheckToUpdateAddress: No reverse geocode info, coordinate=\(coordinate), error=\(error!.localizedDescription)")
                return
            }

            // Construct address
            if placemarks!.count > 0 {
                let pm = placemarks![0] as CLPlacemark
                var address: String = "";

                // Streetname and housenumber.
                if pm.thoroughfare != nil {
                    address = pm.thoroughfare!
                    if pm.subThoroughfare != nil {

                        // User 'normal' or 'reverse' form of address.
                        if (self.useStreetThenNumber()) {
                            address = "\(address) \(pm.subThoroughfare!)";
                        }
                        else {
                            address = "\(pm.subThoroughfare!) \(address)";
                        }
                    }
                }

                // City.
                if pm.locality != nil {
                    if (!address.isEmpty) {
                        address = "\(address), ";
                    }
                    address = "\(address)\(pm.locality!)";
                }

                // Country.
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
            }
            else {
                self.debug(self.INFO, msg: "periodicCheckToUpdateAddress: No placemarks, coordinate=\(coordinate)")
            }
        })
    }


    /**
     * Queue Mapcode REST API request (to a max of 1 in the queue).
     */
    func queueUpdateForMapcode(coordinate: CLLocationCoordinate2D) {

        // Keep only the last coordinate.
        queuedCoordinateForMapcodeLookup = coordinate;

        // And try immediately.
        periodicCheckToUpdateMapcode()
    }


    /**
     * Call Mapcode REST API to get mapcode codes from latitude, longitude.
     */
    func periodicCheckToUpdateMapcode() {

        // Check if the territories were loaded yet from the Mapcode REST API.
        if territoryFullNames.isEmpty {
            fetchTerritoryNamesFromServer()
        }

        // Bail out if nothing changed.
        if isEqualOrNil(queuedCoordinateForMapcodeLookup, prevCoordinate: prevQueuedCoordinateForMapcodeLookup) {
            return
        }

        // Make sure we do this, even if we go back to the same coordinate (because text field is dimmed).
        prevQueuedCoordinateForMapcodeLookup = nil

        // Something to do, dim current field.
        theMapcode.textColor = colorWaitingForUpdate

        // Now check if we're not flooding the web service calls.
        let now = NSDate().timeIntervalSince1970
        let timePassed = now - prevTimeForMapcodeLookupSecs
        if timePassed < limitMapcodeLookupSecs {
            debug(DEBUG, msg: "periodicCheckToUpdateMapcode: Too soon, timePassed=\(timePassed)")
            return
        }

        // Update last time stamp and previous request.
        prevTimeForMapcodeLookupSecs = now
        prevQueuedCoordinateForMapcodeLookup = queuedCoordinateForMapcodeLookup

        // Keep the coordinate local.
        let coordinate = queuedCoordinateForMapcodeLookup

        // Clear the request.
        queuedCoordinateForMapcodeLookup = nil

        // Create URL for REST API call to get mapcodes, URL-encode lat/lon.
        let encodedLatLon = "\(coordinate.latitude),\(coordinate.longitude)".stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
        let url = "\(host)/mapcode/codes/\(encodedLatLon)?client=\(client)&allowLog=\(allowLog)"

        guard let rest = RestController.createFromURLString(url) else {
            debug(ERROR, msg: "updateFieldsMapcodes: Bad URL, url=\(url)")
            return
        }

        // Get mapcodes from REST API.
        debug(INFO, msg: "periodicCheckToUpdateMapcode: Call Mapcode API: url=\(url)")
        rest.get {
            result, httpResponse in
            do {
                var mcInternational = ""        // The international mapcode.
                var mcShortestLocal = ""        // The shortest code.

                // Get JSON response.
                let json = try result.value()

                // The JSON response indicated an error, territory is set to nil.
                if json["errors"] != nil {
                    self.debug(self.WARN, msg: "updateFieldsMapcodes: Can get mapcode, coordinate=\(coordinate)")
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
                        mcShortestLocal = "\((json["local"]?["territory"]?.stringValue)!) \((json["local"]?["mapcode"]?.stringValue)!)"
                    }
                }

                // Try to match existing context with 1 from the new list.
                var prevContext: String!
                if !self.allContexts.isEmpty {
                    prevContext = self.allContexts[self.currentContextIndex]
                }

                // Create a new list of mapcodes and contexts.
                var newAllMapcodes = [String]()
                var newAllContextsSet = Set<String>()

                // Get alternative mapcodes.
                if (json["mapcodes"] != nil) && (json["mapcodes"]?.jsonArray != nil) {
                    let alt = (json["mapcodes"]?.jsonArray)!

                    // The international code is always there.
                    if alt.count >= 2 {

                        // Add the shortest one (which must exist as there are 2+ codes).
                        newAllMapcodes.append(mcShortestLocal)

                        // Add the alternatives, including the international (which is last).
                        for i in 0...alt.count - 2 {

                            // Create the full mapcode.
                            let territory = (alt[i]!["territory"]?.stringValue)!
                            let mapcode = (alt[i]!["mapcode"]?.stringValue)!
                            let fullMapcode = "\(territory) \(mapcode)"

                            // Don't add the already added local code.
                            if (fullMapcode != mcShortestLocal) {
                                newAllMapcodes.append(fullMapcode)
                            }

                            // And keep the territories.
                            newAllContextsSet.insert(territory)
                        }
                    }
                }

                // Convert set of contexts into list and find previous context in list.
                var newContextIndex = 0
                var newAllContexts = [String]()
                var i = 0
                for context in newAllContextsSet {
                    newAllContexts.append(context)
                    if (prevContext != nil) && (context == prevContext) {
                        newContextIndex = i
                    }
                    i += 1
                }

                // Always append the international context at the end.
                newAllContexts.append(self.territoryInternationalAlphaCode)

                // Always append the international code.
                newAllMapcodes.append(mcInternational)

                // Update mapcode fields on main thread.
                dispatch_async(dispatch_get_main_queue()) {
                    self.allContexts = newAllContexts
                    self.currentContextIndex = newContextIndex
                    self.allMapcodes = newAllMapcodes
                    self.currentMapcodeIndex = 0
                    self.updateContext()
                    self.updateMapcode()
                }
            }
            catch {
                self.debug(self.WARN, msg: "updateFieldsMapcodes: API call failed, url=\(url), error=\(error)")
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
            if waitingForFirstLocationSinceStarted || moveMapToUserLocation {

                // Update location.
                mapcodeLocation = newLocation;

                // First time location ever? Override map zoom.
                if waitingForFirstLocationSinceStarted {
                    spanX = spanInitX
                    spanY = spanInitY
                    waitingForFirstLocationSinceStarted = false
                }
                moveMapToUserLocation = false

                // Change zoom level, pretty much zoomed out.
                let newRegion = MKCoordinateRegion(center: mapcodeLocation,
                                                   span: MKCoordinateSpanMake(spanX, spanY))

                // Move without animation.
                theMap.setRegion(newRegion, animated: true)

                // Update text fields.
                showLatLon(mapcodeLocation)
                queueUpdateForMapcode(mapcodeLocation)
                queueUpdateForAddress(mapcodeLocation)
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
            debug(WARN, msg: "LocationManager:didFailWithError, error=\(error)")
        }
    }


    /**
     * This method gets called when the location authorization changes.
     */
    func locationManager(locationManager: CLLocationManager,
                         didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        debug(INFO, msg: "locationManager:didChangeAuthorizationStatus, status=\(status)")

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
        openMapApplication(mapcodeLocation, name: theMapcode.text!)
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
     * Truncate latitude to [-90, 90].
     */
    func truncLatitude(latitude: Double) -> CLLocationDegrees {
        return max(-90.0, min(90.0, latitude))
    }


    /**
     * Truncate latitude to [-180, 180].
     */
    func truncLongitude(latitude: Double) -> CLLocationDegrees {
        return max(-180.0, min(180.0 - 1.0e-12, latitude))
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
     * Returns true if new coordinate is nil or no different from previous one.
     */
    func isEqualOrNil(newCoordinate: CLLocationCoordinate2D!, prevCoordinate: CLLocationCoordinate2D!) -> Bool {
        if newCoordinate == nil {

            // Nothing to do; new coordinate is nil.
        }
        else if prevCoordinate == nil {

            // New coordinate is not nil, old is nil, so not equal.
            return false;
        }
        else {

            // Both are not nil. Check if they are equal/
            if !isAlmostEqual(prevCoordinate.latitude, degree2: newCoordinate.latitude) ||
                !isAlmostEqual(prevCoordinate.longitude, degree2: newCoordinate.longitude) {
                return false
            }

            // Coordinates both exists and are equal.
        }
        return true
    }
    

    /**
     * Compares 2 degrees to microdegree level.
     */
    func isAlmostEqual(degree1: CLLocationDegrees, degree2: CLLocationDegrees) -> Bool {
        return abs(degree1 - degree2) < 1.0e-6
    }

    
    /**
     * Simple debug loggin.
     */
    func debug(level: Int, msg: String) {
        if (level & debugMask) != 0 {
            var prefix: String
            switch level {
            case DEBUG:
                prefix = "DEBUG"
            case INFO:
                prefix = "INFO"
            case WARN:
                prefix = "WARN"
            default:
                prefix = "ERROR"
            }
            print("\(prefix): \(msg)")
        }
    }


    /**
     * This method gets called when on low memory.
     */
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        debug(WARN, msg: "didReceiveMemoryWarning: Low memory warning")
    }
}
