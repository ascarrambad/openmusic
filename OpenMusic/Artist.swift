//
//  Artist.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 27/05/15.
//  Copyright (c) 2015 Matteo Riva. All rights reserved.
//

import Foundation
import CoreData

class Artist: NSManagedObject {

    convenience init(name: String, entity: NSEntityDescription, in context: NSManagedObjectContext) {
        self.init(entity: entity, insertInto: context)
        self.name = name
    }
    
    
    class func create(withName name: String, in context: NSManagedObjectContext) -> Artist? {
        
        let request = NSFetchRequest<Artist>(entityName: "Artist")
        request.predicate = NSPredicate(format: "name == %@", name)
        
        if let results = try? context.fetch(request) {
            if results.count == 1 {
                let artist = results.first! as Artist
                return artist
            } else {
                if let entity =  NSEntityDescription.entity(forEntityName: "Artist", in: context) {
                    let artist = Artist(name: name, entity: entity, in: context)
                    return artist
                }
            }
        }
        return nil
    }
    
    var firstLetter: String {
        get {
            willAccessValue(forKey: "firstLetter")
            let firstLetter = name.characters.first! 
            didAccessValue(forKey: "firstLetter")
            if "a"..."z" ~= firstLetter || "A"..."Z" ~= firstLetter {
                return String(firstLetter).uppercased()
            } else {
                return "#"
            }
        }
    }
    
    var coverImageLocalURL: URL? {
        get {
            willAccessValue(forKey: "coverImageLocalURL")
            let docDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            didAccessValue(forKey: "coverImageLocalURL")
            return coverImage != nil ? docDirectoryURL.appendingPathComponent(coverImage!) : nil
        }
    }
    
    var thumbImageLocalURL: URL? {
        get {
            willAccessValue(forKey: "thumbImageLocalURL")
            let docDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            didAccessValue(forKey: "thumbImageLocalURL")
            return thumbImage != nil ? docDirectoryURL.appendingPathComponent(thumbImage!) : nil
        }
    }
    
    var filteredSongSet: [Song] {
        get {
            willAccessValue(forKey: "filteredSongSet")
            
            let filteredSongs = songs!.filter {
                return ($0 as! Song).isDownloaded
            } as! [Song]
            let sortedSongs = filteredSongs.sorted {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == ComparisonResult.orderedAscending
            }
            
            didAccessValue(forKey: "filteredSongSet")
            return sortedSongs
        }
    }
    
    func add(_ album: Album) {
        let albums = self.mutableSetValue(forKey: "albums")
        albums.add(album)
    }
    
    func downloadArtwork() {
        let searchString = name.shortenArtistName().addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)!.replacingOccurrences(of: "%20", with: "+", options: [], range: nil)
        print(searchString)
        let url = URL(string: "https://api.spotify.com/v1/search?q=\(searchString)&type=artist&limit=1&market=US")!
        URLSession.shared.dataTask(with: url, completionHandler: {[unowned self] (data, _, error) -> Void in
            if error == nil {
                if let dict =  (try? JSONSerialization.jsonObject(with: data!, options: [])) as? [String : Any] {
                    if let imageDict = (((dict["artists"] as? [String : Any])?["items"] as? [Any])?.first as? [String : Any])?["images"] as? [[String : Any]] {
                        
                        if self.coverImage == nil {
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
                                            self.coverImage = path!.lastPathComponent
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
                        
                        if index != nil && self.thumbImage == nil {
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
                                            self.thumbImage = path!.lastPathComponent
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
        }).resume()
    }
    
    override func prepareForDeletion() {
        
        if songs != nil {
            for song in songs! {
                managedObjectContext!.delete(song as! Song)
            }
        }
        
        if coverImageLocalURL != nil {
            try? FileManager.default.removeItem(atPath: coverImageLocalURL!.path)
        }
        
        if thumbImageLocalURL != nil {
            try? FileManager.default.removeItem(atPath: thumbImageLocalURL!.path)
        }
        
        super.prepareForDeletion()
    }
    
}

extension String {
    func shortenArtistName() -> String {
        let scanner = Scanner(string: self)
        var tmp: NSString?
        var finalString = ""
        while scanner.scanUpTo(" ", into: &tmp) && tmp!.lowercased != "feat." && tmp!.lowercased != "feat" && tmp!.lowercased != "featuring" && tmp!.lowercased != "(feat." {
            finalString += (tmp as! String) + " "
        }
        
        return finalString.isEmpty ? self : finalString.substring(to: finalString.index(before: finalString.endIndex))
    }
}
