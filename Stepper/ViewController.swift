//
//  ViewController.swift
//  Stepper
//
//  Created by Yumen Cao on 2/13/15.
//  Copyright (c) 2015 Remis-Tsao. All rights reserved.
//

import UIKit
import Foundation
import CoreMotion
import CoreLocation
import AVFoundation
import MessageUI

let precisionDefault:Double = 12
let strideDefault:Double = 0.38

class ViewController: UIViewController, MFMailComposeViewControllerDelegate, CLLocationManagerDelegate, AVAudioRecorderDelegate,AVAudioPlayerDelegate {
    
    @IBOutlet weak var precisionInput: UITextField!
    @IBOutlet weak var strideInput: UITextField!
    
    @IBOutlet weak var gyroscopeLabel: UILabel!
    @IBOutlet weak var accelerometerLabel: UILabel!
    @IBOutlet weak var attitudeLabel: UILabel!
    @IBOutlet weak var stepCounter: UILabel!
    @IBOutlet weak var northPole: UILabel!
    @IBOutlet weak var soundLevel: UILabel!
    @IBOutlet weak var totalDegree: UILabel!
    
    @IBAction func doneRecording(sender: AnyObject) {
        startButton.enabled = true
        doneButton.enabled = false

        recorder?.stop()
        
        if motionManager.deviceMotionAvailable {
            motionManager.stopDeviceMotionUpdates()
            updateTimer.invalidate()
            updateTimer = nil
        }
        if CLLocationManager.headingAvailable() {
            locationManager.stopUpdatingHeading()
        }
        
        sendMail(output)
        
    }
    
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var doneButton: UIButton!
    
    @IBAction func startEverything(sender: AnyObject) {
        startButton.enabled = false
        doneButton.enabled = true
        
        var precisionTemp = (precisionInput.text as NSString).doubleValue
        if precisionTemp > 0 {
            self.precision = precisionTemp
        }
        
        var strideTemp = (strideInput.text as NSString).doubleValue
        if strideTemp > 0 {
            self.stride = strideTemp
        }
        
        precisionInput.text = String(format: "Precision: %.0f", self.precision)
        strideInput.text = String(format: "Stride: %.3f", self.stride)
        
        self.step = 3.141592653/self.precision
        
        recorder?.record()
        
        now = NSDate()
        if motionManager.deviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = interval
            motionManager.startDeviceMotionUpdates()
            
        }
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
        
        updateTimer = NSTimer.scheduledTimerWithTimeInterval(interval, target: self, selector: "updateDisplay", userInfo: nil, repeats: true)

    }
    
    private let motionManager = CMMotionManager()
    private let locationManager = CLLocationManager()
    
    private var recorder:AVAudioRecorder?
    
    private var compassGeoFlt:Float = -1
    private var compassMagFlt:Float = -1
    private var soundChl1Flt:Float = 1
    private var soundChl2Flt:Float = 1
    
    // total degree
    private var precision:Double = precisionDefault
    private var stride:Double = strideDefault
    private var step:Double = 3.141592653/precisionDefault
    private var inital:Double = 0
    private var totalDegreeTurned: Double = 0
    
    private var updateTimer:NSTimer!
    
    private let bundle = NSBundle.mainBundle()
    
    let stepThreshold : Double = 0.35
    let interval : Double = 0.01
    let lowest : Double = -0.2
    
    var stepFlag = 0
    
    private var stepCount : Int = 0
    
    var output : NSString = ""
    var now : NSDate?
    
    override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        self.view.endEditing(true)
    }
    
    func updateDisplay() {
        let motion = motionManager.deviceMotion
        let heading = locationManager.heading
        
        if motion != nil {
            
            let rotationRate = motion.rotationRate
            let gravity = motion.gravity
            let userAcc = motion.userAcceleration
            let attitude = motion.attitude
            
            let gyroscopText = String(format:"Rotation Rate:\nx:%+.2f y: %+.2f z: %+.2f", rotationRate.x, rotationRate.y, rotationRate.z)
            let acceleratorText = String(format:"Acceleration:\nGravity x: %+.2f User x: %+.2f\nGravity y: %+.2f User y: %+.2f\nGravity z: %+.2f User z: %+.2f", gravity.x, userAcc.x, gravity.y, userAcc.y, gravity.z, userAcc.z)
            let attitudeText = String(format:"Attitude:\nRoll: %+.2f  Pitch: %+.2f Yaw:%+.2f", attitude.roll, attitude.pitch, attitude.yaw)
            
            
            let timestamp = now!.timeIntervalSinceNow
            let timestampStr = String(format:"%.3f,", -timestamp)
            
            let content = String(format:"%+.2f, %+.2f, %+.2f, %+.2f, %+.2f, %+.2f, %+.2f, %+.2f, %+.2f, %+.2f, %+.2f, %+.2f, %+.2f, %+.2f, %+.2f, %+.2f\n", rotationRate.x, rotationRate.y, rotationRate.z, gravity.x, userAcc.x, gravity.y, userAcc.y, gravity.z, userAcc.z, attitude.roll, attitude.pitch, attitude.yaw, soundChl1Flt, soundChl2Flt, compassGeoFlt, compassMagFlt)
            
            output = output + timestampStr + content
            
            if (Double(userAcc.z) - lowest) > stepThreshold && stepFlag == 0 {
                stepCount++
                stepFlag = 1
            }
            
            if stepFlag == 1 && Double(userAcc.z) < 0 {
                stepFlag = 0
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                self.gyroscopeLabel.text = gyroscopText
                self.accelerometerLabel.text = acceleratorText
                self.attitudeLabel.text = attitudeText
                self.stepCounter.text = String("Steps: \(self.stepCount) Distance: \(Double(self.stepCount)*self.stride)\nTime: \(timestampStr)")
                
                self.calculateDegreeTurned(attitude.yaw)

                if self.recorder?.recording == true {
                    self.recorder?.updateMeters()
                    
                    self.soundChl1Flt = self.recorder!.peakPowerForChannel(0)
                    self.soundChl2Flt = self.recorder!.peakPowerForChannel(1)
                    self.soundLevel.text = String(format: "Sound Level: %.2f %.2f", self.soundChl1Flt, self.soundChl2Flt)
                                    }
            })
        }
    }
    
    func calculateDegreeTurned( yaw:Double ) {
        if abs(yaw - self.inital) > 2 {
            self.inital = -1 * self.inital
        }
        if yaw > (self.inital + self.step) {
            self.totalDegreeTurned = self.totalDegreeTurned + 180/self.precision
            self.inital = self.inital + self.step
        }
        else if yaw < (self.inital - self.step) {
            self.totalDegreeTurned = self.totalDegreeTurned + 180/self.precision
            self.inital = self.inital - self.step
        }
        totalDegree.text = String(format: "Total Degree Turned: %.2f", self.totalDegreeTurned)
    }
    
    func sendMail( body:NSString) -> Int {
            let picker = MFMailComposeViewController();
            picker.mailComposeDelegate = self;
        let today = NSDate()
        let dateString = today.description
        picker.setSubject("[ECE498] Data from sensors \(dateString)");
        println(dateString)
    
        picker.setMessageBody(body, isHTML:false);
    
        let toRecipients = ["ycao10@illinois.edu", "remis2@illinois.edu"]
    
        picker.setToRecipients(toRecipients)
        self.presentViewController(picker, animated:true, completion:nil)
        return 0
    }
    
    func mailComposeController(controller: MFMailComposeViewController!, didFinishWithResult result: MFMailComposeResult, error: NSError!) {

        self.dismissViewControllerAnimated(true, completion:nil)
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateHeading newHeading: CLHeading!) {
        if newHeading.headingAccuracy < 0 {
            return
        }
        
        self.northPole.text = String(format:"GeoNP: %.2f MagNP: %.2f", newHeading.trueHeading,newHeading.magneticHeading)
        self.compassGeoFlt = Float(newHeading.trueHeading)
        self.compassMagFlt = Float(newHeading.magneticHeading)
        return
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        locationManager.headingFilter = kCLHeadingFilterNone
        
        let dirPaths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let docsDir = dirPaths[0] as String
        let soundFilePath = docsDir.stringByAppendingPathComponent("sound.caf")
        let soundFileURL = NSURL(fileURLWithPath: soundFilePath)
        let recordSettings = [AVEncoderAudioQualityKey: AVAudioQuality.Min.rawValue, AVEncoderBitRateKey: 16,AVNumberOfChannelsKey: 2, AVSampleRateKey: 44100.0]
        
        var error: NSError?
        
        let audioSession = AVAudioSession.sharedInstance()
        audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord,
            error: &error)
        
        if let err = error {
            println("audioSession error: \(err.localizedDescription)")
        }
        
        recorder = AVAudioRecorder(URL: soundFileURL,
            settings: recordSettings, error: &error)
        
        if let err = error {
            println("audioSession error: \(err.localizedDescription)")
        } else {
            recorder?.prepareToRecord()
        }
        recorder?.meteringEnabled = true
        doneButton.enabled = false
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
    }
    
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer!, successfully flag: Bool) {
    }
    
    func audioPlayerDecodeErrorDidOccur(player: AVAudioPlayer!, error: NSError!) {
        println("Audio Play Decode Error")
    }
    
    func audioRecorderDidFinishRecording(recorder: AVAudioRecorder!, successfully flag: Bool) {
    }
    
    func audioRecorderEncodeErrorDidOccur(recorder: AVAudioRecorder!, error: NSError!) {
        println("Audio Record Encode Error")
    }
    
    override func shouldAutorotate() -> Bool {
        return false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

