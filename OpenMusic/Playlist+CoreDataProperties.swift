//
//  Playlist+CoreDataProperties.swift
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

extension Playlist {

    @NSManaged var name: String
    @NSManaged var system: Bool
    
    @NSManaged var songs: NSOrderedSet

}
