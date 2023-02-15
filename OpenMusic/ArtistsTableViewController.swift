//
//  ArtistsTableViewController.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 27/05/15.
//  Copyright (c) 2015 Matteo Riva. All rights reserved.
//

import UIKit
import CoreData
import AERecord

class ArtistsTableViewController: AbstractTableViewController, UISearchResultsUpdating, UISearchControllerDelegate {
    
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
        let request = NSFetchRequest<Artist>(entityName: "Artist")
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "artist", for: indexPath) as! MultiTableViewCell
        
        if let artist = fetchedResultsController?.object(at: indexPath) as? Artist {
            cell.name.text = artist.name
            cell.setNumOfSongs(artist.filteredSongSet.count)
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? MultiTableViewCell {
            if let artist = fetchedResultsController?.object(at: indexPath) as? Artist {
                if let path = artist.thumbImageLocalURL?.path {
                    //let size = cell.artistImage!.frame.size
                    cell.artistImage!.image = UIImage(contentsOfFile: path)?.scaleKeepingRatio(toHeight: 59)
                } else {
                    cell.artistImage!.image = UIImage(named: "genericPlaceholder")?.withRenderingMode(.alwaysTemplate)
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
        case "artistDetailSegue":
            guard let dest = segue.destination as? DetailSongsTableViewController,
                let indexPath = tableView.indexPathForSelectedRow,
                let artist = fetchedResultsController?.object(at: indexPath) as? Artist
                else { return }
                dest.setupSongs(artist, type: .artistSongs)
        default: break
        }
    }


}
