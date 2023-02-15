//
//  PlaylistsTableViewController.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 27/05/15.
//  Copyright (c) 2015 Matteo Riva. All rights reserved.
//

import UIKit
import NAKPlaybackIndicatorView
import AERecord
import CoreData

class PlaylistsTableViewController: AbstractTableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadData()
    }
    
    //MARK: - Actions
    
    func loadData() {
        let request = NSFetchRequest<Playlist>(entityName: "Playlist")
        request.sortDescriptors = [NSSortDescriptor(key: "system", ascending: false),NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        request.fetchBatchSize = 20
        request.relationshipKeyPathsForPrefetching = ["songs"]
        let controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: AERecord.Context.main, sectionNameKeyPath: "system", cacheName: nil)
        self.fetchedResultsController = controller as? NSFetchedResultsController<NSManagedObject>
    }

    // MARK: - Table view data source
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return nil
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "playlist_header_automatic".localized
        case 1: return "playlist_header_user".localized
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "playlist", for: indexPath) as! MultiTableViewCell
        
        if let playlist = fetchedResultsController?.object(at: indexPath) as? Playlist {
            cell.name.text = playlist.name
            cell.setNumOfSongs(playlist.songs.count)
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if let playlist = fetchedResultsController?.object(at: indexPath) as? Playlist {
            (cell as? MultiTableViewCell)?.albumImage?.image = playlist.thumbImage ?? UIImage(named: "playlistPlaceholder")
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch indexPath.section {
        case 0: return false
        default: return true
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        super.prepare(for: segue, sender: sender)
        
        switch segue.identifier ?? "" {
        case "playlistDetailsSegue":
            guard let dest = segue.destination as? DetailSongsTableViewController,
                let indexPath = tableView.indexPathForSelectedRow,
                let playlist = fetchedResultsController?.object(at: indexPath) as? Playlist
                else { return }
                dest.setupSongs(playlist, type: .playlistSongs)
        default: break
        }
    }
    

}
