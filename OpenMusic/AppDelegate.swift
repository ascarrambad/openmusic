//
//  AppDelegate.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 22/05/15.
//  Copyright (c) 2015 Matteo Riva. All rights reserved.
//

import UIKit
import CoreData
import AVFoundation
import Foundation

import Fabric
import Crashlytics
import AERecord
import CoreSpotlight
import Firebase

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    private var databaseIndexer: Any?
    private let storedMediaProvider = StoredMediaProvider()
    
    let notificationCenter = NotificationCenter.default
    let corePlayer = CorePlayer.shared

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        
        if #available(iOS 9.0, *) {
            databaseIndexer = DatabaseIndexer()
        }
        
        Fabric.with([Crashlytics.self()])
        FIRApp.configure()
        
        let modelURL = Bundle.main.url(forResource: "OpenMusic", withExtension: "momd")!
        let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)!
        
        let storeURL = URL.URLForPersistentStore(.persistent, containerGroup: nil).appendingPathComponent("OpenMusic.sqlite")
        let options = [NSMigratePersistentStoresAutomaticallyOption : true,
                       NSInferMappingModelAutomaticallyOption : true]
        
        try? AERecord.loadCoreDataStack(managedObjectModel: managedObjectModel, storeType: NSSQLiteStoreType, configuration: nil, storeURL: storeURL, options: options)
        
        UIApplication.shared.setStatusBarStyle(.lightContent, animated: true)
        UINavigationBar.appearance().tintColor = UIColor.white
        
        AERecord.Context.background.perform() {
            let pred1 = NSPredicate(format: "isDownloaded == false")
            Song.deleteAll(with: pred1)
            
            let pred2 = NSPredicate(format: "ANY songs.isDownloaded == false")
            Artist.deleteAll(with: pred2)
            Album.deleteAll(with: pred2)
            
            AERecord.save()
        }
        
        if !UserDefaults.standard.bool(forKey: "implementIndex") {
            AERecord.Context.background.perform() {
                let request = NSFetchRequest<Song>(entityName: "Song")
                request.predicate = NSPredicate(format: "isDownloaded == true")
                let songs = AERecord.execute(fetchRequest: request)
                if #available(iOS 9.0, *) {
                    DatabaseIndexer.indexSongs(songs, completionHandler: nil)
                }
                UserDefaults.standard.set(true, forKey: "implementIndex")
            }
        }
        
        return true
    }
    
    @available(iOS 9.0, *)
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        switch TouchActions(rawValue: shortcutItem.type)! {
        case .findSong:
            if let viewController = window?.rootViewController as? UITabBarController {
                viewController.selectedIndex = 4
                completionHandler(true)
            }
        case .playFavorites:
            Playlist.createMostPlayed(in: AERecord.Context.main) { [unowned self] (playlist) -> Void in
                
                guard let songs = playlist?.songs.array as? [Song]
                    else { completionHandler(false); return }
                
                if songs.count > 0 {
                    self.corePlayer.reset(endingAudioSession: false)
                    self.corePlayer.prepareForPlayback(with: songs, current: 0, shouldStart: true) { [unowned self] (success) -> Void in
                        if success {
                            DispatchQueue.main.async { [unowned self] in
                                let nowPlayingNav = storyboard.instantiateViewController(withIdentifier: "nowPlaying") as! UINavigationController
                                let nowPlayingView = nowPlayingNav.viewControllers.first as! PlayerViewController
                                nowPlayingView.isNowPlaying = true
                                self.window?.rootViewController?.present(nowPlayingNav, animated: true, completion: nil)
                            }
                        }
                        completionHandler(success)
                    }
                } else {
                    completionHandler(false)
                }
            }
            
        case .shuffleAll:
            StoredMediaProvider.fetchStoredSongs(withFilterKey: nil, orderKey: "title", maxFetch: 200, in: AERecord.Context.main) {[unowned self] (songs, error) in
                if error == nil && songs?.count ?? 0 > 0 {
                    self.corePlayer.reset(endingAudioSession: false)
                    let startIndex = Int(arc4random_uniform(UInt32(songs!.count-1)))
                    self.corePlayer.prepareForPlayback(with: songs!, current: startIndex, shouldStart: true) {[unowned self] (success) in
                        if success {
                            DispatchQueue.main.async { [unowned self] in
                                self.corePlayer.isShuffled = true
                                let nowPlayingNav = storyboard.instantiateViewController(withIdentifier: "nowPlaying") as! UINavigationController
                                let nowPlayingView = nowPlayingNav.viewControllers.first as! PlayerViewController
                                nowPlayingView.isNowPlaying = true
                                self.window?.rootViewController?.present(nowPlayingNav, animated: true, completion: nil)
                            }
                        }
                        completionHandler(success)
                    }
                } else {
                    completionHandler(false)
                }
            }
        }
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        if #available(iOS 9.0, *) {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if userActivity.activityType == CSSearchableItemActionType {
                if let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                    StoredMediaProvider.fetchStoredSongs(withFilterKey: nil, orderKey: "title", maxFetch: 200, in: AERecord.Context.main) {[unowned self] (songs, error) in
                        if error == nil && songs?.count ?? 0 > 0 {
                            self.corePlayer.reset(endingAudioSession: false)
                            let startIndex = songs!.index { $0.id == uniqueIdentifier }
                            self.corePlayer.prepareForPlayback(with: songs!, current: startIndex!, shouldStart: true) {[unowned self] (success) in
                                if success {
                                    DispatchQueue.main.async { [unowned self] in
                                        let nowPlayingView = storyboard.instantiateViewController(withIdentifier: "nowPlaying") as! UINavigationController
                                        (nowPlayingView.viewControllers.first as! PlayerViewController).isNowPlaying = true
                                        self.window?.rootViewController?.present(nowPlayingView, animated: true, completion: nil)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            return true
        } else {
            return false
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        notificationCenter.post(name: .AppStatusDidChange, object: nil, userInfo: ["status" : 0])
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        notificationCenter.post(name: .AppStatusDidChange, object: nil, userInfo: ["status" : 1])
    }
    
    func application(_ application: UIApplication, shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplicationExtensionPointIdentifier) -> Bool {
        return !(extensionPointIdentifier == .keyboard)
    }

}
