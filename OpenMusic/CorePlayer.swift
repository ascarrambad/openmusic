//
//  CorePlayer.swift
//  OpenMusic
//
//  Created by Matteo Riva on 17/10/2016.
//  Copyright © 2016 Matteo Riva. All rights reserved.
//

import UIKit
import Foundation
import AVFoundation
import AERecord
import MediaPlayer

extension Notification.Name {
    static let CorePlayerStatusDidChange = Notification.Name("CorePlayerStatusDidChange")
    static let CorePlayerDidStartNewSong = Notification.Name("CorePlayerDidStartNewSong")
    static let CorePlayerDidEndSongQueue = Notification.Name("CorePlayerDidEndSongQueue")
}

enum CorePlayerLoopType {
    case allPlaylist
    case currentSong
    case normal
}

class CorePlayer: NSObject {

    private let notificationCenter = NotificationCenter.default
    typealias completionType = ((Bool) -> Void)?
    private var privateTimeObserver: Any?
    private var publicTimeObserver: Any?
    
    private var shouldStart = false
    private let player = AVPlayer()
    
    // MARK: - Player properties
    
    private(set) var queue: [Song] = []
    private var originalQueue: [Song]?
    
    private(set) var currentIndex: Int?
    var current: Song? {
        get { return currentIndex != nil ? queue[currentIndex!] : nil }
    }
    
    var currentTime: CMTime {
        get { return player.currentTime() }
    }
    
    var duration: CMTime? {
        get { return player.currentItem?.duration }
    }
    
    var isPlaying: Bool {
        get { return player.rate != 0 && player.error == nil }
    }
    
    var loopType: CorePlayerLoopType = .normal
    var isShuffled = false {
        didSet {
            if let current = current {
                if isShuffled {
                    originalQueue = queue
                    let song = current
                    queue.shuffle()
                    if let index = queue.index(of: song) {
                        queue.remove(at: index)
                        queue.insert(song, at: 0)
                        currentIndex = 0
                    }
                } else {
                    let song = current
                    queue = originalQueue ?? []
                    currentIndex = queue.index(of: song)
                    originalQueue = nil
                }
            }
        }
    }
    
    //MARK: - Play Init
    
    static let shared = CorePlayer()
    
    override init() {
        super.init()
        
        notificationCenter.addObserver(forName: SongHasBeenDeletedNotification, object: nil, queue: .main) {[unowned self] (notif) -> Void in
            if let song = notif.userInfo?[SongHasBeenDeletedKey] as? Song {
                let songIsInQueue = self.isInQueue(song)
                if songIsInQueue.found { self.removeSong(at: songIsInQueue.index!) }
            }
        }
        
        let remote = MPRemoteCommandCenter.shared()
        
        remote.playCommand.addTarget { [unowned self] (event) -> MPRemoteCommandHandlerStatus in
            if self.current != nil {
                self.play()
                return .success
            } else {
                if #available(iOS 9.1, *) {
                    return .noActionableNowPlayingItem
                } else {
                    return .commandFailed
                }
            }
        }
        
        remote.pauseCommand.addTarget { [unowned self] (event) -> MPRemoteCommandHandlerStatus in
            if self.current != nil {
                self.pause()
                return .success
            } else {
                if #available(iOS 9.1, *) {
                    return .noActionableNowPlayingItem
                } else {
                    return .commandFailed
                }
            }
        }
        
        remote.stopCommand.addTarget { [unowned self] (event) -> MPRemoteCommandHandlerStatus in
            if self.current != nil {
                self.reset(endingAudioSession: false)
                return .success
            } else {
                if #available(iOS 9.1, *) {
                    return .noActionableNowPlayingItem
                } else {
                    return .commandFailed
                }
            }
        }
        
        remote.nextTrackCommand.addTarget { [unowned self] (event) -> MPRemoteCommandHandlerStatus in
            if self.current != nil {
                self.next(nil)
                return .success
            } else {
                if #available(iOS 9.1, *) {
                    return .noActionableNowPlayingItem
                } else {
                    return .commandFailed
                }
            }
        }
        
        remote.previousTrackCommand.addTarget { [unowned self] (event) -> MPRemoteCommandHandlerStatus in
            if self.current != nil {
                self.previous(nil)
                return .success
            } else {
                if #available(iOS 9.1, *) {
                    return .noActionableNowPlayingItem
                } else {
                    return .commandFailed
                }
            }
        }
        
        if #available(iOS 9.1, *) {
            remote.changePlaybackPositionCommand.addTarget { [unowned self] (event) -> MPRemoteCommandHandlerStatus in
                if self.current != nil {
                    let event = event as! MPChangePlaybackPositionCommandEvent
                    self.seek(to: event.positionTime)
                    return .success
                } else {
                    return .noActionableNowPlayingItem
                }
            }
        }
    }
    
    deinit {
        notificationCenter.removeObserver(self)
        if isPlaying {
            player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.rate))
            player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.status))
            player.currentItem!.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        }
    }
    
    //MARK: - Prepare player for playback
    
    func prepareForPlayback(with songs: [Song], current index: Int, shouldStart: Bool, completion: completionType) {
        if current?.id != songs[index].id || !isPlaying {
            isShuffled = false
            loopType = .normal
            self.queue = songs
            currentIndex = index
            if index <= queue.count-1 {
                try? AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
                try? AVAudioSession.sharedInstance().setActive(true)
                //UIApplication.shared.beginReceivingRemoteControlEvents()
                self.shouldStart = shouldStart
                prepareForPlayback(with: songs[index], completion: completion)
            } else {
                reset(endingAudioSession: true)
                completion?(false)
            }
        } else {
            completion?(true)
        }
        
    }
    
    private func prepareForPlayback(with song: Song, completion: completionType) {
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            
            let asset = AVURLAsset(url: song.fileURL!)
            let item = AVPlayerItem(asset: asset)
            item.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: .new, context: nil)
            
            self.player.replaceCurrentItem(with: item)
            self.setBackgroundMediaInfo(for: song)
            
            self.player.addObserver(self, forKeyPath: #keyPath(AVPlayer.rate), options: .new, context: nil)
            
            let time = CMTime(seconds: 1.0, preferredTimescale: 1)
            self.privateTimeObserver = self.player.addPeriodicTimeObserver(forInterval: time, queue: .main) { [unowned self] (_) in
                self.setBackgroundMediaInfo(for: self.current!)
            }
            
            self.notificationCenter.addObserver(self,
                                                selector: #selector(CorePlayer.playerStoppedHandler(_:)),
                                                name: .AVPlayerItemDidPlayToEndTime,
                                                object: item)
            self.notificationCenter.addObserver(self,
                                                selector: #selector(CorePlayer.playerStoppedHandler(_:)),
                                                name: .AVPlayerItemFailedToPlayToEndTime,
                                                object: item)
            self.notificationCenter.addObserver(forName: .AVPlayerItemPlaybackStalled, object: item, queue: .main) { (notif) in
                print(notif.userInfo ?? "")
            }
            
            completion?(true)
            self.notificationCenter.post(name: .CorePlayerDidStartNewSong, object: nil)
            
            if !self.isShuffled {
                song.playCount += 1
            }
            
            Playlist.createMostPlayed(in: song.managedObjectContext!) { [unowned self] (playlist) -> Void in
                if playlist != nil {
                    AERecord.save()
                    self.notificationCenter.post(name: PlaylistsNeedDisplay, object: nil)
                }
            }
            
            if song.durationInSeconds == 0 {
                song.durationInSeconds = Int16(self.duration!.seconds.rounded())
                let min = (song.durationInSeconds/60).format(".2")
                let sec = (song.durationInSeconds%60).format(".2")
                song.duration = song.durationInSeconds == 0 ? "n/d" : "\(min):\(sec)"
                AERecord.save()
            }
        }
    }
    
    //MARK: - Resume from preview
    
    func resumeFromPreview(with item: AVPlayerItem, songs: [Song], current index: Int) {
        
        isShuffled = false
        loopType = .normal
        queue = songs
        currentIndex = index
        shouldStart = true
        
        current!.playCount += 1
        
        Playlist.createMostPlayed(in: current!.managedObjectContext!) { [unowned self] (playlist) -> Void in
            if playlist != nil {
                AERecord.save()
                self.notificationCenter.post(name: PlaylistsNeedDisplay, object: nil)
            }
        }
        
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        let newItem = AVPlayerItem(asset: item.asset)
        newItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: .new, context: nil)
        newItem.seek(to: item.currentTime())
        
        self.player.replaceCurrentItem(with: newItem)
        
        self.player.addObserver(self, forKeyPath: #keyPath(AVPlayer.rate), options: .new, context: nil)
        
        let time = CMTime(seconds: 1.0, preferredTimescale: 1)
        self.privateTimeObserver = self.player.addPeriodicTimeObserver(forInterval: time, queue: .main) { [unowned self] (_) in
            self.setBackgroundMediaInfo(for: self.current!)
        }
        
        notificationCenter.addObserver(self,
                                       selector: #selector(playerStoppedHandler(_:)),
                                       name: .AVPlayerItemDidPlayToEndTime,
                                       object: newItem)
        notificationCenter.addObserver(self,
                                       selector: #selector(playerStoppedHandler(_:)),
                                       name: .AVPlayerItemFailedToPlayToEndTime,
                                       object: newItem)
    }
    
    //MARK: - Queue operations
    
    func move(at index: Int, to newIndex: Int) {
        let song = queue.remove(at: index)
        queue.insert(song, at: newIndex)
    }
    
    func isInQueue(_ song: Song) -> (found: Bool, index: Int?) {
        for (i, qSong) in queue.enumerated() {
            if qSong.id == song.id { return (true, i) }
        }
        return (false, nil)
    }
    
    func append(_ song: Song) {
        queue.append(song)
    }
    
    func addNext(_ song: Song) {
        queue.insert(song, at: currentIndex!+1)
    }
    
    func removeSong(at index: Int) {
        
        if index > currentIndex! {
            queue.remove(at: index)
        } else if index < currentIndex! {
            queue.remove(at: index)
            currentIndex! -= 1
        } else if currentIndex! == index {
            queue.remove(at: index)
            currentIndex! -= 1
            next(nil)
        }
    }
    
    //MARK: - Index generators
    
    private func nextIndex() {
        currentIndex! += loopType == .currentSong ? 0 : 1
        if currentIndex! >= queue.count {
            currentIndex = loopType == .allPlaylist ? 0 : nil
        }
    }
    
    private func previousIndex() {
        currentIndex! -= loopType == .currentSong ? 0 : 1
        if currentIndex! < 0 {
            currentIndex = loopType == .allPlaylist ? queue.count-1 : nil
        }
    }
    
    //MARK: - Play commands
    
    func play() {
        
        notificationCenter.addObserver(self,
                                       selector: #selector(routeChangeHandler(_:)),
                                       name: .AVAudioSessionRouteChange, object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(audioSessionInterruptHandler(_:)),
                                       name: .AVAudioSessionInterruption, object: nil)
        
        shouldStart = true
        player.play()
        setBackgroundMediaInfo(for: current!)
        
    }
    
    func pause() {
        
        notificationCenter.removeObserver(self, name: .AVAudioSessionRouteChange, object: nil)
        notificationCenter.removeObserver(self, name: .AVAudioSessionInterruption, object: nil)
        
        shouldStart = false
        player.pause()
        setBackgroundMediaInfo(for: current!)
    }
    
    func next(_ completion: completionType) {
        nextIndex()
        if let song = current {
            removePrivateObservers()
            prepareForPlayback(with: song, completion: completion)
            completion?(true)
        } else {
            self.notificationCenter.post(name: .CorePlayerDidEndSongQueue, object: nil)
            reset(endingAudioSession: false)
            completion?(false)
        }
    }
    
    func previous(_ completion: completionType) {
        if currentTime.seconds.rounded() > 5 {
            seek(to: 0)
            setBackgroundMediaInfo(for: current!)
            completion?(true)
        } else {
            previousIndex()
            if let song = current {
                removePrivateObservers()
                prepareForPlayback(with: song, completion: completion)
                completion?(true)
            } else {
                self.notificationCenter.post(name: .CorePlayerDidEndSongQueue, object: nil)
                reset(endingAudioSession: false)
                completion?(false)
            }
        }
    }
    
    func seek(to time: Double) {
        if currentIndex != nil {
            let cmTime: CMTime
            if isPlaying {
                let standTime = min(max(0, time), Double(current!.durationInSeconds-5))
                cmTime = CMTime(seconds: standTime, preferredTimescale: 1)
            } else {
                let standTime = min(max(0, time), Double(current!.durationInSeconds-5))
                cmTime = CMTime(seconds: standTime, preferredTimescale: 1)
            }
            player.seek(to: cmTime)
            setBackgroundMediaInfo(for: current!)
        }
    }
    
    func changeLoop() {
        switch loopType {
        case .normal:
            loopType = .allPlaylist
        case .allPlaylist:
            loopType = .currentSong
        case .currentSong:
            loopType = .normal
        }
    }
    
    func reset(endingAudioSession: Bool) {
        if privateTimeObserver != nil { removePrivateObservers() }
        player.replaceCurrentItem(with: nil)
        queue = []
        currentIndex = nil
        isShuffled = false
        loopType = .normal
        shouldStart = false
        notificationCenter.post(name: .CorePlayerStatusDidChange, object: nil)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        if endingAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false)
            //UIApplication.shared.endReceivingRemoteControlEvents()
        }
    }
    
    //MARK: - Background infos
    
    private var infoCenterUpdatingFlag = false
    
    private func setBackgroundMediaInfo(for song: Song) {
        
        let artwork = UIImage(contentsOfFile: song.coverImageURL?.path ?? "") ?? UIImage(named: "coverPlaceholder")!
        
        let currentlyPlayingTrackInfo: [String : Any] = [
            MPMediaItemPropertyTitle : song.title,
            MPMediaItemPropertyArtist : song.artist?.name ?? "unknown_artist".localized,
            MPMediaItemPropertyAlbumTitle : song.album?.name ?? "unknown_album".localized,
            MPNowPlayingInfoPropertyElapsedPlaybackTime : player.currentTime().seconds.rounded(),
            MPMediaItemPropertyPlaybackDuration : Int(song.durationInSeconds),
            MPNowPlayingInfoPropertyPlaybackQueueCount : queue.count,
            MPNowPlayingInfoPropertyPlaybackQueueIndex : currentIndex!,
            MPMediaItemPropertyArtwork : MPMediaItemArtwork(image: artwork),
            MPNowPlayingInfoPropertyPlaybackRate : Double(player.rate)
        ]
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = currentlyPlayingTrackInfo
    }
    
    //MARK: - Notification handlers & value observer
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath ?? "" {
        case #keyPath(AVPlayer.rate):
            notificationCenter.post(name: .CorePlayerStatusDidChange, object: nil)
        case #keyPath(AVPlayerItem.status):
            if player.currentItem!.status == .readyToPlay && shouldStart { play() }
        default: super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    func removePrivateObservers() {
        player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.rate))
        player.currentItem!.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        notificationCenter.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        notificationCenter.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: player.currentItem)
        if privateTimeObserver != nil {
            player.removeTimeObserver(privateTimeObserver!)
            privateTimeObserver = nil
        }
    }
    
    internal func audioSessionInterruptHandler(_ notif: Notification) {
        guard let typeRAW = notif.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSessionInterruptionType(rawValue: typeRAW)
            else { return }
        
        switch type {
        case .began:
            pause()
            notificationCenter.addObserver(self,
                                           selector: #selector(audioSessionInterruptHandler(_:)),
                                           name: .AVAudioSessionInterruption,
                                           object: nil)
        case .ended:
            guard let flagRAW = notif.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
                else { return }
            
            let flag = AVAudioSessionInterruptionOptions(rawValue: flagRAW)
            switch flag {
            case AVAudioSessionInterruptionOptions.shouldResume:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [unowned self] in
                    self.notificationCenter.removeObserver(self, name: .AVAudioSessionInterruption, object: nil)
                    self.play()
                }
            default: break
            }
        }
    }
    
    internal func routeChangeHandler(_ notif: Notification) {
        DispatchQueue.main.async {[unowned self] in
            guard let typeRAW = notif.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                let type = AVAudioSessionRouteChangeReason(rawValue: typeRAW)
                else { return }
            
            switch type {
            case .oldDeviceUnavailable: self.pause()
            default: break
            }
        }
    }
    
    internal func playerStoppedHandler(_ notif: Notification) {
        if publicTimeObserver != nil {
            player.removeTimeObserver(publicTimeObserver!)
            publicTimeObserver = nil
        }
        next(nil)
    }
    
    //MARK: - Timer ops
    
    func addTimeObserver(_ handler: @escaping ((CMTime) -> Void)) {
        let time = CMTime(seconds: 1.0, preferredTimescale: 1)
        publicTimeObserver = player.addPeriodicTimeObserver(forInterval: time, queue: .main, using: handler)
    }
    
    func removeTimeObserver() {
        if publicTimeObserver != nil {
            player.removeTimeObserver(publicTimeObserver!)
            publicTimeObserver = nil
        }
    }
    
}
