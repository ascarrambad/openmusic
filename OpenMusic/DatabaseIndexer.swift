//
//  DatabaseIndexer.swift
//  OpenMusic
//
//  Created by Matteo Riva on 08/09/2016.
//  Copyright © 2016 Matteo Riva. All rights reserved.
//

import Foundation
import MobileCoreServices
import CoreSpotlight
import AERecord
import CoreData

@available(iOS 9.0, *)
class DatabaseIndexer: NSObject, CSSearchableIndexDelegate {
    
    override init() {
        super.init()
        CSSearchableIndex.default().indexDelegate = self
    }
    
    static func indexSongs(_ songs: [Song], completionHandler: ((Error?) -> Void)?) {
        var items = [CSSearchableItem]()
        for song in songs {
            if song.isDownloaded {
                items.append(self.createSearchItem(withSong: song))
            }
        }
        CSSearchableIndex.default().indexSearchableItems(items,
                                                         completionHandler: completionHandler)
    }
    
    static func indexSong(_ song: Song, completionHandler: ((Error?) -> Void)?) {
        let item = createSearchItem(withSong: song)
        CSSearchableIndex.default().indexSearchableItems([item],
                                                         completionHandler: completionHandler)
    }
    
    static func deindexSong(_ song: Song, completionHandler: ((Error?) -> Void)?) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [song.id],
                                                          completionHandler: completionHandler)
    }
    
    private static func createSearchItem(withSong song: Song) -> CSSearchableItem {
        let attrs = CSSearchableItemAttributeSet(itemContentType: kUTTypeMP3 as String)
        attrs.title = song.title
        attrs.artist = song.artist?.name
        attrs.album = song.album?.name
        attrs.duration = NSNumber(value: song.durationInSeconds)
        attrs.playCount = NSNumber(value: song.playCount)
        attrs.audioBitRate = NSNumber(value: song.bitrate)
        attrs.url = song.fileURL
        attrs.thumbnailURL = song.album?.thumbImageLocalURL
        return CSSearchableItem(uniqueIdentifier: song.id, domainIdentifier: "it.teoriva.MeratiMusic.songs", attributeSet: attrs)
    }
    
    
    //MARK: - CSSearchableIndexDelegate
    
    func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void) {        AERecord.Context.background.perform {
            let fetch = NSFetchRequest<Song>(entityName: "Song")
            fetch.predicate = NSPredicate(format: "isDownloaded == true")
            let songs = AERecord.execute(fetchRequest: fetch, in: AERecord.Context.default)
            DatabaseIndexer.indexSongs(songs) { (_) in
                acknowledgementHandler()
            }
        }
    }
    
    func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexSearchableItemsWithIdentifiers identifiers: [String], acknowledgementHandler: @escaping () -> Void) {
        AERecord.Context.background.perform {
            let fetch = NSFetchRequest<Song>(entityName: "Song")
            fetch.predicate = NSPredicate(format: "id IN %@", identifiers)
            let songs = AERecord.execute(fetchRequest: fetch, in: AERecord.Context.default)
            DatabaseIndexer.indexSongs(songs) { (_) in
                acknowledgementHandler()
            }
        }
    }

}
