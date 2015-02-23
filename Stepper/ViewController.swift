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
import MessageUI

class ViewController: UIViewController, MFMailComposeViewControllerDelegate {
    
    @IBOutlet weak var gyroscopeLabel: UILabel!
    @IBOutlet weak var accelerometerLabel: UILabel!
    @IBOutlet weak var attitudeLabel: UILabel!
    @IBOutlet weak var stepCounter: UILabel!
    
    @IBAction func doneRecording(sender: AnyObject) {
        sendMail(output)
    }
    
    private let motionManager = CMMotionManager()
    private var updateTimer:NSTimer!
    
    private let bundle = NSBundle.mainBundle()
    
    let stepThreshold : Double = 0.35
    let interval : Double = 0.01
    let lowest : Double = -0.2
    
    var stepFlag = 0
    
    private var stepCount : Int = 0
    
    var output : NSString = ""
    var now : NSDate?
    
    func updateDisplay() {
        let motion = motionManager.deviceMotion
        if motion != nil {
            
            let rotationRate = motion.rotationRate
            let gravity = motion.gravity
            let userAcc = motion.userAcceleration
            let attitude = motion.attitude
            
            let gyroscopText = String(format:"Rotation Rate:\nx:%+.2f y: %+.2f z: %+.2f", rotationRate.x, rotationRate.y, rotationRate.z)
            let acceleratorText = String(format:"Acceleration:\nGravity x: %+.2f User x: %+.2f\nGravity y: %+.2f User y: %+.2f\nGravity z: %+.2f User z: %+.2f", gravity.x, userAcc.x, gravity.y, userAcc.y, gravity.z, userAcc.z)
            let attitudeText = String(format:"Attitude:\nRoll: %+.2f  Pitch: %+.2f Yaw:%+.2f", attitude.roll, attitude.pitch, attitude.yaw)
            
            let timestamp = now!.timeIntervalSinceNow
            let timestampStr = String("\(-timestamp), ")
            
            let content = String(format:"%+.2f, %+.2f, %+.2f, %+.2f, %+.2f, %+.2f, %+.2f, %+.2f, %+.2f, %+.2f, %+.2f, %+.2f\n", rotationRate.x, rotationRate.y, rotationRate.z, gravity.x, userAcc.x, gravity.y, userAcc.y, gravity.z, userAcc.z, attitude.roll, attitude.pitch, attitude.yaw)
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
                    self.stepCounter.text = String("Steps: \(self.stepCount)\nTime: \(-timestamp)")
            })

        }
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
        NSLog("sent")
        return 0
    }
    
    func mailComposeController(controller: MFMailComposeViewController!, didFinishWithResult result: MFMailComposeResult, error: NSError!) {

        self.dismissViewControllerAnimated(true, completion:nil)
    }
    
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        now = NSDate()
        if motionManager.deviceMotionAvailable {
            
            motionManager.deviceMotionUpdateInterval = interval
            motionManager.startDeviceMotionUpdates()
            updateTimer = NSTimer.scheduledTimerWithTimeInterval(interval, target: self, selector: "updateDisplay", userInfo: nil, repeats: true)
        }

    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        if motionManager.deviceMotionAvailable {
            
            motionManager.stopDeviceMotionUpdates()
            updateTimer.invalidate()
            updateTimer = nil
        }
    }
    
    override func shouldAutorotate() -> Bool {
        return false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

