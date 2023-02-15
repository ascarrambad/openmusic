//
//  AlbumTableViewController.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 26/02/16.
//  Copyright © 2016 Matteo Riva. All rights reserved.
//

import UIKit
import CoreData
import AERecord

class AlbumTableViewController: AbstractTableViewController, UISearchResultsUpdating, UISearchControllerDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        searchController.dimsBackgroundDuringPresentation = false
        definesPresentationContext = true
        tableView.tableHeaderView = searchController.searchBar
        searchController.searchBar.sizeToFit()
        
        loadData()
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
    
    //MARK: - Actions
    
    func loadData() {
        let request = NSFetchRequest<Album>(entityName: "Album")
        request.predicate = NSPredicate(format: "ANY songs.isDownloaded == true")
        request.fetchBatchSize = 20
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        request.relationshipKeyPathsForPrefetching = ["songs"]
        let controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: AERecord.Context.main, sectionNameKeyPath: "firstLetter", cacheName: nil)
        self.fetchedResultsController = controller as? NSFetchedResultsController<NSManagedObject>
    }
    
    //MARK: - Search
    
    func willPresentSearchController(_ searchController: UISearchController) {
        navigationController!.navigationBar.isTranslucent = true
    }
    
    func willDismissSearchController(_ searchController: UISearchController) {
        navigationController!.navigationBar.isTranslucent = false
    }
    
    func filterContentForSearchText(_ searchText: String) {
        
        let mainP = NSPredicate(format: "ANY songs.isDownloaded == true")
        
        if searchText.isEmpty {
            fetchedResultsController?.fetchRequest.predicate = mainP
            try! performFetch()
        } else {
            let secP = NSPredicate(format: "name contains[c] %@", searchText)
            fetchedResultsController?.fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [mainP, secP])
            try! performFetch()
        }
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchController.searchBar.text!)
    }
    
    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "album", for: indexPath) as! MultiTableViewCell
        
        if let album = fetchedResultsController?.object(at: indexPath) as? Album {
            cell.name.text = album.name
            cell.caption?.text = album.artist?.name ?? "Nessun artista"
            cell.setNumOfSongs(album.filteredSongSet.count)
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? MultiTableViewCell {
            if let album = fetchedResultsController?.object(at: indexPath) as? Album {
                if let path = album.thumbImageLocalURL?.path {
                    //let size = cell.albumImage!.frame.size
                    cell.albumImage!.image = UIImage(contentsOfFile: path)?.scaleKeepingRatio(toHeight: 59)
                } else {
                    cell.albumImage!.image = UIImage(named: "genericPlaceholder")?.withRenderingMode(.alwaysTemplate)
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        super.prepare(for: segue, sender: sender)
        
        switch segue.identifier ?? "" {
        case "albumDetailSegue":
            guard let dest = segue.destination as? DetailSongsTableViewController,
                let indexPath = tableView.indexPathForSelectedRow,
                let album = fetchedResultsController?.object(at: indexPath) as? Album
                else { return }
            dest.setupSongs(album, type: .albumSongs)
        default: break
        }
    }
    
    
}
