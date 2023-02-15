//
//  Album.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 01/02/16.
//  Copyright © 2016 Matteo Riva. All rights reserved.
//

import Foundation
import CoreData

enum AlbumType: String {
    case Compilation = "compilation"
    case Album = "album"
    case Single = "single"
}

class Album: NSManagedObject {
    
    convenience init(name: String, id: String, entity: NSEntityDescription, in context: NSManagedObjectContext) {
        self.init(entity: entity, insertInto: context)
        self.name = name
        self.id = id
    }
    
    class func create(withName name: String, id: String, in context: NSManagedObjectContext) -> Album? {
        
        let request = NSFetchRequest<Album>(entityName: "Album")
        request.predicate = NSPredicate(format: "id == %@", id)
        
        if let results = try? context.fetch(request) {
            if results.count == 1 {
                let album = results.first! as Album
                return album
            } else {
                if let entity =  NSEntityDescription.entity(forEntityName: "Album", in: context) {
                    let album = Album(name: name, id: id, entity: entity, in: context)
                    return album
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
            
            didAccessValue(forKey: "filteredSongSet")
            return filteredSongs
        }
    }
    
    override func prepareForDeletion() {
        
        if let songs = songs /*&& NSUserDefaults.standardUserDefaults().boolForKey("albumFix")*/ {
            for song in songs {
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
