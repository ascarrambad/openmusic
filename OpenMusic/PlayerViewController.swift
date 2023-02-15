//
//  PlayerViewController.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 27/05/15.
//  Copyright (c) 2015 Matteo Riva. All rights reserved.
//

import UIKit
import MediaPlayer
import MarqueeLabel

class PlayerViewController: UIViewController {
    
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var shuffleButton: UIButton!
    @IBOutlet weak var loopButton: UIButton!
    @IBOutlet weak var titleLabel: MarqueeLabel!
    @IBOutlet weak var artistLabel: MarqueeLabel!
    @IBOutlet weak var elapsedTime: UILabel!
    @IBOutlet weak var remainingTime: UILabel!
    @IBOutlet weak var minVolumeImage: UIImageView!
    @IBOutlet weak var maxVolumeImage: UIImageView!
    @IBOutlet weak var volumeSliderView: UIView!
    @IBOutlet weak var currentTimeSlider: UISlider!
    @IBOutlet weak var coverImage: UIImageView!
    
    @IBOutlet weak var topCoverConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleBackgroundView: UIView!
    @IBOutlet weak var topTitleLabel: NSLayoutConstraint!
    
    @IBOutlet weak var topVolumeBar: NSLayoutConstraint!
    @IBOutlet weak var topLeftSpeaker: NSLayoutConstraint!
    @IBOutlet weak var topRightSpeaker: NSLayoutConstraint!
    @IBOutlet weak var topTimeSlider: NSLayoutConstraint!
    
    private let notificationCenter = NotificationCenter.default
    private let corePlayer = CorePlayer.shared
    
    private var constraintsSet = false
    var isNowPlaying = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        playerLayout()
        play()
        
        titleLabel.trailingBuffer = 20
        titleLabel.marqueeType = .MLContinuous
        
        artistLabel.trailingBuffer = 20
        artistLabel.marqueeType = .MLContinuous
        
        minVolumeImage.image = minVolumeImage.image?.withRenderingMode(.alwaysTemplate)
        maxVolumeImage.image = maxVolumeImage.image?.withRenderingMode(.alwaysTemplate)
        
        let thumbImage = UIImage(named: "thumbPlayerImage")?.withRenderingMode(.alwaysTemplate)
        currentTimeSlider.thumbTintColor = UIColor.orange
        
        currentTimeSlider.setThumbImage(thumbImage, for: .normal)
        currentTimeSlider.setThumbImage(thumbImage, for: .selected)
        currentTimeSlider.setThumbImage(thumbImage, for: .highlighted)
        
        unowned let volumeSlider = MPVolumeView()
        
        let dict = ["volume" : volumeSlider, "min" : minVolumeImage, "max" : maxVolumeImage, "button" : playPauseButton] as [String : Any]
        volumeSlider.translatesAutoresizingMaskIntoConstraints = false
        volumeSlider.tintColor = navigationController?.navigationBar.barTintColor
        volumeSlider.showsRouteButton = true
        
        volumeSlider.setRouteButtonImage(UIImage(named: "airplayButton")?.withRenderingMode(.alwaysTemplate), for: .normal)
        
        volumeSliderView.addSubview(volumeSlider)
        volumeSliderView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[volume]-|", options: [], metrics: nil, views: dict))
        volumeSliderView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[volume]-|", options: [], metrics: nil, views: dict))
        
        if isNowPlaying {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(PlayerViewController.dismissAction))
        }
        
        playPauseButton.tintColor = navigationController?.navigationBar.barTintColor
        previousButton.tintColor = navigationController?.navigationBar.barTintColor
        nextButton.tintColor = navigationController?.navigationBar.barTintColor
        volumeSliderView.tintColor = navigationController?.navigationBar.barTintColor
        currentTimeSlider.tintColor = navigationController?.navigationBar.barTintColor
        coverImage.tintColor = navigationController?.navigationBar.barTintColor
        
        notificationCenter.addObserver(forName: .CorePlayerStatusDidChange, object: nil, queue: .main) { [weak self] (_) -> Void in
            if self?.corePlayer.current != nil {
                if self?.corePlayer.isPlaying ?? false {
                    self?.play()
                } else {
                    self?.pause()
                }
            }
        }
        
        notificationCenter.addObserver(forName: .CorePlayerDidStartNewSong, object: nil, queue: .main) { [weak self] (_) in
            self?.corePlayer.addTimeObserver { [weak self] (_) in
                if UIApplication.shared.applicationState != .background {
                    self?.updateTime()
                }
            }
            self?.displaySongInfos()
            self?.updateTime()
        }
        
        notificationCenter.addObserver(forName: .CorePlayerDidEndSongQueue, object: nil, queue: .main) { [weak self] (_) in
            self?.dismissAction()
        }
        
        notificationCenter.addObserver(forName: .AppStatusDidChange, object: nil, queue: .main) { [weak self] (_) in
            self?.updateTime()
        }
        
    }
    
    deinit {
        notificationCenter.removeObserver(self)
        if !corePlayer.isPlaying {
            corePlayer.reset(endingAudioSession: true)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        corePlayer.removeTimeObserver()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        corePlayer.addTimeObserver { [weak self] (_) in
            if UIApplication.shared.applicationState != .background {
                self?.updateTime()
            }
        }
        
        if !constraintsSet {
            /*let banner = (UIApplication.sharedApplication().delegate as! AppDelegate).adProvider.retrieveBanner(removeFromSuperview: true, withFrame: AdProvider.CGRectPlayer)
             view.addSubview(banner)*/
            if DeviceType.iPhone4OrLess {
                topCoverConstraint.constant = -50
                topTitleLabel.constant = -45
                topTimeSlider.constant = 15
                titleBackgroundView.isHidden = false
                titleLabel.textColor = UIColor.white
                artistLabel.textColor = UIColor.white
            } else if DeviceType.iPhone6 {
                topTitleLabel.constant = topTitleLabel.constant + 15
                topVolumeBar.constant = topVolumeBar.constant + 15
                topLeftSpeaker.constant = topLeftSpeaker.constant + 15
                topRightSpeaker.constant = topRightSpeaker.constant + 15
            } else if DeviceType.iPhone6Plus {
                topTitleLabel.constant = topTitleLabel.constant + 25
                topVolumeBar.constant = topVolumeBar.constant + 35
                topLeftSpeaker.constant = topLeftSpeaker.constant + 35
                topRightSpeaker.constant = topRightSpeaker.constant + 35
            }
            constraintsSet = true
        }
        
        updateTime()
    }
    
    //MARK: - Layout
    
    func playerLayout() {
        
        updateTime()
        displaySongInfos()
        
        if corePlayer.isShuffled {
            shuffleButton.tintColor = navigationController?.navigationBar.barTintColor?.inverse
        } else {
            shuffleButton.tintColor = navigationController?.navigationBar.barTintColor
        }
        
        switch corePlayer.loopType {
        case .allPlaylist:
            loopButton.tintColor = navigationController?.navigationBar.barTintColor?.inverse
        case .currentSong:
            loopButton.tintColor = navigationController?.navigationBar.barTintColor?.inverse
            loopButton.setImage(UIImage(named: "loop1Button")!, for: .normal)
        case .normal:
            loopButton.tintColor = navigationController?.navigationBar.barTintColor
            loopButton.setImage(UIImage(named: "loopButton")!, for: .normal)
        }
    }
    
    func displaySongInfos() {
        titleLabel.text = corePlayer.current?.title
        
        let artistName = corePlayer.current?.artist?.name ?? "unknown_artist".localized
        let albumName = corePlayer.current?.album?.name ?? "unknown_album".localized
        
        artistLabel.text =  artistName + " - " + albumName
        currentTimeSlider.maximumValue = Float(corePlayer.current?.durationInSeconds ?? 0)
        currentTimeSlider.value = 0
        if let url = corePlayer.current?.coverImageURL {
            self.coverImage.image = UIImage(contentsOfFile: url.path)
        } else {
            self.coverImage.image = UIImage(named: "coverTintPlaceholder")?.withRenderingMode(.alwaysTemplate)
        }
    }
    
    //MARK: - Generics
    
    func updateTime() {
        if !corePlayer.currentTime.seconds.isNaN && !(corePlayer.duration?.seconds.isNaN ?? false) {
            let f = ".2"
            let progress = Float(corePlayer.currentTime.seconds.rounded())
            let duration = Float(corePlayer.duration!.seconds)
            if duration/60<60 {
                
                let elapTime = Int(progress/60)
                let elapTimeR = Int(progress.truncatingRemainder(dividingBy: 60))
                let remTime = Int((duration-progress)/60)
                let remTimeR = Int((duration-progress).truncatingRemainder(dividingBy: 60))
                
                elapsedTime.text = "\(elapTime):\(elapTimeR.format(f))"
                remainingTime.text = "-\(remTime):\(remTimeR.format(f))"
            } else {
                
                let elapTime = Int(progress/3600)
                let elapTime2 = Int(progress.truncatingRemainder(dividingBy: 3600)/60)
                let elapTimeR = Int(progress.truncatingRemainder(dividingBy: 3600).truncatingRemainder(dividingBy: 60))
                let remTime = Int((duration-progress)/3600)
                let remTime2 = Int((duration-progress).truncatingRemainder(dividingBy: 3600)/60)
                let remTimeR = Int((duration-progress).truncatingRemainder(dividingBy: 3600).truncatingRemainder(dividingBy: 60))
                
                elapsedTime.text = "\(elapTime.format(f)):\(elapTime2.format(f)):\(elapTimeR.format(f))"
                remainingTime.text = "-\(remTime.format(f)):\(remTime2.format(f)):\(remTimeR.format(f))"
            }
            currentTimeSlider.value = Float(progress)
        }
    }
    
    //MARK: - Actions
    
    func dismissAction() {
        DispatchQueue.main.async { [weak self] in
            if self?.isNowPlaying ?? false { self?.dismiss(animated: true, completion: nil) }
            else { _=self?.navigationController?.popViewController(animated: true) }
        }
    }
    
    @IBAction func shuffleAction() {
        corePlayer.isShuffled = !corePlayer.isShuffled
        
        if corePlayer.isShuffled {
            shuffleButton.tintColor = navigationController?.navigationBar.barTintColor?.inverse
        } else {
            shuffleButton.tintColor = navigationController?.navigationBar.barTintColor
        }
        
    }
    
    @IBAction func loopAction() {
        switch corePlayer.loopType {
        case .normal:
            loopButton.tintColor = navigationController?.navigationBar.barTintColor?.inverse
        case .allPlaylist:
            loopButton.setImage(UIImage(named: "loop1Button")!, for: .normal)
        case .currentSong:
            loopButton.tintColor = navigationController?.navigationBar.barTintColor
            loopButton.setImage(UIImage(named: "loopButton")!, for: .normal)
        }
        corePlayer.changeLoop()
    }
    
    @IBAction func playPauseAction() {
        if corePlayer.isPlaying {
            corePlayer.pause()
        } else {
            corePlayer.play()
        }
    }
    
    @IBAction func nextAction() {
        corePlayer.next() { [weak self] success in
            if success {
                self?.displaySongInfos()
                self?.updateTime()
            }
        }
    }
    
    @IBAction func previousActon() {
        corePlayer.previous() { [weak self] success in
            if success {
                self?.displaySongInfos()
                self?.updateTime()
            }
        }
    }
    
    @IBAction func sliderDidChangePosition() {
        let f = ".2"
        let duration = Double(corePlayer.current?.durationInSeconds ?? 0)
        let current = Double(currentTimeSlider.value)
        if duration/60<60 {
            
            let elapTime = Int(current/60)
            let elapTimeR = Int(current.truncatingRemainder(dividingBy: 60))
            let remTime = Int((duration-current)/60)
            let remTimeR = Int((duration-current).truncatingRemainder(dividingBy: 60))
            
            elapsedTime.text = "\(elapTime):\(elapTimeR.format(f))"
            remainingTime.text = "-\(remTime):\(remTimeR.format(f))"
        } else {
            
            let elapTime = Int(current/3600)
            let elapTime2 = Int(current.truncatingRemainder(dividingBy: 3600)/60)
            let elapTimeR = Int(current.truncatingRemainder(dividingBy: 3600).truncatingRemainder(dividingBy: 60))
            let remTime = Int((duration-current)/3600)
            let remTime2 = Int((duration-current).truncatingRemainder(dividingBy: 3600)/60)
            let remTimeR = Int((duration-current).truncatingRemainder(dividingBy: 3600).truncatingRemainder(dividingBy: 60))
            
            elapsedTime.text = "\(elapTime.format(f)):\(elapTime2.format(f)):\(elapTimeR.format(f))"
            remainingTime.text = "-\(remTime.format(f)):\(remTime2.format(f)):\(remTimeR.format(f))"
        }
        corePlayer.seek(to: current)
    }
    
    
    @IBAction func lyricsAction(_ sender: AnyObject) {
        
        let ext = MXMLyricsAction.sharedExtension()
        if ext?.isSystemAppExtensionAPIAvailable() ?? false {
            let song = corePlayer.current!
            let cover: UIImage?
            
            if let path = song.coverImageURL?.path {
                cover = UIImage(contentsOfFile: path)!
            } else {
                cover = UIImage(named: "coverTintPlaceholder")!.withRenderingMode(.alwaysTemplate)
            }
            
            ext?.findLyricsForSong(withTitle: song.title,
                                   artist: song.artist!.name,
                                   album: song.album?.name ?? "".localized,
                                   artWork: cover,
                                   currentProgress: corePlayer.currentTime.seconds.rounded(),
                                   trackDuration: Double(song.durationInSeconds),
                                   for: self,
                                   sender: sender,
                                   competionHandler: nil)
        }
        
    }
    
    //MARK: - Handle PlayPauseButton
    
    func pause() {
        DispatchQueue.main.async {[weak self] in
            self?.playPauseButton.setImage(UIImage(named: "playButton"), for: .normal)
        }
    }
    
    func play() {
        DispatchQueue.main.async {[weak self] in
            self?.playPauseButton.setImage(UIImage(named: "pauseButton"), for: .normal)
        }
    }

}
