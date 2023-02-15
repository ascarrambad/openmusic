//
//  Song.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 27/05/15.
//  Copyright (c) 2015 Matteo Riva. All rights reserved.
//

import Foundation
import CoreData

let SongHasBeenDeletedNotification = NSNotification.Name("SongHasBeenDeletedNotification")
let SongHasBeenDeletedKey = NSNotification.Name("SongHasBeenDeletedKey")

class Song: NSManagedObject {
    
    let notificationCenter = NotificationCenter.default

    convenience init(json: [String : Any], entity: NSEntityDescription, in context: NSManagedObjectContext) {
        self.init(entity: entity, insertInto: context)
        
        let titleRAW = json["track"] as? String ?? "no_title".localized
        let artistRAW = json["artist"] as? String ?? "unknown_artist".localized
        
        let ops = [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                   NSCharacterEncodingDocumentAttribute: String.Encoding.utf8.rawValue] as [String : Any]
        
        let artistString = try? NSAttributedString(data: artistRAW.data(using: .utf8)!,
                                                   options: ops,
                                                   documentAttributes: nil)
        
        let titleString = try? NSAttributedString(data: titleRAW.data(using: .utf8)!,
                                options: ops,
                                documentAttributes: nil)
        
        
        id = json["id"] as! String
        artist = Artist.create(withName: artistString!.string, in: context)!
        title = titleString!.string
        durationInSeconds = Int16(json["lenght"] as? String ?? "0") ?? 0
        let min = (durationInSeconds/60).format(".2")
        let sec = (durationInSeconds%60).format(".2")
        duration = durationInSeconds == 0 ? "n/d" : "\(min):\(sec)"
        bitrate = Int16(json["bitrate"] as? String ?? "0") ?? 0
    }
    
    class func create(withJSON json: [String : Any], in context: NSManagedObjectContext) -> Song? {
        
        if json["id"] as? String != "" && json["artist"] as? String != "" && json["track"] as? String != "" {
            let id = json["id"] as! String
            
            if let song = find(id: id, in: context) {
                return song
            } else if let entity = NSEntityDescription.entity(forEntityName: "Song", in: context) {
                let song = Song(json: json, entity: entity, in: context)
                return song
            }
        }
        return nil
        
    }
    
    class func find(id: String, in context: NSManagedObjectContext) -> Song? {
        let request = NSFetchRequest<Song>(entityName: "Song")
        request.predicate = NSPredicate(format: "id == %@", id)

        return (try? context.fetch(request))?.first
    }
    
    func addSkipBackupAttributeToItem(at URL: URL) -> Bool {
        
        let success: Bool
        do {
            try (URL as NSURL).setResourceValue(true, forKey: URLResourceKey.isExcludedFromBackupKey)
            success = true
        } catch let error as NSError {
            print("Error excluding \(URL.lastPathComponent) from backup \(error)")
            success = false
        }
        
        return success
    }
    
    var firstLetter: String {
        get {
            willAccessValue(forKey: "firstLetter")
            let firstLetter = title.characters.first!
            didAccessValue(forKey: "firstLetter")
            if "a"..."z" ~= firstLetter || "A"..."Z" ~= firstLetter {
                return String(firstLetter).uppercased()
            } else {
                return "#"
            }
        }
    }
    
    var fileURL: URL? {
        get {
            willAccessValue(forKey: "fileURL")
            let docDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            didAccessValue(forKey: "fileURL")
            let fileName = self.id + ".mp3"
            return isDownloaded ? docDirectoryURL.appendingPathComponent(fileName) : nil
        }
    }
    
    var coverImageURL: URL? {
        get {
            willAccessValue(forKey: "coverImageURL")
            let url = album?.coverImageLocalURL ?? artist?.coverImageLocalURL
            didAccessValue(forKey: "coverImageURL")
            return url
        }
    }
    
    var thumbImageURL: URL? {
        get {
            willAccessValue(forKey: "thumbImageURL")
            let url = album?.thumbImageLocalURL ?? artist?.thumbImageLocalURL
            didAccessValue(forKey: "thumbImageURL")
            return url
        }
    }
    
    class func fetchSong(withID ID: String, and context: NSManagedObjectContext) -> Song? {
        let request = NSFetchRequest<Song>(entityName: "Song")
        request.predicate = NSPredicate(format: "id == %@", ID)
        
        if let results = try? context.fetch(request) {
            if results.count == 1 {
                return results.first
            }
        }
        return nil
    }
    
    func fetchAlbumInfos() {
        
        if let artistName = artist?.name.shortenArtistName() {
            
            var searchString = artistName.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)!
            let htmlTitle = title.shortenArtistName().addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)!
            
            searchString = searchString.replacingOccurrences(of: "%20", with: "+") + "+" + htmlTitle.replacingOccurrences(of: "%20", with: "+")
            
            print(searchString)
            
            let url = URL(string: "https://api.spotify.com/v1/search?q=\(searchString)&type=track")!
            URLSession.shared.dataTask(with: url, completionHandler: {[unowned self] (data, _, error) -> Void in
                if error == nil {
                    if let dict =  (try? JSONSerialization.jsonObject(with: data!, options: [])) as? [String : Any] {
                        if let albumDict = (dict["tracks"] as? [String : Any])?["items"] as? [[String : Any]] {
                            
                            var filtered = albumDict.filter({ (item) -> Bool in
                                guard let album = item["album"] as? [String : Any],
                                    let albumType = album["album_type"] as? String,
                                    let artist = (item["artists"] as? [[String : Any]])?.first,
                                    let artistName2 = artist["name"] as? String
                                    else { return false }
                                return albumType == "album" && (artistName2 == artistName || artistName2.contains(artistName))
                            }).first?["album"]
                            
                            if filtered == nil {
                                filtered = albumDict.filter({ (item) -> Bool in
                                    guard let album = item["album"] as? [String : Any],
                                        let albumType = album["album_type"] as? String,
                                        let artist = (item["artists"] as? [[String : Any]])?.first,
                                        let artistName2 = artist["name"] as? String
                                        else { return false }
                                    return albumType == "single" && (artistName2 == artistName || artistName2.contains(artistName))
                                }).first?["album"]
                            }
                            
                            if filtered == nil {
                                filtered = albumDict.filter({ (item) -> Bool in
                                    guard let album = item["album"] as? [String : Any],
                                        let albumType = album["album_type"] as? String,
                                        let artist = (item["artists"] as? [[String : Any]])?.first,
                                        let artistName2 = artist["name"] as? String
                                        else { return false }
                                    return albumType == "compilation" && (artistName2 == artistName || artistName2.contains(artistName))
                                }).first?["album"]
                            }
                            
                            if let albumD = filtered as? [String : Any] {
                                let albumName = albumD["name"] as! String
                                let albumID = albumD["id"] as! String
                                
                                let album = Album.create(withName: albumName, id: albumID, in: self.managedObjectContext!)!
                                
                                //album.hasDownloadedSongs = true
                                
                                self.album = album
                                
                                self.artist?.add(album)
                                
                                try? self.managedObjectContext?.save()
                                
                                guard let imageDict = albumD["images"] as? [[String : Any]] else {
                                    return
                                }
                                
                                if album.coverImage == nil {
                                    if let bigImage = imageDict.first?["url"] as? String {
                                        URLSession.shared.downloadTask(with: URL(string: bigImage)!, completionHandler: {[unowned self] (path, _, error) -> Void in
                                            if error == nil {
                                                let docDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                                                let localURL = docDirectoryURL.appendingPathComponent(path!.lastPathComponent)
                                                
                                                if FileManager.default.fileExists(atPath: localURL.path) {
                                                    try? FileManager.default.removeItem(atPath: localURL.path)
                                                }
                                                
                                                do {
                                                    try FileManager.default.copyItem(atPath: path!.path, toPath: localURL.path)
                                                    album.coverImage = path!.lastPathComponent
                                                    self.managedObjectContext?.perform(){
                                                        try? self.managedObjectContext?.save()
                                                    }
                                                } catch let error as NSError {
                                                    print(error.localizedDescription)
                                                }
                                            }
                                        }).resume()
                                    }
                                }
                                
                                var index: Int?
                                
                                if imageDict.count > 3 {
                                    index = imageDict.count - 3
                                } else if imageDict.count > 2 {
                                    index = imageDict.count - 2
                                } else if imageDict.count > 1 {
                                    index = imageDict.count - 1
                                }
                                
                                if index != nil && album.thumbImage == nil {
                                    if let smallImage = imageDict[index!]["url"] as? String {
                                        URLSession.shared.downloadTask(with: URL(string: smallImage)!, completionHandler: {[unowned self] (path, _, error) -> Void in
                                            if error == nil {
                                                let docDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                                                let localURL = docDirectoryURL.appendingPathComponent(path!.lastPathComponent)
                                                
                                                if FileManager.default.fileExists(atPath: localURL.path) {
                                                    try? FileManager.default.removeItem(atPath: localURL.path)
                                                }
                                                
                                                do {
                                                    try FileManager.default.copyItem(atPath: path!.path, toPath: localURL.path)
                                                    album.thumbImage = path!.lastPathComponent
                                                    self.managedObjectContext?.perform(){
                                                        try? self.managedObjectContext?.save()
                                                    }
                                                } catch let error as NSError {
                                                    print(error.localizedDescription)
                                                }
                                            }
                                        }).resume()
                                    }
                                }
                            }
                        }
                    }
                }
            }).resume()
        }
    }
    
    override func prepareForDeletion() {
        
        notificationCenter.post(name: SongHasBeenDeletedNotification, object: nil, userInfo: [SongHasBeenDeletedKey : self])
        
        if fileURL != nil {
            try? FileManager.default.removeItem(atPath: fileURL!.path)
        }

        notificationCenter.post(name: PlaylistsNeedDisplay, object: nil)
        
        if #available(iOS 9.0, *) {
            DatabaseIndexer.deindexSong(self, completionHandler: nil)
        }
        
        super.prepareForDeletion()
    }

}
