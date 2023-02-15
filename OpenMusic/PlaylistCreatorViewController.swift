//
//  PlaylistCreatorTableViewController.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 27/05/15.
//  Copyright (c) 2015 Matteo Riva. All rights reserved.
//

import UIKit
import AERecord
import AECoreDataUI
import CoreData

class PlaylistCreatorTableViewController: CoreDataTableViewController, UITextFieldDelegate {
    
    @IBOutlet weak var doneButton: UIBarButtonItem!
    
    private var playlistNameField = UITextField()
    private var existingPlaylist: Playlist!
    private var completion: ((Playlist) -> ())!
    private var userIsEditingPlaylist = false
    
    private let selectedSongs = NSMutableArray()
    
    let notificationCenter = NotificationCenter.default
    
    func setupForEditingPlaylist(_ playlist: Playlist, completion: @escaping ((Playlist) -> ())) {
        userIsEditingPlaylist = true
        existingPlaylist = playlist
        self.completion = completion
        for song in playlist.songs.array as! [Song] {
            selectedSongs.add(song)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.setEditing(true, animated: false)
        playlistNameField.delegate = self

        
        let view = UIView(frame: CGRect(x: 0, y: 0, width: ScreenSize.width, height: 46))
        playlistNameField.placeholder = "playlist_name_placeholder".localized
        playlistNameField.frame = CGRect(x: 16, y: 14, width: ScreenSize.width-14, height: 21)
        playlistNameField.borderStyle = .none
        playlistNameField.returnKeyType = .done
        view.addSubview(playlistNameField)
        tableView.tableHeaderView = view
        
        loadData()
        playlistNameField.addTarget(self, action: #selector(textDidChange), for: .editingChanged)
        
        if userIsEditingPlaylist {
            playlistNameField.text = existingPlaylist.name
            navigationItem.rightBarButtonItem?.isEnabled = true
            let counter = existingPlaylist.songs.count
            navigationItem.prompt = "\(counter)"
            navigationItem.prompt! += counter == 1 ? "cell_song".localized : "cell_songs".localized
        } else {
            navigationItem.prompt = "0" + "cell_songs".localized
        }
    }
    
    func loadData() {
        let request = NSFetchRequest<Song>(entityName: "Song")
        request.predicate = NSPredicate(format: "isDownloaded == true")
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        request.fetchBatchSize = 20
        let controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: AERecord.Context.main, sectionNameKeyPath: "firstLetter", cacheName: nil)
        fetchedResultsController = controller as? NSFetchedResultsController<NSManagedObject>
    }
    
    //MARK: - Actions
    
    @IBAction func createPlaylistAndDismiss() {
        AERecord.Context.main.perform {[unowned self] in
            if self.playlistNameField.text!.lowercased() == "recently_added".localized.lowercased() || self.playlistNameField.text!.lowercased() == "most_played".localized.lowercased() {
                UIAlertView(title: "error".localized, message: "playlist_forbidden_name".localized, delegate: nil, cancelButtonTitle: "ok_button".localized).show()
                self.playlistNameField.text = ""
                self.playlistNameField.becomeFirstResponder()
            } else {
                if self.selectedSongs.count == 0 {
                    UIAlertView(title: "error".localized, message: "empty_playlist".localized, delegate: nil, cancelButtonTitle: "ok_button".localized).show()
                } else {
                    if self.userIsEditingPlaylist {
                        let songs = self.selectedSongs as Any as! [Song]
                        self.existingPlaylist.modify(withNewName: self.playlistNameField.text!, songs: songs)
                        self.completion(self.existingPlaylist)
                        AERecord.save()
                        self.notificationCenter.post(name: PlaylistsNeedDisplay, object: nil)
                        self.dismissAction()
                    } else {
                        let songs = self.selectedSongs as Any as! [Song]
                        if Playlist.create(withName: self.playlistNameField.text!, songs: songs, in: AERecord.Context.main) == nil {
                            UIAlertView(title: "error".localized, message: "playlist_same_name".localized, delegate: nil, cancelButtonTitle: "ok_button".localized).show()
                        } else {
                            AERecord.save()
                            self.dismissAction()
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func dismissAction() {
        dismiss(animated: true, completion: nil)
    }
    
    //MARK: - UITextFieldDelegate
    
    func textDidChange() {
        doneButton.isEnabled = !playlistNameField.text!.isEmpty
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    //MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .insert
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .insert {
            guard let song = fetchedResultsController?.object(at: indexPath)
                else { return }
            selectedSongs.add(song)
            let counter = selectedSongs.count
            navigationItem.prompt = "\(counter)" + (counter == 1 ? "cell_song".localized : "cell_songs".localized)
            
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "song", for: indexPath) as! SongTableViewCell
        
        if let song = fetchedResultsController?.object(at: indexPath) as? Song {
            cell.displaySongInfos(song)
        }
        
        return cell
    }
    
    //MARK: - TableViewDelegate
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? SongTableViewCell {
            if let song = fetchedResultsController?.object(at: indexPath) as? Song {
                if let path = song.thumbImageURL?.path {
                    //let size = cell.thumbImage!.frame.size
                    cell.thumbImage!.image = UIImage(contentsOfFile: path)?.scaleKeepingRatio(toHeight: 38)
                } else {
                    cell.thumbImage!.image = UIImage(named: "smallPlaceholder")?.withRenderingMode(.alwaysTemplate)
                }
            }
        }
    }

}
