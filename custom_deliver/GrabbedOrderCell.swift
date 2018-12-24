//
//  GrabbedOrderCell.swift
//  custom_deliver
//
//  Created by S WEI on 2018-12-12.
//  Copyright © 2018 S WEI. All rights reserved.
//

import UIKit

protocol GrabbedOrderCellDelegate: class {
    func tickButtonPressedFrom(_ cell: GrabbedOrderCell)
    func mapButtonPressedFrom(_ cell: GrabbedOrderCell)
}

class GrabbedOrderCell: UITableViewCell {

    @IBOutlet weak var tickButton: UIButton!
    @IBOutlet weak var freightLabel: UILabel!
    @IBOutlet weak var tipsLabel: UILabel!
    @IBOutlet weak var cashLabel: UILabel!
    @IBOutlet weak var subtotalLabel: UILabel!
    @IBOutlet weak var fromSiteLabel: UILabel!
    @IBOutlet weak var aimSiteLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var etaLabel: UILabel!
    @IBOutlet weak var clientNameLabel: UILabel!
    @IBOutlet weak var storeNameLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var tipsRateLabel: UILabel!
    @IBOutlet weak var clientPhoneLabel: UILabel!
    @IBOutlet weak var createTimeLabel: UILabel!
    @IBOutlet weak var mealTimeLabel: UILabel!
    @IBOutlet weak var appointTimeLabel: UILabel!
    @IBOutlet weak var timeToStoreLabel: UILabel!
    @IBOutlet weak var timeToClientLabel: UILabel!
    weak var delegate: GrabbedOrderCellDelegate?
    
    var supplyId: String?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }

    @IBAction func onMapPressed(_ sender: UIButton) {
        delegate!.mapButtonPressedFrom(self)
    }
    @IBAction func onTickPressed(_ sender: AnyObject){
        delegate!.tickButtonPressedFrom(self)
    }
}
