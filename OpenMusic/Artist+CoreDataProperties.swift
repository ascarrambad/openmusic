//
//  Artist+CoreDataProperties.swift
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

extension Artist {

    @NSManaged var coverImage: String?
    @NSManaged var name: String
    @NSManaged var thumbImage: String?
    
    @NSManaged var songs: NSSet?
    @NSManaged var albums: NSSet?

}
