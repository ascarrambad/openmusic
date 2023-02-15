//
//  PleerService.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 24/05/15.
//  Copyright (c) 2015 Matteo Riva. All rights reserved.
//

import Foundation
import CoreData
import UIKit
import ACPDownload
import AERecord

class PleerService: NSObject, ServiceProtocol {
    
    private var token: String?
    private var tokenTimeOfExpiral: Date?
    private var isTokenValid: Bool {
        get {
            return (tokenTimeOfExpiral?.compare(Date()) == .orderedDescending)
        }
    }
    private var searchQuery: String!
    private let downloadManager = DonwloadManager.shared
    
    var qualityFilter: ServiceQualityFilter {
        get {
            return ServiceQualityFilter(rawValue: UserDefaults.standard.string(forKey: "qualityFilter") ?? "all")!
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "qualityFilter")
        }
    }
    
    //MARK: - Init
    
    static let shared = PleerService()
    
    override init() {
        super.init()
        retrieveToken {_ in }
    }
    
    //MARK: - Token
    
    private func retrieveToken(_ completion: @escaping ((Bool) -> ())) {
        let params = ["grant_type" : "client_credentials",
                      "client_id" : "311621",
                      "client_secret" : "RjlNjPUsmbd5MRjISbj6"]
        let url = URL(string: "http://api.pleer.com/token.php")!
        
        performPOSTConnection(with: url, parameters: params as [String : Any]) {[unowned self] (data, _, error) -> () in
            if error == nil {
                if let dict = (try? JSONSerialization.jsonObject(with: data!, options: [])) as? [String : Any] {
                    let interval: TimeInterval = dict["expires_in"] as! TimeInterval
                    self.tokenTimeOfExpiral = Date(timeIntervalSinceNow: interval)
                    self.token = (dict["access_token"] as! String)
                    completion(true)
                }
            } else {
                print(error!.localizedDescription)
                completion(false)
            }
        }
        
    }
    
    //MARK: - Suggestions
    
    func retrieveSuggestions(for string: String, completion: @escaping ([String]?) -> ()) {
        if token == nil || !isTokenValid {
            retrieveToken() {[unowned self] (success) -> () in
                if success {
                    self.retrieveSuggestions(for: string, withToken: self.token!, completion: completion)
                }
            }
        } else {
            retrieveSuggestions(for: string, withToken: token!, completion: completion)
        }
    }
    
    private func retrieveSuggestions(for string: String, withToken token: String, completion: @escaping ([String]?) -> ()) {
        
        let params: [String : String] = ["access_token" : token,
            "part" : string,
            "method" : "get_suggest"]
        let url = URL(string: "http://api.pleer.com/index.php")!
        
        performPOSTConnection(with: url, parameters: params as [String : Any]) { (data, _, error) -> () in
            if error == nil {
                if let dict = (try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)) as? [String : Any] {
                    completion(dict["suggest"] as? [String])
                } else {
                    completion(nil)
                }
            } else {
                completion(nil)
                print(error!.localizedDescription)
            }
        }
        
    }
    
    //MARK: - Search
    
    func performSearch(for string: String, completion: @escaping ([EphimeralSong]?) -> ()) {
        if token == nil || !isTokenValid {
            retrieveToken() { [unowned self] (success) in
                if success {
                    self.performSearch(for: string, with: self.token!, completion: completion)
                }
            }
        } else { performSearch(for: string, with: token!, completion: completion) }

    }
    
    private func performSearch(for string: String, with token: String, completion: @escaping ([EphimeralSong]?) -> ()) {
        
        let params: [String : String] = ["access_token" : token,
            "query" : string,
            "quality" : qualityFilter.rawValue,
            "page" : "1",
            "result_on_page" : "50",
            "method" : "tracks_search"]
        let url = URL(string: "http://api.pleer.com/index.php")!
        
        performPOSTConnection(with: url, parameters: params as [String : Any]) { (data, _, error) -> () in
            if error == nil {
                if let dict = (try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)) as? [String : Any] {
                    
                    var songs = [EphimeralSong]()
                    
                    if let tracks = dict["tracks"] as? [String : [String : Any]] {
                        for track in tracks {
                            let song = EphimeralSong(json: track.1)
                            songs.append(song)
                        }
                    }
                    completion(songs)
                    
                }
            } else {
                completion(nil)
                print(error!.localizedDescription)
            }
        }

    }
    
    //MARK: - Donwload
    
    func performDonwload(song: Song, with action: String, handler: @escaping (Float) -> Void, completion: @escaping (Error?) -> Void) {
        
        song.isDownloading = true
        
        if token == nil || !isTokenValid {
            retrieveToken() {[unowned self] (success) -> () in
                if success {
                    self.requestDownloadLink(of: song, with: action, handler: handler, completion: completion)
                }
            }
        } else { self.requestDownloadLink(of: song, with: action, handler: handler, completion: completion) }
    }
    
    private func requestDownloadLink(of song: Song, with action: String, handler: @escaping (Float) -> Void, completion: @escaping (Error?) -> Void) {
        let params = ["access_token" : token!,
            "track_id" : song.id,
            "reason" : action,
            "method" : "tracks_get_download_link"]
        let url = URL(string: "http://api.pleer.com/index.php")!
        performPOSTConnection(with: url, parameters: params as [String : Any], completion: { [unowned self] (data, _, error) -> () in
            if error == nil {
                guard let dict = (try? JSONSerialization.jsonObject(with: data!, options: [])) as? [String : Any],
                    let stringURL = dict["url"] as? String,
                    let finalURL = URL(string: stringURL)
                    else {
                        song.isDownloading = false
                        let error = NSError(domain: "it.teoriva.MeratiMusic",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey : "corrupted_data".localized])
                        completion(error)
                        return
                }
                
                if params["reason"] == "save" {
                    self.downloadManager.donwload(song: song, with: finalURL, handler: handler, completion: completion)
                }

            } else {
                print(error!.localizedDescription)
                completion(error)
            }
        })
    }
    
    //MARK: - Generics
    
    private func performPOSTConnection(with url: URL, parameters: [String : Any], completion: @escaping (Data?,URLResponse?,Error?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var paramString = ""
        for (key,value) in parameters {
            paramString += "\(key)=\(value)&"
        }
        let body = NSMutableData()
        body.append(paramString.data(using: String.Encoding.utf8, allowLossyConversion: false)!)
        
        request.httpBody = body as Data
        URLSession.shared.dataTask(with: request, completionHandler: completion).resume()
    }
    
}
