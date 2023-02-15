//
//  SongsViewController.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 24/09/15.
//  Copyright © 2015 Matteo Riva. All rights reserved.
//

import UIKit
import CoreData
import AERecord
import MGSwipeTableCell

class AllSongsTableViewController: AbstractTableViewController, UISearchResultsUpdating, UISearchControllerDelegate, UIViewControllerPreviewingDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        searchController.dimsBackgroundDuringPresentation = false
        definesPresentationContext = true
        tableView.tableHeaderView = searchController.searchBar
        searchController.searchBar.sizeToFit()
        
        if #available(iOS 9.0, *) {
            if traitCollection.forceTouchCapability == .available {
                registerForPreviewing(with: self, sourceView: view)
            }
        }
        
        loadData()
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
    
    func loadData() {
        let request = NSFetchRequest<Song>(entityName: "Song")
        request.predicate = NSPredicate(format: "isDownloaded == true")
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        request.fetchBatchSize = 20
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
        
        let mainP = NSPredicate(format: "isDownloaded == true")
        
        if searchText.isEmpty {
            fetchedResultsController?.fetchRequest.predicate = mainP
            try! performFetch()
        } else {
            let secP = NSPredicate(format: "title contains[c] %@", searchText)
            fetchedResultsController?.fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [mainP, secP])
            try! performFetch()
        }
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchController.searchBar.text!)
    }
    
    //MARK: - TableViewDataSource
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "song", for: indexPath) as! SongTableViewCell
        
        if let song = fetchedResultsController?.object(at: indexPath) as? Song {
            cell.displaySongInfos(song)
            
            if corePlayer.isPlaying {
                let addQueue = MGSwipeButton(title: "",
                                             icon: UIImage(named: "addQueue")!.withRenderingMode(.alwaysTemplate),
                                             backgroundColor: .lightGray, callback: { [weak self] (_) -> Bool in
                                                self?.corePlayer.append(song)
                                                return true
                })
                
                let addNext = MGSwipeButton(title: "",
                                            icon: UIImage(named: "addNext")!.withRenderingMode(.alwaysTemplate),
                                            backgroundColor: navigationController?.navigationBar.barTintColor, callback: { [weak self]  (_) -> Bool in
                    self?.corePlayer.addNext(song)
                    return true
                })
                
                addNext.tintColor = .white
                addNext.buttonWidth = 90
                addQueue.tintColor = .white
                addQueue.buttonWidth = 90
                
                cell.leftButtons = [addNext,addQueue]
                cell.leftSwipeSettings.transition = .clipCenter
                cell.leftExpansion.buttonIndex = 0
            } else {
                cell.leftButtons = []
            }
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    //MARK: - TableViewDelegate
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? SongTableViewCell {
            if let song = fetchedResultsController?.object(at: indexPath)  as? Song {
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
            let previewVC = storyboard?.instantiateViewController(withIdentifier: "3dTouchPreview") as? PreviewSongViewController,
            let songs = self.fetchedResultsController?.fetchedObjects as? [Song],
            let song = self.fetchedResultsController?.object(at: indexPath) as? Song,
            let index = songs.index(of: song)
            else { return nil }
        
        corePlayer.reset(endingAudioSession: false)
        previewVC.setSongs(songs, startIndex: index)
        
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
        
        super.prepare(for: segue, sender: sender)
        
        switch segue.identifier ?? "" {
        case "playSegue":
            guard let indexPath = self.tableView.indexPathForSelectedRow,
                let songs = self.fetchedResultsController?.fetchedObjects as? [Song],
                let song = self.fetchedResultsController?.object(at: indexPath) as? Song,
                let index = songs.index(of: song)
                else { return }
            corePlayer.reset(endingAudioSession: false)
            corePlayer.prepareForPlayback(with: songs, current: index, shouldStart: true, completion: nil)
        default: break
        }
    }

}
