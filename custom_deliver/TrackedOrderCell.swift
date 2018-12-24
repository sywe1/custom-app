//
//  TrackedOrderCell.swift
//  custom_deliver
//
//  Created by S WEI on 2018-12-27.
//  Copyright © 2018 S WEI. All rights reserved.
//

import UIKit

protocol TrackedOrderCellDelegate: class {
    func onRestaurantRouteRequest(_ cell: TrackedOrderCell)
    func onClientRouteRequest(_ cell: TrackedOrderCell)
    func onMapButtonPressed(_ cell: TrackedOrderCell)
}

class TrackedOrderCell: UITableViewCell {

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
    
    @IBOutlet weak var clientNavigationButton: UIButton!
    @IBOutlet weak var storeNavigationButton: UIButton!
    weak var delegate: TrackedOrderCellDelegate?
    var supplyId: String?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func onMapClicked(_ sender: UIButton) {
        self.delegate?.onMapButtonPressed(self)
    }
    @IBAction func onClientLocationClicked(_ sender: UIButton) {
        self.delegate?.onClientRouteRequest(self)
    }
    @IBAction func onStoreLocationClicked(_ sender: UIButton) {
        self.delegate?.onRestaurantRouteRequest(self)
    }
}
