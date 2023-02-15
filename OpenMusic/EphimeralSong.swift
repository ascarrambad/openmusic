//
//  EphimeralSong.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 20/06/16.
//  Copyright © 2016 Matteo Riva. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import AERecord

class EphimeralSong: NSObject {
    
    var bitrate: Int16
    var duration: String
    var durationInSeconds: Int16
    var id: String
    var title: String
    var artist: String
    
    var jsonData: [String : Any] {
        get {
            return ["id" : id,
                    "track" : title,
                    "artist" : artist,
                    "lenght" : "\(durationInSeconds)",
                    "bitrate" : "\(bitrate)"]
        }
    }
    var persistent: Song?
    
    required init(json: [String : Any]) {
        
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
        artist = artistString!.string
        title = titleString!.string
        if let lenght = json["lenght"] as? String {
            durationInSeconds = Int16(lenght)!
            let min = (durationInSeconds/60).format(".2")
            let sec = (durationInSeconds%60).format(".2")
            duration = durationInSeconds == 0 ? "n/d" : "\(min):\(sec)"
        } else {
            durationInSeconds = -1
            duration = ""
        }
        
        bitrate = Int16(json["bitrate"] as? String ?? "0") ?? 0
        
        self.persistent = Song.find(id: id, in: AERecord.Context.default)
        
        super.init()
    }
    
    func createPersistent(in context: NSManagedObjectContext, completion: @escaping (Song?) -> Void) {
        context.perform() { [unowned self] in
            self.persistent = Song.create(withJSON: self.jsonData, in: context)
            completion(self.persistent)
        }
    }

}
