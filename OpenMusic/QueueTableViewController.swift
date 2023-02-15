//
//  QueueTableViewController.swift
//  OpenMusic
//
//  Created by Matteo Riva on 30/08/16.
//  Copyright © 2016 Matteo Riva. All rights reserved.
//

import UIKit
import MGSwipeTableCell

class QueueTableViewController: UITableViewController {
    
    private enum SectionType: Int {
        case previous = 0
        case current = 1
        case next = 2
    }
    
    private let corePlayer = CorePlayer.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setEditing(true, animated: false)
        
        NotificationCenter.default.addObserver(forName: .CorePlayerDidStartNewSong, object: nil, queue: .main) {[weak self] (_) in
            self?.tableView.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let indexPath = IndexPath(item: 0, section: SectionType.current.rawValue)
        tableView.scrollToRow(at: indexPath, at: .top, animated: false)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let section = SectionType(rawValue: section)!
        switch section {
        case .current: return "current_song".localized
        case .next: return "next_songs".localized
        case .previous: return "previous_songs".localized
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = SectionType(rawValue: section)!
        switch section {
        case .current: return 1
        case .next: return corePlayer.queue.count - (corePlayer.currentIndex! + 1)
        case .previous: return corePlayer.currentIndex!
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "song", for: indexPath) as! SongTableViewCell
        
        let song: Song
        let section = SectionType(rawValue: indexPath.section)!
        
        switch section {
        case .current: song = corePlayer.current!
        case .next:
            let index = corePlayer.currentIndex! + indexPath.row + 1
            song = corePlayer.queue[index]
        case .previous: song = corePlayer.queue[indexPath.row]
        }
        
        cell.displaySongInfos(song)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let section = SectionType(rawValue: indexPath.section)!
        return section == .next
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        let section = SectionType(rawValue: indexPath.section)!
        return section == .next
    }
    
    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        
        if proposedDestinationIndexPath.section < SectionType.next.rawValue {
            return IndexPath(row: 0, section: SectionType.next.rawValue)
        } else {
            return proposedDestinationIndexPath
        }
    }
    
    //MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let index = corePlayer.currentIndex! + indexPath.row + 1
            corePlayer.removeSong(at: index)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        
        let current = corePlayer.currentIndex! + sourceIndexPath.row + 1
        let destination = corePlayer.currentIndex! + destinationIndexPath.row + 1
        corePlayer.move(at: current, to: destination)
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let cell = cell as! SongTableViewCell
        
        let song: Song
        let section = SectionType(rawValue: indexPath.section)!
        
        switch section {
        case .current: song = corePlayer.current!
        case .next:
            let index = corePlayer.currentIndex! + indexPath.row + 1
            song = corePlayer.queue[index]
        case .previous: song = corePlayer.queue[indexPath.row]
        }
        
        if let path = song.thumbImageURL?.path {
            cell.thumbImage!.image = UIImage(contentsOfFile: path)?.scaleKeepingRatio(toHeight: 38)
        } else {
            cell.thumbImage!.image = UIImage(named: "smallPlaceholder")?.withRenderingMode(.alwaysTemplate)
        }
    }

}
