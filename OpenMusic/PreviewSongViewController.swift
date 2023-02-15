//
//  PreviewSongViewController.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 19/06/16.
//  Copyright © 2016 Matteo Riva. All rights reserved.
//

import UIKit
import NAKPlaybackIndicatorView
import AVFoundation

@available(iOS 9.0, *)
class PreviewSongViewController: UIViewController {
    
    @IBOutlet weak var coverAlbum: UIImageView!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var indicator: NAKPlaybackIndicatorView!
    
    let previewPlayer = AVPlayer()
    var previewSongs: [Song]?
    var startIndex: Int?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let index = startIndex, let song = previewSongs?[index] {
            
            let asset = AVURLAsset(url: song.fileURL!, options: nil)
            let item = AVPlayerItem(asset: asset)
            previewPlayer.replaceCurrentItem(with: item)
            
            play()
            
            artistLabel.text = song.artist?.name
            titleLabel.text = song.title
            if let imagePath = song.coverImageURL?.path {
                coverAlbum.image = UIImage(contentsOfFile: imagePath) ?? UIImage(named: "coverPlaceholder")
            } else {
                coverAlbum.image = UIImage(named: "coverPlaceholder")
            }
        }
        
        indicator.tintColor = UIColor.white
        indicator.state = .playing
        
    }
    
    private func play() {
        try? AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        previewPlayer.play()
    }
    
    func setSongs(_ songs: [Song], startIndex: Int) {
        self.previewSongs = songs
        self.startIndex = startIndex
    }

}
