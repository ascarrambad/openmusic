//
//  SongsProvider.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 22/05/15.
//  Copyright (c) 2015 Matteo Riva. All rights reserved.
//

import CoreData
import Foundation

import MediaPlayer
import AERecord

class StoredMediaProvider: NSObject, MPPlayableContentDelegate {
    
    typealias completionSongType = ([Song]?, NSError?) -> ()
    typealias completionPlaylistType = ([[Playlist]]?, NSError?) -> ()
    
    override init() {
        super.init()
        MPPlayableContentManager.shared().delegate = self
    }
    
    static func fetchStoredSongs(withFilterKey filterKey: String?, orderKey: String, maxFetch: Int?, in context: NSManagedObjectContext, completionHandler: @escaping completionSongType) {
        context.perform() {
            let request = NSFetchRequest<Song>(entityName: "Song")
            var fetchString = "isDownloaded == true"
            if filterKey != nil { fetchString += " AND \(filterKey!)" }
            request.predicate = NSPredicate(format: fetchString)
            if filterKey == nil {
                request.sortDescriptors = [NSSortDescriptor(key: orderKey, ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))]
            } else {
                request.sortDescriptors = [NSSortDescriptor(key: orderKey, ascending: false)]
            }
            if maxFetch != nil { request.fetchLimit = maxFetch! }
            
            
            do {
                let results = try context.fetch(request)
                completionHandler(results,nil)
            } catch let error as NSError {
                completionHandler(nil, error)
            }
        }
    }
    
    static func fetchStoredPlaylists(in context: NSManagedObjectContext, completionHandler: @escaping completionPlaylistType) {
        context.perform() {
            
            do {
                let request = NSFetchRequest<Playlist>(entityName: "Playlist")
                request.predicate = NSPredicate(format: "name == %@ OR name == %@", "recently_added".localized, "most_played".localized)
                request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))]
                
                let system = try context.fetch(request)
                
                request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))]
                request.predicate = NSPredicate(format: "name != %@ AND name != %@", "recently_added".localized, "most_played".localized)
                let user = try context.fetch(request)
                
                completionHandler([system, user],nil)
            } catch let error as NSError {
                completionHandler(nil, error)
            }
        }
    }
    
    //MARK: - MPPlayableContentDelegate
    
    func playableContentManager(_ contentManager: MPPlayableContentManager, initializePlaybackQueueWithContentItems contentItems: [Any]?, completionHandler: @escaping (Error?) -> Void) {
        setupPlayback(completionHandler: completionHandler)
    }
    
    func playableContentManager(_ contentManager: MPPlayableContentManager, initializePlaybackQueueWithCompletionHandler completionHandler: @escaping (Error?) -> Void) {
        setupPlayback(completionHandler: completionHandler)
    }
    
    private func setupPlayback(completionHandler: @escaping (Error?) -> Void) {
        if !CorePlayer.shared.isPlaying && CorePlayer.shared.current == nil {
            StoredMediaProvider.fetchStoredSongs(withFilterKey: nil, orderKey: "title", maxFetch: nil, in: AERecord.Context.main) { (songs, error) in
                if let error = error {
                    completionHandler(error)
                } else if let songs = songs {
                    CorePlayer.shared.prepareForPlayback(with: songs, current: 0, shouldStart: false) { (success) in
                        completionHandler(nil)
                    }
                }
            }
        } else {
            completionHandler(nil)
        }
    }

}
