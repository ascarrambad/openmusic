//
//  SongsTableViewController.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 22/05/15.
//  Copyright (c) 2015 Matteo Riva. All rights reserved.
//

import UIKit
import AVFoundation
import NAKPlaybackIndicatorView
import AERecord
import CoreData

enum SongListType {
    case artistSongs
    case albumSongs
    case playlistSongs
}

class DetailSongsTableViewController: UITableViewController, UIViewControllerPreviewingDelegate {
    
    private var listType: SongListType!
    private var playlist: Playlist?
    private var artist: Artist?
    private var album: Album?
    
    let notificationCenter = NotificationCenter.default
    let corePlayer = CorePlayer.shared
    
    private var songs: [Song] {
        get {
            switch listType! {
            case .artistSongs: return artist!.filteredSongSet
            case .albumSongs: return album!.filteredSongSet
            case .playlistSongs: return playlist!.songs.array as! [Song]
            }
        }
        
        set {
            switch listType! {
            case .artistSongs: artist!.songs = NSSet(array: newValue)
            case .albumSongs: album!.songs = NSSet(array: newValue)
            case .playlistSongs: playlist!.songs = NSOrderedSet(array: newValue)
            }
        }
    }
    
    private var isPlaylist: Bool {
        get {
            return listType == .playlistSongs
        }
    }
    
    func setupSongs(_ container: NSManagedObject, type: SongListType) {
        self.listType = type
        switch type {
        case .artistSongs: self.artist = (container as! Artist)
        case .albumSongs: self.album = (container as! Album)
        case .playlistSongs: self.playlist = (container as! Playlist)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        switch listType! {
        case .playlistSongs:
            if playlist?.name.lowercased() != "recently_added".localized.lowercased() && playlist?.name.lowercased() != "most_played".localized.lowercased() {
                navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(DetailSongsTableViewController.editPlaylistAction))
                notificationCenter.addObserver(forName: PlaylistsNeedDisplay, object: nil, queue: OperationQueue.main) {[weak self] (notif) -> Void in
                    self?.tableView.reloadData()
                }
            }
        default: break
        }
        
        if #available(iOS 9.0, *) {
            if traitCollection.forceTouchCapability == .available {
                registerForPreviewing(with: self, sourceView: view)
            }
        }
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
    
    //MARK: - Actions
    
    func editPlaylistAction() {
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let actionReorder = UIAlertAction(title: "reorder_button".localized, style: .default) {[weak self] (_) in
            self?.setEditing(true, animated: true)
            self?.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(DetailSongsTableViewController.doneReorderingAction))
        }
        
        let actionEdit = UIAlertAction(title: "edit_button".localized, style: .default) {[weak self] (_) in
            self?.performSegue(withIdentifier: "editPlaylistSegue", sender: self)
        }
        
        let actionCancel = UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil)
        
        alert.addAction(actionReorder)
        alert.addAction(actionEdit)
        alert.addAction(actionCancel)
        
        present(alert, animated: true, completion: nil)
        
    }
    
    func doneReorderingAction() {
        self.setEditing(false, animated: true)
        tableView.reloadData()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(DetailSongsTableViewController.editPlaylistAction))
    }

    // MARK: - TableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songs.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let reuseID: String
        switch listType! {
        case .playlistSongs: reuseID = "songP"
        default: reuseID = "song"
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseID, for: indexPath) as! SongTableViewCell
        
        let song = songs[(indexPath as NSIndexPath).row]
        cell.displaySongInfos(song)
        if isPlaylist {
            cell.number!.text = "\((indexPath as NSIndexPath).row+1)"
        }
        

        return cell
    }
    
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return listType == .playlistSongs ? !playlist!.system : true
    }
    
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return listType == .playlistSongs ? !playlist!.system : false
    }
    
    //MARK: - TableViewDelegate
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            switch listType! {
            case .playlistSongs:
                playlist?.remove(at: indexPath.row)
                if songs.count == 0 {
                    playlist?.managedObjectContext?.delete(playlist!)
                    _ = self.navigationController?.popViewController(animated: true)
                }
            case .artistSongs:
                let song = songs.remove(at: indexPath.row)
                song.managedObjectContext?.delete(song)
                if songs.count == 0 {
                    artist?.managedObjectContext?.delete(artist!)
                    _ = self.navigationController?.popViewController(animated: true)
                }
            case .albumSongs:
                let song = songs.remove(at: indexPath.row)
                song.managedObjectContext?.delete(song)
                if songs.count == 0 {
                    album?.managedObjectContext?.delete(album!)
                    _ = self.navigationController?.popViewController(animated: true)
                }
            }
            AERecord.save()
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        
        guard let mutableSongs = playlist?.songs as? NSMutableOrderedSet
            else { return }
        
        
        let indexSet = IndexSet(integer: sourceIndexPath.row)
        mutableSongs.moveObjects(at: indexSet, to: destinationIndexPath.row)
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if listType == .playlistSongs {
            if let cell = cell as? SongTableViewCell {
                let song = songs[indexPath.row]
                if let path = song.thumbImageURL?.path {
                    //let size = cell.thumbImage!.frame.size
                    cell.thumbImage!.image = UIImage(contentsOfFile: path)?.scaleKeepingRatio(toHeight: 38)
                } else {
                    cell.thumbImage!.image = UIImage(named: "smallPlaceholder")?.withRenderingMode(.alwaysTemplate)
                }
            }
        }
    }
    
    //MARK: - ViewControllerPreviewingDelegate
    
    @available(iOS 9.0, *)
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        
        guard let indexPath = tableView?.indexPathForRow(at: location),
            let cell = tableView?.cellForRow(at: indexPath),
            let previewVC = storyboard?.instantiateViewController(withIdentifier: "3dTouchPreview") as? PreviewSongViewController
            else { return nil }
        
        corePlayer.reset(endingAudioSession: false)
        previewVC.setSongs(songs, startIndex: indexPath.row)
        
        previewingContext.sourceRect = cell.frame
        
        return previewVC
        
    }
    
    @available(iOS 9.0, *)
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        
        guard let previewVC = viewControllerToCommit as? PreviewSongViewController,
            let playerVC = storyboard?.instantiateViewController(withIdentifier: "playerDetail") as? PlayerViewController,
            let playerItem = previewVC.previewPlayer.currentItem,
            let songs = previewVC.previewSongs,
            let startIndex = previewVC.startIndex
            else { return }
        
        previewVC.previewPlayer.pause()
        corePlayer.resumeFromPreview(with: playerItem,
                                     songs: songs,
                                     current: startIndex)
        
        show(playerVC, sender: self)
    }
    
    //MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier ?? "" {
        case "editPlaylistSegue":
            guard let navController = segue.destination as? UINavigationController,
                let destController = navController.viewControllers.first as? PlaylistCreatorTableViewController
                else { return }
                destController.setupForEditingPlaylist(playlist!) {[unowned self] (_) in
                    self.tableView.reloadData()
                }
        default:
            let index = tableView.indexPathForSelectedRow!.row
            corePlayer.reset(endingAudioSession: false)
            corePlayer.prepareForPlayback(with: songs, current: index, shouldStart: true, completion: nil)
        }
    }

}
