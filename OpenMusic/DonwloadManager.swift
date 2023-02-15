//
//  DonwloadManager.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 19/06/16.
//  Copyright © 2016 Matteo Riva. All rights reserved.
//

import Foundation
import AERecord
import AVFoundation
import CoreSpotlight
import MobileCoreServices

class DonwloadManager: NSObject, URLSessionDownloadDelegate {
    
    static let shared = DonwloadManager()
    
    let notificationCenter = NotificationCenter.default

    private lazy var session: Foundation.URLSession = Foundation.URLSession(configuration: URLSessionConfiguration.background(withIdentifier: "songsDonwloader"), delegate: self, delegateQueue: nil)
    
    typealias completionBlock = (NSError?) -> Void
    typealias handlerBlock = (Float) -> Void
    
    func download(request: URLRequest, with infos: [String : String], handler: @escaping handlerBlock, completion: @escaping completionBlock) {
        
        AERecord.Context.background.perform { [weak self] in
            if let song = Song.create(withJSON: infos, in: AERecord.Context.default) {
                song.isDownloading = true
                self?.download(song: song, with: request, handler: handler, completion: completion)
            }
        }
        
    }
    
    func donwload(song: Song, with url: URL, handler: @escaping handlerBlock, completion: @escaping completionBlock) {
        let request = URLRequest(url: url)
        download(song: song, with: request, handler: handler, completion: completion)
    }
    
    private func download(song: Song, with request: URLRequest, handler: @escaping handlerBlock, completion: @escaping completionBlock) {
        
        let task = session.downloadTask(with: request)
        
        notificationCenter.addObserver(forName: NSNotification.Name(rawValue: "PercentageDownloadChange"), object: task, queue: .main) { (notif) -> Void in
            let completion = notif.userInfo!["completion"] as! Float
            handler(completion)
        }
        
        notificationCenter.addObserver(forName: NSNotification.Name(rawValue: "SessionDidEndWriteFileToURL"), object: task, queue: nil) { [unowned self] (notif) -> Void in
            let path = notif.userInfo!["path"] as! URL
            
            let docDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let localURL = docDirectoryURL.appendingPathComponent(song.id).appendingPathExtension("mp3")
            print(localURL)
            
            if FileManager.default.fileExists(atPath: localURL.path) {
                try? FileManager.default.removeItem(atPath: localURL.path)
            }
            
            do {
                try FileManager.default.copyItem(atPath: path.path, toPath: localURL.path)
                
                completion(nil)
                
                AERecord.Context.background.perform() {[weak self] in
                    
                    if song.duration == "n/d" {
                        let info = self?.getBitRateAndDurationOfSong(at: localURL)
                        let bitrate = info!.0
                        let duration = info!.1
                        
                        song.bitrate = Int16(bitrate/1000)
                        song.durationInSeconds = Int16(duration)
                        let min = (song.durationInSeconds/60).format(".2")
                        let sec = (song.durationInSeconds%60).format(".2")
                        song.duration = song.durationInSeconds == 0 ? "n/d" : "\(min):\(sec)"
                    }
                    
                    song.isDownloading = false
                    song.isDownloaded = true
                    song.artist!.downloadArtwork()
                    song.fetchAlbumInfos()
                    _ = Playlist.createRecentlyAdded(withSong: song, in: AERecord.Context.default)
                    AERecord.save()
                    
                    DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 6) {
                        if #available(iOS 9.0, *) {
                            DatabaseIndexer.indexSong(song, completionHandler: nil)
                        }
                    }
                }
            } catch let error as NSError {
                print(error.localizedDescription)
            }
            
            self.notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: "SessionDidEndWriteFileToURL"), object: task)
            self.notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: "PercentageDownloadChange"), object: task)
        }
        
        notificationCenter.addObserver(forName: NSNotification.Name(rawValue: "SessionDidEndWithError"), object: task, queue: nil) {[unowned self] (notif) -> Void in
            let error = notif.userInfo!["error"] as! NSError
            song.isDownloading = false
            completion(error)
            print(error.localizedDescription)
            self.notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: "SessionDidEndWriteFileToURL"), object: task)
            self.notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: "PercentageDownloadChange"), object: task)
            self.notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: "SessionDidEndWithError"), object: task)
        }
        
        task.resume()
        
    }
    
    //MARK: - NSURLSessionDonwloadDelegate
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let completion = Float(Float(totalBytesWritten) / Float(totalBytesExpectedToWrite))
        let infos: [String : Any] = ["completion" : completion as Any]
        notificationCenter.post(name: Notification.Name(rawValue: "PercentageDownloadChange"), object: downloadTask, userInfo: infos)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        let response = downloadTask.response as! HTTPURLResponse
        
        if response.statusCode == 200 {
            let infos: [String : Any] = ["path" : location as Any]
            notificationCenter.post(name: Notification.Name(rawValue: "SessionDidEndWriteFileToURL"), object: downloadTask, userInfo: infos)
        } else {
            let error = NSError(domain: "it.teoriva.MeratiMusic", code: 1, userInfo: [NSLocalizedDescriptionKey : "corrupted_data".localized])
            let infos: [String : Any] = ["error" : error]
            notificationCenter.post(name: Notification.Name(rawValue: "SessionDidEndWithError"), object: downloadTask, userInfo: infos)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            let infos: [String : Any] = ["error" : error as Any]
            notificationCenter.post(name: Notification.Name(rawValue: "SessionDidEndWithError"), object: task, userInfo: infos)
        }
    }
    
    //MARK: - Retrieve info on files when not available
    
    func getBitRateAndDurationOfSong(at url: URL) -> (Int,Int) {
        var sourceAudioFile: ExtAudioFileRef? = nil
        ExtAudioFileOpenURL( url as CFURL, &sourceAudioFile );
    
        let audioFileId = getAudioFileID(sourceAudioFile!)
        let info = getBitRateAndDuration(audioFileId)
        return (Int(info.0),Int(info.1))
    }
    
    func getAudioFileID(_ fileRef: ExtAudioFileRef) -> AudioFileID {
        var status: OSStatus
        var result: AudioFileID? = nil
    
        var size = UInt32(MemoryLayout<AudioFileID>.size)
        status = ExtAudioFileGetProperty(fileRef, kExtAudioFileProperty_AudioFile, &size, &result)
        assert(status == noErr)
    
        return result!;
    }
    
    func getBitRateAndDuration(_ audioFileId: AudioFileID)-> (UInt32, TimeInterval) {
        var status: OSStatus
        var bitrate: UInt32 = 0
        var duration: TimeInterval = 0
        
        var sizeBitrate = UInt32(MemoryLayout<UInt32>.size)
        var sizeDuration = UInt32(MemoryLayout<TimeInterval>.size)
        
        status = AudioFileGetProperty(audioFileId, kAudioFilePropertyBitRate, &sizeBitrate, &bitrate)
        assert(status == noErr)
        
        status = AudioFileGetProperty(audioFileId, kAudioFilePropertyEstimatedDuration, &sizeDuration, &duration)
        assert(status == noErr)
    
        return (bitrate,duration)
    }
    
}
