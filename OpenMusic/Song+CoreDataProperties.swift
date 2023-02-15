//
//  Song+CoreDataProperties.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 19/09/15.
//  Copyright © 2015 Matteo Riva. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Song {

    @NSManaged var bitrate: Int16
    @NSManaged var duration: String
    @NSManaged var durationInSeconds: Int16
    @NSManaged var id: String
    @NSManaged var isDownloaded: Bool
    @NSManaged var isDownloading: Bool
    @NSManaged var playCount: Int32
    @NSManaged var rating: Int16
    @NSManaged var title: String
    @NSManaged var artist: Artist?
    @NSManaged var album: Album?
    
    @NSManaged var playlist: NSSet?

}
