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
import Contacts

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate,
        UITextFieldDelegate, UIGestureRecognizerDelegate {
    /**
     * List of UI controls that we need to access from code.
     */

    @IBOutlet weak var theMap: MKMapView!
    @IBOutlet weak var theFindMyLocation: UIButton!
    @IBOutlet weak var theAddress: UITextField!
    @IBOutlet weak var theAddressLabel: UILabel!
    @IBOutlet weak var theAddressFirstLine: UILabel!
    @IBOutlet weak var theContext: UITextView!
    @IBOutlet weak var theContextLabel: UILabel!
    @IBOutlet weak var theNextContext: UIButton!
    @IBOutlet weak var theMapcode: UITextView!
    @IBOutlet weak var theMapcodeLabel: UILabel!
    @IBOutlet weak var theNextMapcode: UIButton!
    @IBOutlet weak var theLat: UITextField!
    @IBOutlet weak var theLon: UITextField!
    @IBOutlet weak var theLatLabel: UILabel!
    @IBOutlet weak var theLonLabel: UILabel!
    @IBOutlet weak var theView: UIView!
    @IBOutlet weak var keyboardHeightLayoutConstraint: NSLayoutConstraint!

    //@formatter:off

    /**
     * Constants.
     */

    // Current debug messages mask.
    let debugMask: UInt8 = 0x00
    let TRACE: UInt8 = 1
    let DEBUG: UInt8 = 2
    let INFO: UInt8 = 4
    let WARN: UInt8 = 8
    let ERROR: UInt8 = 16

    // Help texts.
    let textWhatsNew = "\n" +
        "* Compatible with older iOS 8.1+.\n" +
        "* Added iOS Share button.\n" +
        "* Fixed issues with address formatting.\n"

    let textAbout = "Copyright (C) 2016\n" +
        "Rijn Buve, Mapcode Foundation\n\n" +

        "Welcome the official Mapcode App from the Mapcode Foundation!\n\n" +

        "Enter an address or coordinate to get a mapcode, or move the map around. " +
        "Tap twice to zoom in really deep.\n\n" +

        "Enter a mapcode in the address field to show it on the map. Tip: if you omit " +
        "the territory for local mapcodes, the current territory is used.\n\n" +

        "Tap the Next buttons to show next territory or mapcode. " +
        "Tap the mapcode itself to copy it to the clipboard.\n\n" +

        "Tap on the Maps icon to plan a route to it using the Maps app.\n\n" +

        "Note that a single location can have mapcodes with different territory codes. " +
        "The 'correct' territory is always included, but other territories may be presented as well. " +
        "You can select correct territory by tapping on the Next button.\n\n" +

        "For questions, or more info on mapcodes in general, please visit us at: http://mapcode.com\n\n" +

        "Finally, a big thanks to our many beta-testers who have provided invaluable " +
        "feedback during the development of this product!\n\n" +

        "________\n" +

        "Privacy notice: " +
        "This app uses the Mapcode REST API at https://api.mapcode.com. " +
        "This free online service is provided for demonstration purposes " +
        "only and the Mapcode Foundation accepts no claims " +
        "on its availability or reliability, although we try hard to " +
        "provide a stable and decent service. Note that anonymized " +
        "usage and log data, including mapcodes and coordinates, may " +
        "be collected to improve the service and better anticipate " +
        "on its scalability needs. The collected data contains no IP " +
        "addresses, is processed securely in the EEA and is never " +
        "sold or used for commercial purposes."

    // Other constants.
    let host: String = "https:/api.mapcode.com";    // Host name of Mapcode REST API.
    let allowLog: String = "true";                  // API: Allow logging requests.
    let client: String = "ios";                     // API: Client ID.

    let tagTextFieldAddress = 1                     // Tags of text fields.
    let tagTextFieldLatitude = 2
    let tagTextFieldLongitude = 3

    let mapcodeTerritoryFont = "HelveticaNeue"      // Font definitions.
    let mapcodeCodeFont = "HelveticaNeue-Bold"
    let mapcodeInternationalFont = "HelveticaNeue-Bold"
    let contextFont = "HelveticaNeue-Medium"
    let mapcodeTerritoryFontSize: CGFloat = 12.0;
    let mapcodeCodeFontSize: CGFloat = 16.0;
    let mapcodeCodeFontSizeSmall: CGFloat = 12.0;
    let mapcodeInternationalFontSize: CGFloat = 16.0;
    let contextFontSize: CGFloat = 16.0;
    let mapcodeFontKern = 0.65

    let colorMapcode = UIColor.blackColor()         // Colors of mapcode and its territory prefix.
    let colorTerritoryPrefix = UIColor(hue: 0.6, saturation: 0.7, brightness: 0.5, alpha: 1.0)

    let colorWaitingForUpdate = UIColor.lightGrayColor()    // Color for 'outdated' fields, waiting for update.
    let colorLabelNormal = UIColor.blackColor()             // Normal label.
    let colorLabelAlert = UIColor.redColor()                // Alert message.
    let colorLabelCopiedToClipboard = UIColor(hue: 0.35, saturation: 0.8, brightness: 0.6, alpha: 1.0)

    let zoomFactor = 2.5                            // Factor for zoom in/out.

    let metersPerDegreeLat          = (6378137.0 * 2.0 * 3.141592654) / 360.0
    let metersPerDegreeLonAtEquator = (6356752.3 * 2.0 * 3.141592654) / 360.0

    let spanInit = 8.0                              // Initial zoom, "country level".
    let spanZoomedIn = 0.003                        // Zoomed in, after double tap.
    let spanZoomedInMax = 0.0005                    // Zoomed in max.
    let spanZoomedOutMax = 175.0                    // Zoomed out max.

    var locationManager: CLLocationManager!         // Controls and receives location updates.

    let scheduleUpdateLocationsSecs = 300.0         // Switch on update locations every x secs.
    let distanceFilterMeters = 10000.0              // Not interested in local position updates.

    let limitReverseGeocodingSecs = 1.0             // Limit webservice API's to no
    let limitMapcodeLookupSecs = 1.0                // more than x requests per second.

    let mapcodeRegex = try! NSRegularExpression(    // Pattern to match mapcodes: XXx[-XXx] XXxxx.XXxx[-Xxxxxxxx]

        // _______START_[' ']XXx____________________[___-_XXx______________________]' '___XXxxx____________.__XXxx___________[___-_Xxxxxxxx_________][' ']END
        pattern: "\\A\\s*(?:[a-zA-Z][a-zA-Z0-9]{1,2}(?:[-][a-zA-Z][a-zA-Z0-9]{1,2})?\\s+)?[a-zA-Z0-9]{2,5}[.][a-zA-Z0-9]{2,4}(?:[-][a-zA-Z0-9]{1,8})?\\s*\\Z",
        options: [])

    let keyVersionBuild = "versionBuild"            // Version and build (for what's new).

    let territoryInternationalAlphaCode = "AAA"     // Territory code for international context.
    let territoryInternationalFullName = "Earth"    // Territory full name for international context.

    let alphaEnabled: CGFloat = 1.0                 // Transparency of enabled button.
    let alphaDisabled: CGFloat = 0.5                // Transparency of disabled button.

    let resetLabelsAfterSecs = 5.0                  // Reset coordinate labels after copy to clipboard.
    let keyboardMinimumDistance: CGFloat = 4.0      // Default distance to bottom.

    var movementDistanceAddress: CGFloat = 0.0              // Distance to move screen up/down when typing.
    var movementDistanceCoordinate: CGFloat = 0.0           // These vars should be considered constants.
    let iPhoneMovementDistanceAddress: CGFloat = 125.0      // The movement distance is set once to either
    let iPhoneMovementDistanceCoordinate: CGFloat = 250.0   // iPhone or iPad movement.
    let iPadMovementDistanceAddress: CGFloat = 270.0
    let iPadMovementDistanceCoordinate: CGFloat = 400.0

    // Texts in dialogs.
    let textNoTerritoriesFound = "No territories found"
    let textLoadingTerritories = "Loading territories..."
    let textNoInternet = "No internet connection?"

    // Labels.
    let textTerritorySingle = "TERRITORY"
    let textTerritoryXOfY = "TERRITORY %i OF %i"
    let textMapcodeSingle = "MAPCODE"
    let textMapcodeFirstOfN = "MAPCODE (+%i ALT.)"
    let textMapcodeXOfY = "ALTERNATIVE %i"
    let textLatLabel = "LATITUDE (Y)"
    let textLonLabel = "LONGITUDE (X)"
    let textCopiedToClipboard = "COPIED TO CLIPBOARD"
    let textAddressLabel = "ENTER ADDRESS OR MAPCODE"
    let textWrongAddress = "CANNOT FIND: "
    let textWrongMapcode = "INCORRECT MAPCODE: "

    // Special mapcodes.
    let longestMapcode = "MX-GRO MWWW.WWWW"
    let mostMapcodesCoordinate = CLLocationCoordinate2D(latitude: 52.0505, longitude: 113.4686)
    let mostMapcodesCoordinateCount = 21

    /**
     * Global state.
     */

    // Provide a sensible screen if no user location is available (rather than mid Pacific).
    var mapcodeLocation = CLLocationCoordinate2D(latitude: 52.373293, longitude: 4.893718)

    var waitingForFirstLocationSinceStarted = true  // First location is different: auto-move to it.
    var moveMapToUserLocation = false               // True if map should auto-move to user location.

    var undoTextFieldEdit: String!                  // Undo edits if something went wrong.
    var mapChangedFromUserInteraction = false       // True if map was panned by user, rather than auto-move.

    var allMapcodes = [String]()                    // List of all mapcodes for current location (cannot be empty).
    var currentMapcodeIndex = 0                     // Index of current alternative; 0 = shortest, last = int'l.

    var allContexts = [String]()                    // List of all contexts for current location (can be empty).
    var currentContextIndex = 0                     // Index of current context.

    var territoryFullNames = [String: String]()     // List of territory alpha codes and full names. Can be empty.

    var queuedCoordinateForReverseGeocode: CLLocationCoordinate2D!  // Queue of 1, for periodic rev. geocoding. Nil if none.
    var queuedCoordinateForMapcodeLookup: CLLocationCoordinate2D!   // Queue of 1, for mapcode lookup. Nil if none.

    var prevQueuedCoordinateForReverseGeocode: CLLocationCoordinate2D!  // Keep previous one, to skip new one if we can.
    var prevQueuedCoordinateForMapcodeLookup: CLLocationCoordinate2D!   // Ditto.

    var prevTimeForReverseGeocodeSecs: NSTimeInterval = 0.0   // Last time a request was made, to limit number of requests
    var prevTimeForMapcodeLookupSecs: NSTimeInterval = 0.0    // but react immediately after time of inactivity.

    var timerReverseGeocoding = NSTimer()           // Timer to schedule/limit reverse geocoding.
    var timerLocationUpdates = NSTimer()            // Timer to schedule/limit location updates.
    var timerResetLabels = NSTimer()                // Timer to reset labels.

    // @formatter:on

    /**
     * Errors that may be thrown when talking to an API.
     */

    enum ApiError: ErrorType {
        case ApiReturnsErrors(json:JSONValue!)
        case ApiUnexpectedMessageFormat(json:JSONValue!)
    }


    /**
     * This method gets called when the view loads. It is called exactly once.
     */
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup our Map View.
        theMap.delegate = self
        theMap.mapType = MKMapType.Standard
        theMap.showsUserLocation = true
        theMap.showsBuildings = true

        // Map scale only on iOS 9.0+.
        if #available(iOS 9.0, *) {
            theMap.showsScale = true
        }

        // Set initial map and zoom. Pick a decent location to start with until a real location is found.
        let newRegion = MKCoordinateRegion(center: mapcodeLocation,
                                           span: MKCoordinateSpanMake(spanInit, spanInit))
        theMap.setRegion(newRegion, animated: false)

        // Setup up delegates for text input boxes, so events are handled.
        theAddress.delegate = self
        theLat.delegate = self
        theLon.delegate = self

        // Set text fields.
        theAddressFirstLine.text = ""
        theAddress.text = ""
        theContext.text = ""
        theContextLabel.text = "TERRITORY"
        theNextContext.enabled = false
        theMapcode.text = ""
        theMapcodeLabel.text = "SHORTEST"
        theNextMapcode.enabled = false
        theLat.text = ""
        theLon.text = ""

        // Work-around to move screen sufficiently high on iPad.
        if UIDevice().model.containsString("iPad") {
            movementDistanceAddress = iPadMovementDistanceAddress
            movementDistanceCoordinate = iPadMovementDistanceCoordinate
        } else {
            movementDistanceAddress = iPhoneMovementDistanceAddress
            movementDistanceCoordinate = iPhoneMovementDistanceCoordinate
        }

        // Recognize 1 or 2 taps on map.
        let tapMap1 = UITapGestureRecognizer(target: self, action: #selector(handleMapTap1))
        theMap.addGestureRecognizer(tapMap1)

        let tapMap2 = UITapGestureRecognizer(target: self, action: #selector(handleMapTap2))
        tapMap2.numberOfTapsRequired = 2
        theMap.addGestureRecognizer(tapMap2)

        // Recognize 1 tap on mapcode.
        let tapMapcode = UITapGestureRecognizer(target: self, action: #selector(handleCopyMapcodeTap))
        theMapcode.addGestureRecognizer(tapMapcode)

        // Recognize 1 tap on latitude.
        let tapLatitude = UITapGestureRecognizer(target: self, action: #selector(handleCopyLatitudeTap))
        theLatLabel.addGestureRecognizer(tapLatitude)

        // Recognize 1 tap on longitude.
        let tapLongitude = UITapGestureRecognizer(target: self, action: #selector(handleCopyLongitudeTap))
        theLonLabel.addGestureRecognizer(tapLongitude)

        // Recognize 1 tap on context, context label and mapcode label
        let tapContextLabel = UITapGestureRecognizer(target: self, action: #selector(handleNextContextTap))
        theContextLabel.addGestureRecognizer(tapContextLabel)
        let tapContext = UITapGestureRecognizer(target: self, action: #selector(handleNextContextTap))
        theContext.addGestureRecognizer(tapContext)
        let tapMapcodeLabel = UITapGestureRecognizer(target: self, action: #selector(handleNextMapcodeTap))
        theMapcodeLabel.addGestureRecognizer(tapMapcodeLabel)

        // Subscribe to notification of keyboard show/hide.
        NSNotificationCenter.defaultCenter().addObserver(self,
                                                         selector: #selector(self.keyboardNotification(_:)),
                                                         name: UIKeyboardWillChangeFrameNotification,
                                                         object: nil)

        // Setup our Location Manager. Only 1 location update is requested when the user presses
        // the "Find My Location" button. Updates are switched off immediately after that. Only
        // once every couple of minutes it is switched on for a single event again (or finding your
        // position would take longer or be less accurate). The large distance filter causes the
        // code not be called for local udpates, as that might lead to more REST calls.
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = distanceFilterMeters
        locationManager.requestWhenInUseAuthorization()     // Ask for permission - may show dialog.
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
     * This gets called when the controlled is exited.
     */
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }


    /**
     * This method gets called whenever the keyboard is about to show/hide. Nice solution from:
     * http://stackoverflow.com/questions/25693130/move-textfield-when-keyboard-appears-swift
     */
    func keyboardNotification(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            let endFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.CGRectValue()
            let duration: NSTimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
            let animationCurveRawNumber = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber
            let animationCurveRaw = animationCurveRawNumber?.unsignedLongValue ?? UIViewAnimationOptions.CurveEaseInOut.rawValue
            let animationCurve: UIViewAnimationOptions = UIViewAnimationOptions(rawValue: animationCurveRaw)
            if endFrame?.origin.y >= UIScreen.mainScreen().bounds.size.height {
                self.keyboardHeightLayoutConstraint?.constant = keyboardMinimumDistance
            } else {
                self.keyboardHeightLayoutConstraint?.constant = endFrame?.size.height ?? keyboardMinimumDistance
            }
            UIView.animateWithDuration(duration,
                                       delay: NSTimeInterval(0),
                                       options: animationCurve,
                                       animations: { self.view.layoutIfNeeded() },
                                       completion: nil)
        }
    }


    /**
     * This method gets called when the view is displayed.
     */
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        // Show initial what's new dialog (if this is a new version).
        showStartUpText()
    }


    /**
     * This method presents the 'What's new" box.
     */
    func showStartUpText() {
        let version = NSBundle.mainBundle().infoDictionary!["CFBundleShortVersionString"] as! String
        let build = NSBundle.mainBundle().infoDictionary!["CFBundleVersion"] as! String
        let versionBuild = "\(version)\(build)"

        let defaults = NSUserDefaults.standardUserDefaults()
        let prevVersionBuild = defaults.stringForKey(keyVersionBuild)

        // Update settings.
        defaults.setValue(versionBuild, forKey: keyVersionBuild)
        defaults.synchronize()

        // Check if the app was updated.
        if prevVersionBuild == nil {
            self.showAbout(self)
        } else if prevVersionBuild != versionBuild {
            self.showAlert("What's New", message: "\(version):" + textWhatsNew, button: "Dismiss")
        }
    }


    /**
     * This method gets called when the "info" icon is pressed.
     */
    @IBAction func showAbout(sender: AnyObject) {
        let version = NSBundle.mainBundle().infoDictionary!["CFBundleShortVersionString"] as! String
        let build = NSBundle.mainBundle().infoDictionary!["CFBundleVersion"] as! String
        self.showAlert("Mapcode \(version).\(build)", message: textAbout, button: "Dismiss")
    }


    /**
     * This gets called if the "share" button gets pressed.
     */
    @IBAction func shareButtonClicked(sender: UIButton) {
        let textToShare = theMapcode.text
        let objectsToShare = [textToShare]
        let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
        activityVC.excludedActivityTypes = [UIActivityTypeAirDrop, UIActivityTypeAddToReadingList]
        activityVC.popoverPresentationController?.sourceView = sender
        self.presentViewController(activityVC, animated: true, completion: nil)
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
        } else {
            // Fields were already updated, this map movement is a result of that.
        }
    }


    /**
     * Gesture recognizer: this method gets called when the user taps the map once.
     */
    func handleMapTap1(gestureRecognizer: UITapGestureRecognizer) {

        // Resign keyboard form text field when user taps map.
        self.view.endEditing(true)

        // Don't auto-zoom to user location anymore.
        waitingForFirstLocationSinceStarted = false

        // Get location of tap.
        let location = gestureRecognizer.locationInView(theMap)
        mapcodeLocation = theMap.convertPoint(location, toCoordinateFromView: theMap)

        // Set map center and update fields. Do not limit zoom level.
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
                                           span: MKCoordinateSpanMake(spanZoomedIn, spanZoomedIn))
        theMap.setRegion(newRegion, animated: true)
    }


    /**
     * Gesture recognizer: this method gets called when the user taps the mapcode.
     */
    func handleCopyMapcodeTap(gestureRecognizer: UITapGestureRecognizer) {
        UIPasteboard.generalPasteboard().string = theMapcode.text
        theMapcodeLabel.textColor = colorLabelCopiedToClipboard
        theMapcodeLabel.text = textCopiedToClipboard
        scheduleResetLabels()
    }


    /**
     * Gesture recognizer: this method gets called when the user taps the latitude.
     */
    func handleCopyLatitudeTap(gestureRecognizer: UITapGestureRecognizer) {
        // Resign keyboard form text field when user taps map.
        self.view.endEditing(true)

        UIPasteboard.generalPasteboard().string = theLat.text
        theLatLabel.textColor = colorLabelCopiedToClipboard
        theLatLabel.text = textCopiedToClipboard
        scheduleResetLabels()
    }


    /**
     * Gesture recognizer: this method gets called when the user taps the longitude.
     */
    func handleCopyLongitudeTap(gestureRecognizer: UITapGestureRecognizer) {
        // Resign keyboard form text field when user taps map.
        self.view.endEditing(true)

        UIPasteboard.generalPasteboard().string = theLon.text
        theLonLabel.textColor = colorLabelCopiedToClipboard
        theLonLabel.text = textCopiedToClipboard
        scheduleResetLabels()
    }


    /**
     * This method schedules a reset of the labels.
     */
    func scheduleResetLabels() {
        timerResetLabels.invalidate()
        timerResetLabels = NSTimer.scheduledTimerWithTimeInterval(
                resetLabelsAfterSecs, target: self,
                selector: #selector(ResetLabels),
                userInfo: nil, repeats: false)
    }


    /**
     * This method reset the latitude and longitude labels to their default values.
     */
    func ResetLabels() {

        // Update coordinate labels.
        theAddressLabel.textColor = colorLabelNormal
        theAddressLabel.text = textAddressLabel
        theLatLabel.textColor = colorLabelNormal
        theLatLabel.text = textLatLabel
        theLonLabel.textColor = colorLabelNormal
        theLonLabel.text = textLonLabel

        // Update mapcode label.
        updateMapcodeLabel()
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
     * This method gets called when user starts editing a text field. Keep the previous
     * value for undo. Careful though: the undo text is shared for all fields.
     */
    @IBAction func beginEdit(textField: UITextField) {
        dispatch_async(dispatch_get_main_queue()) {
            self.undoTextFieldEdit = textField.text
            textField.selectAll(self)
        }
    }


    /**
     * This method gets called when user starts editing the address field. This needs to
     * clear the first address line as well.
     */
    @IBAction func beginEditAddress(textField: UITextField) {
        dispatch_async(dispatch_get_main_queue()) {
            self.theAddressFirstLine.text = ""
        }
        beginEdit(textField)
    }

    
    /**
     * Delegate method gets called when the Return key is pressed in a text edit field.
     */
    func textFieldShouldReturn(textField: UITextField) -> Bool {

        // Hide keyboard.
        self.view.endEditing(true)

        // Do not process empty fields.
        if (textField.text == nil) || (textField.text?.isEmpty)! {
            // Restore contents of field.
            textField.text = undoTextFieldEdit
            return false
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
            } else {
                debug(DEBUG, msg: "textFieldShouldReturn: Entered address, address=\(theAddress.text!)")
                addressWasEntered(theAddress.text!)
            }

        case theLat.tag:

            // Check if we can actually convert this to a double.
            if Double(theLat.text!) != nil {
                coordinateWasEntered(theLat.text!, longitude: theLon.text!)
            } else {
                theLat.text = undoTextFieldEdit
            }

        case theLon.tag:

            // Check if we can actually convert this to a double.
            if Double(theLon.text!) != nil {
                coordinateWasEntered(theLat.text!, longitude: theLon.text!)
            } else {
                theLon.text = undoTextFieldEdit
            }

        default:
            debug(ERROR, msg: "textFieldShouldReturn: Unknown text field, tag=\(textField.tag)")
        }
        return false
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
                    self.theAddressLabel.textColor = self.colorLabelAlert
                    self.theAddressLabel.text = "\(self.textWrongAddress) \(address.uppercaseString)"

                    // Force call to reset address field; need to do a new reverse geocode as previous text is lost.
                    self.prevQueuedCoordinateForReverseGeocode = nil
                    self.queueUpdateForAddress(self.mapcodeLocation)

                    // Reset error label after some time.
                    self.scheduleResetLabels()
                }
            } else {
                // Found location; determine coordinate and proper zoom level.
                let first = (placemarks?.first)!
                let coordinate = first.location!.coordinate
                let region = first.region as! CLCircularRegion

                // Add 50% slack around the edges.
                let spanLat = min(self.spanZoomedOutMax,
                                  max(self.spanZoomedInMax,
                                      1.5 * region.radius / self.metersPerDegreeLat))
                let spanLon = min(self.spanZoomedOutMax,
                                  max(self.spanZoomedInMax,
                                      1.5 * region.radius / self.metersPerDegreeLonAtLan(coordinate.latitude)))

                dispatch_async(dispatch_get_main_queue()) {
                    // Update location.
                    self.mapcodeLocation = coordinate
                    let newRegion = MKCoordinateRegion(center: coordinate,
                                                       span: MKCoordinateSpanMake(spanLat, spanLon))
                    self.theMap.setRegion(newRegion, animated: false)
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
        var fullMapcode = trimAllSpace(mapcode)

        if (fullMapcode.characters.count < 10) && !fullMapcode.containsString(" ") && !allContexts.isEmpty {
            fullMapcode = "\(allContexts[currentContextIndex]) \(fullMapcode)"
        }

        // Create URL for REST API call to get mapcodes.
        let encodedMapcode = fullMapcode.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
        let url = "\(host)/mapcode/coords/\(encodedMapcode)?client=\(client)&allowLog=\(allowLog)"
        guard let rest = RestController.createFromURLString(url) else {
            debug(ERROR, msg: "mapcodeWasEntered: Bad URL, url=\(url)")
            return
        }

        // Get coordinate.
        debug(INFO, msg: "mapcodeWasEntered: Call Mapcode API: url=\(url)")
        rest.get {
            result, httpResponse in
            do {
                let json = try result.value()

                let status = httpResponse?.statusCode
                if (status != 200) || (json["errors"] != nil) {
                    self.debug(self.INFO, msg: "mapcodeWasEntered: Incorrect mapcode=\(mapcode)")
                    dispatch_async(dispatch_get_main_queue()) {
                        // Show error in label.
                        self.theAddressLabel.textColor = self.colorLabelAlert
                        self.theAddressLabel.text = "\(self.textWrongMapcode) \(mapcode.uppercaseString)"

                        // Reset error label after some time.
                        self.scheduleResetLabels()
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
                        self.setMapCenterAndLimitZoom(coordinate, maxSpan: self.spanZoomedIn, animated: false)
                        self.showLatLon(coordinate)
                        self.queueUpdateForMapcode(coordinate)

                        // Force call.
                        self.prevQueuedCoordinateForReverseGeocode = nil
                        self.queueUpdateForAddress(coordinate)
                    }
                } else {
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
                dispatch_async(dispatch_get_main_queue()) {
                    // Reset to backup.
                    self.prevQueuedCoordinateForMapcodeLookup = nil
                    self.prevQueuedCoordinateForReverseGeocode = nil
                    self.queuedCoordinateForMapcodeLookup = self.mapcodeLocation
                    self.queuedCoordinateForReverseGeocode = self.mapcodeLocation
                    self.theAddress.text = self.textNoInternet
                }
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
            setMapCenterAndLimitZoom(mapcodeLocation, maxSpan: spanZoomedIn, animated: false)
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
        debug(INFO, msg: "fetchTerritoryNamesFromServer: Call Mapcode API: url=\(url)")
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
    @IBAction func findMyLocation(sender: AnyObject) {

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
        region.span.latitudeDelta = max(spanZoomedInMax, lat)
        region.span.longitudeDelta = max(spanZoomedInMax, lon)
        theMap.setRegion(region, animated: true)
    }


    /**
     * This method gets called when the "zoom out" icon is pressed.
     */
    @IBAction func zoomOut(sender: AnyObject) {
        var region = theMap.region
        let lat = region.span.latitudeDelta * zoomFactor
        let lon = region.span.longitudeDelta * zoomFactor
        region.span.latitudeDelta = min(spanZoomedOutMax, lat)
        region.span.longitudeDelta = min(spanZoomedOutMax, lon)
        theMap.setRegion(region, animated: true)
    }


    /**
     * This method gets called when the user taps the context label, which means: next item.
     */
    func handleNextContextTap(gestureRecognizer: UITapGestureRecognizer) {

        // Resign keyboard form text field when user taps map.
        self.view.endEditing(true)

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
        } else {
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
    func handleNextMapcodeTap(gestureRecognizer: UITapGestureRecognizer) {

        // Resign keyboard form text field when user taps map.
        self.view.endEditing(true)

        nextMapcode(self)
    }


    /**
     * This method gets called when the "toggle mapcode" button is pressed.
     */
    @IBAction func nextMapcode(sender: AnyObject) {

        // Move to next alternative next time we press the button.
        currentMapcodeIndex += 1

        // Show current mapcode, no need to update context field.
        updateMapcode()
    }


    /**
     * This method returns an array of all mapcodes for a specific territory.
     */
    func getMapcodesForTerritory(territory: String!) -> [String] {
        var selection = [String]()
        for m in allMapcodes {
            // Add the code if the territory is OK, or the context is international and
            // it's the international code.
            if m.containsString("\(territory) ") ||
                    ((territory == nil) && !m.containsString(" ")) {
                selection.append(m)
            }
        }
        return selection
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
        var selection = getMapcodesForTerritory(context)

        // Limit index to a place in this list.
        let count = selection.count
        if currentMapcodeIndex >= count {
            currentMapcodeIndex = 0
        }

        // Get the mapcode from this selection.
        let mapcode = selection[currentMapcodeIndex]

        // Set the mapcode text.
        let attributedText = NSMutableAttributedString(string: mapcode)

        // Set defaults.
        let fullRange = NSMakeRange(0, mapcode.characters.startIndex.distanceTo(mapcode.characters.endIndex))

        // Set color of mapcode itself.
        attributedText.addAttributes([NSForegroundColorAttributeName: colorMapcode], range: fullRange)

        // Set font size, reduce size for really large mapcodes.
        var fontSize = mapcodeCodeFontSize
        if mapcode.characters.count >= longestMapcode.characters.count {
            fontSize = mapcodeCodeFontSizeSmall
        }
        attributedText.addAttributes([NSFontAttributeName: UIFont(name: mapcodeCodeFont, size: fontSize)!], range: fullRange)
        attributedText.addAttributes([NSKernAttributeName: mapcodeFontKern], range: fullRange)

        // If the code has a territory, make it look different.
        let index = mapcode.characters.indexOf(Character(" "))
        if index != nil {
            let n = mapcode.characters.startIndex.distanceTo(index!)
            attributedText.addAttributes([NSForegroundColorAttributeName: colorTerritoryPrefix], range: NSMakeRange(0, n))
            attributedText.addAttributes([NSFontAttributeName: UIFont(name: mapcodeTerritoryFont, size: mapcodeTerritoryFontSize)!], range: NSMakeRange(0, n))
        } else {
            // If the code has no territory, it is the international code.
            attributedText.addAttributes([NSFontAttributeName: UIFont(name: mapcodeInternationalFont, size: mapcodeInternationalFontSize)!], range: fullRange)
        }
        theMapcode.attributedText = attributedText
        updateMapcodeLabel()
    }


    /**
     * This method updates the mapcode label text.
     */
    func updateMapcodeLabel() {

        // Set the label color.
        theMapcodeLabel.textColor = colorLabelNormal

        // Set the mapcode label text. There's always a mapcode.
        let count = getMapcodesForTerritory(allContexts[currentContextIndex]).count
        if count <= 1 {
            theNextMapcode.enabled = false
            theNextMapcode.alpha = alphaDisabled
            theMapcodeLabel.text = textMapcodeSingle
        } else {
            theNextMapcode.enabled = true
            theNextMapcode.alpha = alphaEnabled
            if currentMapcodeIndex == 0 {
                theMapcodeLabel.text = String(format: textMapcodeFirstOfN, count - 1)
            } else {
                theMapcodeLabel.text = String(format: textMapcodeXOfY, currentMapcodeIndex, count - 1)
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
        theContext.attributedText = attributedText

        // Set the mapcode label text. There's always a context.
        if allContexts.count == 1 {
            theNextContext.enabled = false
            theNextContext.alpha = alphaDisabled
            theContextLabel.text = textTerritorySingle
        } else {
            theNextContext.enabled = true
            theNextContext.alpha = alphaEnabled
            theContextLabel.text = String(format: textTerritoryXOfY, currentContextIndex + 1, allContexts.count)
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
            debug(TRACE, msg: "periodicCheckToUpdateAddress: Filtered (no change), coordinate=\(queuedCoordinateForReverseGeocode)")
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
            debug(TRACE, msg: "periodicCheckToUpdateAddress: Filtered (too soon), timePassed=\(timePassed)")
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
                let pm = placemarks!.first!

                // Get address from formatted address lines. First line seems to be neighborhood or POI sometimes, however.
                var address = ""
                var addressFirstLine = ""
                if let lines = pm.addressDictionary!["FormattedAddressLines"] as! [String]! {
                    var start = 0
                    if lines.count > 3 {
                        addressFirstLine = lines.first!
                        start = 1
                    }
                    address = lines[start]
                    for line in lines.dropFirst(start + 1) {
                        address = address + "\n" + line
                    }
                    address = address.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).stringByReplacingOccurrencesOfString("\n", withString: ", ")
                }

                // Update address fields.
                dispatch_async(dispatch_get_main_queue()) {
                    self.theAddressFirstLine.text = addressFirstLine
                    self.theAddress.textColor = UIColor.blackColor()
                    self.theAddress.text = address
                }
            } else {
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
            debug(TRACE, msg: "periodicCheckToUpdateMapcode: Filtered (no change), coordinate=\(queuedCoordinateForMapcodeLookup)")
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
            debug(TRACE, msg: "periodicCheckToUpdateMapcode: Too soon, timePassed=\(timePassed)")
            return
        }

        // Update last time stamp and previous request.
        prevTimeForMapcodeLookupSecs = now
        prevQueuedCoordinateForMapcodeLookup = queuedCoordinateForMapcodeLookup

        // Keep the coordinate local.
        let coordinate = queuedCoordinateForMapcodeLookup

        // Clear the request, keep a backup when an error occurs.
        queuedCoordinateForMapcodeLookup = nil

        // Create URL for REST API call to get mapcodes, URL-encode lat/lon.
        let encodedLatLon = "\(coordinate.latitude),\(coordinate.longitude)".stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
        let url = "\(host)/mapcode/codes/\(encodedLatLon)?client=\(client)&allowLog=\(allowLog)"

        guard let rest = RestController.createFromURLString(url) else {
            debug(ERROR, msg: "periodicCheckToUpdateMapcode: Bad URL, url=\(url)")
            return
        }

        // Get mapcodes from REST API.
        debug(INFO, msg: "periodicCheckToUpdateMapcode: Call Mapcode API: url=\(url)")
        rest.get {
            result, httpResponse in
            do {
                // Get JSON response.
                let json = try result.value()

                // The JSON response indicated an error, territory is set to nil.
                if json["errors"] != nil {
                    throw ApiError.ApiReturnsErrors(json: json["errors"])
                }

                // Get international mapcode (must exist).
                if (json["international"] == nil) || (json["international"]?["mapcode"] == nil) {
                    throw ApiError.ApiUnexpectedMessageFormat(json: json.jsonValue)
                }
                let mapcodeInternational = (json["international"]?["mapcode"]?.stringValue)!


                // Get shortest local mapcode (optional).
                var mapcodeLocal = ""
                var territoryLocal = ""
                if json["local"] != nil {
                    if (json["local"]?["territory"] == nil) || (json["local"]?["mapcode"] == nil) {
                        throw ApiError.ApiUnexpectedMessageFormat(json: json["local"])
                    }
                    territoryLocal = (json["local"]?["territory"]?.stringValue)!
                    mapcodeLocal = (json["local"]?["mapcode"]?.stringValue)!
                }

                // Try to match existing context with 1 from the new list.
                var prevContext: String!
                if !self.allContexts.isEmpty {
                    prevContext = self.allContexts[self.currentContextIndex]
                }

                // The new index; nil means: no matching territory found yet.
                var newContextIndex: Int!

                // Create a new list of mapcodes and contexts.
                var newAllMapcodes = [String]()
                var newAllContexts = [String]()

                // Get list of all mapcodes (must exist and must contain at least the international mapcode).
                if (json["mapcodes"] == nil) || (json["mapcodes"]?.jsonArray == nil) {
                    throw ApiError.ApiUnexpectedMessageFormat(json: json.jsonValue)
                }

                // Store the list of mapcodes (must include the international mapcode).
                let alt = (json["mapcodes"]?.jsonArray)!
                if alt.count == 0 {
                    throw ApiError.ApiUnexpectedMessageFormat(json: json["mapcodes"])
                }

                // If there are other mapcodes besides the international one, process them.
                if alt.count >= 2 {
                    // Add the shortest one at front (which only exists if there are 2+ mapcodes).
                    newAllMapcodes.append("\(territoryLocal) \(mapcodeLocal)")
                    newAllContexts.append(territoryLocal)
                    if (prevContext != nil) && (prevContext == territoryLocal) {
                        newContextIndex = 0
                    }

                    // Add the alternatives, NOT including the international (which is last and has no territory).
                    for i in 0 ... alt.count - 2 {
                        // Create the full mapcode.
                        let territory = (alt[i]!["territory"]?.stringValue)!
                        let mapcode = (alt[i]!["mapcode"]?.stringValue)!

                        // Don't add the already added local mapcode (or its territory).
                        if (territory != territoryLocal) || (mapcode != mapcodeLocal) {
                            newAllMapcodes.append("\(territory) \(mapcode)")

                            // Keep the territories (no doubles).
                            if (!newAllContexts.contains(territory)) {
                                newAllContexts.append(territory)

                                // Update the new index only if it didn't have a value yet.
                                if (newContextIndex == nil) && (prevContext != nil) && (prevContext == territory) {
                                    newContextIndex = newAllContexts.count - 1
                                }
                            }
                        }
                    }
                }

                // Special case: Always append the international mapcode and context at the end. 
                // Do NOT match the previous context - we rather have it snap to something else than international.
                newAllContexts.append(self.territoryInternationalAlphaCode)
                newAllMapcodes.append(mapcodeInternational)

                // Now, if we still didn't find a matching territory, fall back to the first one.
                if newContextIndex == nil {
                    newContextIndex = 0
                }

                // Update mapcode fields on main thread.
                dispatch_async(dispatch_get_main_queue()) {
                    self.allContexts = newAllContexts
                    self.currentContextIndex = newContextIndex
                    self.allMapcodes = newAllMapcodes
                    self.currentMapcodeIndex = 0
                    self.updateContext()
                    self.updateMapcode()
                }
            } catch {
                self.debug(self.WARN, msg: "periodicCheckToUpdateMapcode: API call failed, url=\(url), error=\(error)")
                dispatch_async(dispatch_get_main_queue()) {
                    // Reset to backup.
                    self.prevQueuedCoordinateForMapcodeLookup = nil
                    self.prevQueuedCoordinateForReverseGeocode = nil
                    self.queuedCoordinateForMapcodeLookup = coordinate
                    self.queuedCoordinateForReverseGeocode = coordinate
                    self.theAddress.text = self.textNoInternet
                }
            }
        }
    }


    /**
     * This method gets called whenever a location change is detected.
     */
    func locationManager(locationManager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {

        // Get new location.
        let newLocation = locations[0].coordinate

        // Set default span.
        var span = spanZoomedIn

        // If it's a valid coordinate and we need to auto-move or it's the first location, move.
        if isValidCoordinate(newLocation) {
            if waitingForFirstLocationSinceStarted || moveMapToUserLocation {
                // Update location.
                mapcodeLocation = newLocation;

                // First time location ever? Override map zoom.
                if waitingForFirstLocationSinceStarted {
                    span = spanInit
                    waitingForFirstLocationSinceStarted = false
                }
                moveMapToUserLocation = false

                // Change zoom level, pretty much zoomed out.
                let newRegion = MKCoordinateRegion(center: mapcodeLocation,
                                                   span: MKCoordinateSpanMake(span, span))

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
        if allow! {
            theFindMyLocation.enabled = true
            theFindMyLocation.alpha = alphaEnabled
        } else {
            theFindMyLocation.enabled = false
            theFindMyLocation.alpha = alphaDisabled
        }
    }


    /**
     * This method gets called when the "open in maps" icon is pressed.
     */
    @IBAction func openInMapsApplication(sender: AnyObject) {
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
     * This method sets the center of the map and makes sure the zoom-level is limited if necessary.
     */
    func setMapCenterAndLimitZoom(center: CLLocationCoordinate2D, maxSpan: Double, animated: Bool) {
        if (theMap.region.span.latitudeDelta >= maxSpan) || (theMap.region.span.longitudeDelta >= maxSpan) {
            let newRegion = MKCoordinateRegion(center: mapcodeLocation,
                                               span: MKCoordinateSpanMake(maxSpan, maxSpan))
            theMap.setRegion(newRegion, animated: animated)
        } else {
            theMap.setCenterCoordinate(mapcodeLocation, animated: animated)
        }
    }


    /**
     * This method checks if a coordinate is valid or not.
     */
    func isValidCoordinate(coordinate: CLLocationCoordinate2D) -> Bool {

        // Skip things very close (0, 0). Unfortunately you get (0, 0) sometimes as a coordinate.
        return (abs(coordinate.latitude) > 0.1) || (abs(coordinate.latitude) > 0.1)
    }


    /**
     * This method trims all spaces around a string and removes double spacing.
     */
    func trimAllSpace(input: String) -> String {
        var output = input.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet());
        var changed = false
        repeat {
            let replaced = output.stringByReplacingOccurrencesOfString("  ", withString: " ")
            changed = (replaced != output)
            output = replaced
        } while changed
        return output
    }


    /**
     * Returns true if new coordinate is nil or no different from previous one.
     */
    func isEqualOrNil(newCoordinate: CLLocationCoordinate2D!, prevCoordinate: CLLocationCoordinate2D!) -> Bool {
        if newCoordinate == nil {
            // Nothing to do; new coordinate is nil.
        } else if prevCoordinate == nil {
            // New coordinate is not nil, old is nil, so not equal.
            return false;
        } else {
            // Both are not nil. Check if they are equal.
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
     * Return meters per degree longitude (at a specific latitude).
     */
    func metersPerDegreeLonAtLan(atLatitude: Double) -> Double {
        let meters = metersPerDegreeLonAtEquator *
                cos(max(-85.0, min(85.0, abs(atLatitude))) / 180.0 * 3.141592654)
        return meters
    }


    /**
     * Simple debug loggin.
     */
    func debug(level: UInt8, msg: String) {
        var prefix: String!
        if (level & debugMask) == TRACE {
            prefix = "TRACE"
        } else if (level & debugMask) == DEBUG {
            prefix = "DEBUG"
        } else if (level & debugMask) == INFO {
            prefix = "INFO"
        } else if (level & debugMask) == WARN {
            prefix = "WARN"
        } else if (level & debugMask) == ERROR {
            prefix = "ERROR"
        } else {
            prefix = nil
        }
        if prefix != nil {
            print("\(prefix!): \(msg)")
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
