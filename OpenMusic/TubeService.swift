//
//  YTService.swift
//  OpenMusic
//
//  Created by Matteo Riva on 17/10/2016.
//  Copyright © 2016 Matteo Riva. All rights reserved.
//

import Foundation

class TubeService: NSObject, ServiceProtocol {
    
    private typealias conCompletion = (Any?, Error?) -> Void
    
    private let sggUrl = "https://suggestqueries.google.com/complete/search"
    private let srcUrl = "https://www.googleapis.com/youtube/v3/search"
    private let lenUrl = "https://www.googleapis.com/youtube/v3/videos"
    private let dwnUrl = "https://www.youtubeinmp3.com/fetch/"
    
    private let srcKey = "AIzaSyDfJIrBbn9QGCSfntYEk8JpSKohHf1-RO4"
    
    private let downloadManager = DonwloadManager.shared
    
    static let shared = TubeService()
    
    var qualityFilter: ServiceQualityFilter {
        get {
            return ServiceQualityFilter(rawValue: UserDefaults.standard.string(forKey: "qualityFilter") ?? "all")!
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "qualityFilter")
        }
    }
    
    func retrieveSuggestions(for string: String, completion: @escaping ([String]?) -> ()) {
        let query = string.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        
        let params = ["client" : "firefox",
                      "q" : query]
        
        performGETConnection(url: sggUrl, with: params) { (data, _) in
            if let data = data as? [Any] {
                completion(data[1] as? [String])
            }
        }
        
    }
    
    func performSearch(for string: String, completion: @escaping ([EphimeralSong]?) -> ()) {
        let query = string.replacingOccurrences(of: " ", with: "+").addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let params = ["part" : "snippet",
                      "maxResults" : "50",
                      "type" : "video",
                      "safeSearch" : "none",
                      "key" : srcKey,
                      "q" : query]
        
        performGETConnection(url: srcUrl, with: params) { (data, _) in
            guard let data = data as? [String : Any],
                let res = data["items"] as? [[String : Any]]
            else {
                completion(nil)
                return
            }
            
            var songs: [EphimeralSong] = []
            
            for item in res {
                let snippet = item["snippet"] as! [String : Any]
                let id = (item["id"] as! [String : String])["videoId"]!
                let title = snippet["title"] as! String
                let artist = snippet["channelTitle"] as! String
                
                let raw: [String : String] = ["id" : id,
                                              "track" : title,
                                              "artist" : artist]
                
                let song = EphimeralSong(json: raw)
                songs.append(song)
            }
            completion(songs)
        }
        
    }
    
    func performDonwload(song: Song, with action: String, handler: @escaping (Float) -> Void, completion: @escaping (Error?) -> Void) {
        
        song.isDownloading = true
        
        let params = ["format" : "JSON",
                      "video" : "http://www.youtube.com/watch?v=\(song.id)",
                      "bitrate" : "1"]
        
        performGETConnection(url: dwnUrl, with: params) { [unowned self] (data, _) in
            if let data = data as? [String : String] {
                song.durationInSeconds = Int16(data["length"]!)!
                let min = (song.durationInSeconds/60).format(".2")
                let sec = (song.durationInSeconds%60).format(".2")
                song.duration = song.durationInSeconds == 0 ? "n/d" : "\(min):\(sec)"
                song.bitrate = Int16(data["bitrate"]!)!
                let dwnUrl = URL(string: data["link"]!)!
                self.downloadManager.donwload(song: song, with: dwnUrl, handler: handler, completion: completion)
            } else {
                song.isDownloading = false
                let error = NSError(domain: "it.teoriva.MeratiMusic",
                                    code: 1,
                                    userInfo: [NSLocalizedDescriptionKey : "corrupted_data".localized])
                completion(error)
            }
        }
    }
    
    //MARK: - Connections

    private func performGETConnection(url: String, with parameters: [String : String]?, completionHandler: @escaping conCompletion) {
        
        var urlString = url
        
        if let params = parameters {
            urlString += "?"
            for (key,value) in params {
                urlString += "\(key)=\(value)&"
            }
            urlString.characters.removeLast()
        }
        
        let url = URL(string: urlString)!
        
        URLSession.shared.dataTask(with: url, completionHandler: { (data, _, error) in
            var json: Any? = nil
            if data != nil {
                json = try? JSONSerialization.jsonObject(with: data!, options: [])
            }
            completionHandler(json, error)
        }).resume()
    }
}
