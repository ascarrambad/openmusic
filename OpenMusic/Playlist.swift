//
//  Playlist.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 22/05/15.
//  Copyright (c) 2015 Matteo Riva. All rights reserved.
//

import Foundation
import CoreData
import UIKit

let PlaylistsNeedDisplay = NSNotification.Name(rawValue: "PlaylistsNeedDisplay")

class Playlist: NSManagedObject {
    
    var thumbImage: UIImage? {
        get {
            
            var imageArr: [UIImage] = []
            
            if songs.count > 3 {
                var i = 0
                while imageArr.count < 4 {
                    let song = songs.object(at: i) as! Song
                    
                    let image: UIImage
                    
                    if let path = song.thumbImageURL?.path {
                        image = UIImage(contentsOfFile: path)!.scaleKeepingRatio(toHeight: 30)
                    } else {
                        image = UIImage(named: "playlistPlaceholder")!
                    }
                    
                    imageArr.append(image)
                    
                    i += 1
                }
                
                let size = CGSize(width: 60, height: 60)
                UIGraphicsBeginImageContextWithOptions(size, true, 0)
                
                UIColor.white.setFill()
                
                let rect = CGRect(x: 0, y: 0, width: 60, height: 60)
                let rect0 = CGRect(x: 0, y: 0, width: 30, height: 30)
                let rect1 = CGRect(x: 30, y: 0, width: 30, height: 30)
                let rect2 = CGRect(x: 0, y: 30, width: 30, height: 30)
                let rect3 = CGRect(x: 30, y: 30, width: 30, height: 30)
                
                UIRectFill(rect)
                
                imageArr[0].draw(in: rect0, blendMode: .normal, alpha: 1)
                imageArr[1].draw(in: rect1, blendMode: .normal, alpha: 1)
                imageArr[2].draw(in: rect2, blendMode: .normal, alpha: 1)
                imageArr[3].draw(in: rect3, blendMode: .normal, alpha: 1)
                
                let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                return scaledImage
            } else {
                return nil
            }
            
        }
    }

    convenience init(name: String, songs: [Song]?, system: Bool, entity: NSEntityDescription, in context: NSManagedObjectContext) {
        self.init(entity: entity, insertInto: context)
        self.name = name
        self.system = system
        if songs != nil { self.songs = NSOrderedSet(array: songs!) }
    }
    
    class func create(withName name: String, songs: [Song], in context: NSManagedObjectContext) -> Playlist? {
        
        let request = NSFetchRequest<Playlist>(entityName: "Playlist")
        request.predicate = NSPredicate(format: "name == %@", name)
        
        if let results = try? context.fetch(request) {
            if results.count == 1 {
                return nil
            } else {
                if let entity =  NSEntityDescription.entity(forEntityName: "Playlist", in: context) {
                    let playlist = Playlist(name: name, songs: songs, system: false, entity: entity, in: context)
                    return playlist
                }
            }
        }
        return nil
    }
    
    func modify(withNewName newName: String, songs: [Song]) {
        name = newName
        self.songs = NSOrderedSet(array: songs)
    }
    
    class func createRecentlyAdded(withSong song: Song, in context: NSManagedObjectContext) -> Playlist? {
        
        let request = NSFetchRequest<Playlist>(entityName: "Playlist")
        request.predicate = NSPredicate(format: "name == %@", "recently_added".localized)
        
        if let results = try? context.fetch(request) {
            if results.count == 1 {
                if results.first!.songs.count >= 25 {
                    results.first!.add(song)
                    results.first!.removeLast()
                } else {
                    results.first!.add(song)
                }
                return results.first!
            } else {
                if let entity =  NSEntityDescription.entity(forEntityName: "Playlist", in: context) {
                    let playlist = Playlist(name: "recently_added".localized, songs: [song], system: true, entity: entity, in: context)
                    return playlist
                }
            }
        }
        return nil
    }
    
    class func createMostPlayed(in context: NSManagedObjectContext, completionHandler: @escaping (Playlist?) -> Void) {
        
        let request = NSFetchRequest<Playlist>(entityName: "Playlist")
        request.predicate = NSPredicate(format: "name == %@", "most_played".localized)
        
        if let results = try? context.fetch(request) {
            if results.count == 1 {
                StoredMediaProvider.fetchStoredSongs(withFilterKey: "playCount > 0", orderKey: "playCount", maxFetch: 25, in: context) { (songs, error) in
                    if error == nil {
                        results.first!.songs = NSOrderedSet(array: songs!)
                        completionHandler(results.first!)
                    } else {
                        completionHandler(nil)
                    }
                }
            } else if let entity = NSEntityDescription.entity(forEntityName: "Playlist", in: context) {
                let playlist = Playlist(name: "most_played".localized, songs: nil, system: true, entity: entity, in: context)
                StoredMediaProvider.fetchStoredSongs(withFilterKey: "playCount > 0", orderKey: "playCount", maxFetch: 25, in: context) { (songs, error) in
                    if error == nil {
                        playlist.songs = NSOrderedSet(array: songs!)
                        completionHandler(playlist)
                    } else {
                        completionHandler(nil)
                    }
                }
            }
        } else {
            completionHandler(nil)
        }
        
    }
    
    func remove(at index: Int) {
        let items = self.mutableOrderedSetValue(forKey: "songs")
        items.removeObject(at: index)
    }
    
    private func removeLast() {
        let items = self.mutableOrderedSetValue(forKey: "songs")
        items.removeObject(at: items.count-1)
    }
    
    private func add(_ song: Song) {
        let items = self.mutableOrderedSetValue(forKey: "songs")
        items.insert(song, at: 0)
    }

}
