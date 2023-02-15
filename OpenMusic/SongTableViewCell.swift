//
//  TableViewCell.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 22/05/15.
//  Copyright (c) 2015 Matteo Riva. All rights reserved.
//

import UIKit
import ACPDownload
import QuartzCore
import MGSwipeTableCell

class SongTableViewCell: MGSwipeTableCell {
    
    @IBOutlet weak var number: UILabel? {
        didSet {
            number?.layer.cornerRadius = 12.5
            number?.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            number?.textColor = UIColor.white
        }
    }
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var artist: UILabel!
    @IBOutlet weak var duration: UILabel?
    @IBOutlet weak var quality: UILabel! {
        didSet {
            quality.layer.cornerRadius = 2
        }
    }
    @IBOutlet weak var downloadButton: ACPDownloadView?
    @IBOutlet weak var playbutton: UIButton?
    
    @IBOutlet weak var thumbImage: UIImageView? {
        didSet { thumbImage?.layer.cornerRadius = 3 }
    }
    
    private(set) var id: String!
    
    func displaySongInfos(_ song: Song) {
        id = song.id
        title.text = song.title
        artist.text = song.artist!.name
        duration?.text = song.duration
        quality.text = song.bitrate == 0 ? " VBR " : " \(song.bitrate) kbps "
        
        if song.bitrate == 0 {
            quality.backgroundColor = UIColor.lightGray
        } else if song.bitrate <= 128 {
            quality.backgroundColor = UIColor.red
        } else if song.bitrate >= 256 {
            quality.backgroundColor = UIColor(red: 20.0/255.0, green: 128.0/255.0, blue: 48.0/255.0, alpha: 1)
        } else {
            quality.backgroundColor = UIColor.orange
        }
        
    }
    
    func displayEphimeralSongInfos(_ song: EphimeralSong) {
        id = song.id
        title.text = song.title
        artist.text = song.artist
        duration?.text = song.duration
        quality.text = song.bitrate == 0 ? " VBR " : " \(song.bitrate) kbps "
        
        if song.bitrate == 0 {
            quality.backgroundColor = UIColor.lightGray
        } else if song.bitrate <= 128 {
            quality.backgroundColor = UIColor.red
        } else if song.bitrate >= 256 {
            quality.backgroundColor = UIColor(red: 20.0/255.0, green: 128.0/255.0, blue: 48.0/255.0, alpha: 1)
        } else {
            quality.backgroundColor = UIColor.orange
        }
        
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        let colorQ = quality.backgroundColor
        let colorN = number?.backgroundColor
        super.setSelected(selected, animated: animated)
        quality.backgroundColor = colorQ
        number?.backgroundColor = colorN
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        let colorQ = quality.backgroundColor
        let colorN = number?.backgroundColor
        super.setHighlighted(highlighted, animated: animated)
        quality.backgroundColor = colorQ
        number?.backgroundColor = colorN
    }

}
