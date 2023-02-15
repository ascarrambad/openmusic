//
//  Album+CoreDataProperties.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 01/02/16.
//  Copyright © 2016 Matteo Riva. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Album {

    @NSManaged var name: String
    @NSManaged var coverImage: String?
    @NSManaged var thumbImage: String?
    @NSManaged var id: String
    
    @NSManaged var songs: NSSet?
    @NSManaged var artist: Artist?

}
