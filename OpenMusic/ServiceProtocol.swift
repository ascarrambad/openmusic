//
//  ServiceProtocol.swift
//  OpenMusic
//
//  Created by Matteo Riva on 17/10/2016.
//  Copyright © 2016 Matteo Riva. All rights reserved.
//

import Foundation

enum ServiceQualityFilter: String {
    case all = "all"
    case high = "best"
    case medium = "good"
    case low = "bad"
}

protocol ServiceProtocol {
    
    var qualityFilter: ServiceQualityFilter {get set}
    
    func retrieveSuggestions(for string: String, completion: @escaping ([String]?) -> ())
    func performSearch(for string: String, completion: @escaping ([EphimeralSong]?) -> ())
    func performDonwload(song: Song, with action: String, handler: @escaping (Float) -> Void, completion: @escaping (Error?) -> Void)
}
