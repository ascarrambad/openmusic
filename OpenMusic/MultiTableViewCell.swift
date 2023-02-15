//
//  ArtistTableViewCell.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 27/05/15.
//  Copyright (c) 2015 Matteo Riva. All rights reserved.
//

import UIKit
import MarqueeLabel

class MultiTableViewCell: UITableViewCell {

    @IBOutlet weak var name: MarqueeLabel! {
        didSet {
            name.marqueeType = .MLContinuous
            name.trailingBuffer = 20
        }
    }
    
    @IBOutlet weak var caption: UILabel?
    
    @IBOutlet weak var numberOfSongs: UILabel!
    @IBOutlet weak var artistImage: UIImageView? {
        didSet { artistImage!.layer.cornerRadius = 59/2 }
    }
    
    @IBOutlet weak var albumImage: UIImageView? {
        didSet { albumImage?.layer.cornerRadius = 5 }
    }
    
    func setNumOfSongs(_ num: Int) {
        var numberString = "\(num)"
        numberString += num > 1 ? "cell_songs".localized : "cell_song".localized
        numberOfSongs.text = numberString
    }

}
