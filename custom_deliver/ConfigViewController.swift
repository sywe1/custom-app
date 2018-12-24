//
//  ThirdViewController.swift
//  custom_deliver
//
//  Created by S WEI on 2018-12-01.
//  Copyright © 2018 S WEI. All rights reserved.
//

import UIKit
import os

class ConfigViewController: UIViewController{
    
    @IBOutlet weak var compareSwitch: UISwitch!
    @IBOutlet weak var tipsBarLabel: UILabel!
    var tipsBar: Double = 8.0 {
        didSet (bar) {
            updateTipsBarLebel(bar: self.tipsBar)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tipsBar = 8.0
    }
    
    func updateTipsBarLebel(bar: Double) {
        let customLog = OSLog(subsystem: ".settings", category: "updateTipsBarLabel")
        tipsBarLabel.text = String(tipsBar)
        guard let grabViewController = self.tabBarController!.viewControllers?[0] as? GrabViewController else {
            os_log(.error, log: customLog, "Fail to fetch grabViewController")
            return
        }
        grabViewController.autoTickTipsBar = tipsBar
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
    }
    
    @IBAction func onTipBarPlus(_ sender: UIButton) {
        tipsBar += 1.0
    }
    @IBAction func onTipBarMinus(_ sender: UIButton) {
        if (tipsBar > 4.0 ) {
            tipsBar -= 1.0
        }
    }
    
    @IBAction func showMapView(_ sender: UIButton) {
        os_log(.debug, "show map view")
    }
    
    @IBAction func autoTipSwitch(_ sender: UISwitch) {
        let customLog = OSLog(subsystem: ".settings", category: "autoTipSwitch")
        guard let grabViewController = self.tabBarController!.viewControllers?[0] as? GrabViewController else {
            os_log(.error, log: customLog, "Fail to fetch grabViewController")
            return
        }
        grabViewController.autoTickOnTipsGTFreight = compareSwitch.isOn
    }
}
