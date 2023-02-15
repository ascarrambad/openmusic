//
//  ViewController.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 22/05/15.
//  Copyright (c) 2015 Matteo Riva. All rights reserved.
//

import UIKit
import iAd
import AERecord
import Popover
import CoreData

class SearchViewController: UIViewController, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var searchImage: UIImageView!
    @IBOutlet weak var searchLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var serviceSelector: UISegmentedControl!
    @IBOutlet weak var filterButton: UIBarButtonItem!
    
    private let searchBar = UISearchBar()
    
    private var currentService: ServiceProtocol!
    
    private var userIsSearching = false
    
    private var songs: [EphimeralSong]? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.searchImage.isHidden = true
                self?.searchLabel.isHidden = true
                self?.tableView.isHidden = false
                self?.tableView.reloadData()
            }
        }
    }
    
    private var suggestions: [String]? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.searchImage.isHidden = true
                self?.searchLabel.isHidden = true
                self?.tableView.isHidden = false
                self?.tableView.reloadData()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        currentService = PleerService.shared
        
        searchBar.placeholder = "search_placeholder".localized
        searchBar.delegate = self
        navigationItem.titleView = searchBar
        navigationItem.titleView?.tintColor = view.tintColor
        
        searchImage.image = searchImage.image?.withRenderingMode(.alwaysTemplate)
        tableView.isHidden = true
        
        filterButton.tintColor = currentService.qualityFilter == .all ? .white : .orange
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.tintColor = navigationController?.navigationBar.barTintColor
        if songs != nil {
            tableView.reloadData()
        }
    }
    
    //MARK: - Actions
    
    @IBAction func songSourceDidChange() {
        if serviceSelector.selectedSegmentIndex == 0 {
            currentService = PleerService.shared
            filterButton.isEnabled = true
        } else {
            currentService = TubeService.shared
            filterButton.isEnabled = false
        }
    }
    
    @IBAction func setFilterAction() {
        
        let index: Int
        switch currentService.qualityFilter {
        case .all: index = 0
        case .low: index = 1
        case .medium: index = 2
        case .high: index = 3
        }
        
        let frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 180)
        let choiceArray = ["all_q".localized,
                           "low_q".localized,
                           "med_q".localized,
                           "hd_q".localized]
        
        let popover = PopoverTableViewController(frame: frame, choicesToDisplay: choiceArray, selectedIndex: index) { [weak self] (selectedIndex, _) -> Void in
            
            let quality: String
            switch selectedIndex {
            case 1: quality = "bad"
            case 2: quality = "good"
            case 3: quality = "best"
            case 0: fallthrough
            default: quality = "all"
            }
            
            self?.currentService.qualityFilter = ServiceQualityFilter(rawValue: quality)!
            if self != nil {
                self!.filterButton.tintColor = self!.currentService.qualityFilter == .all ? UIColor.white : UIColor.orange
                if !self!.searchBar.text!.isEmpty {
                    self!.searchBarSearchButtonClicked(self!.searchBar)
                }
            }
        }
        
        let startPoint = CGPoint(x: 30, y: 55)
        popover.showFromPoint(startPoint)
        
    }
    
    //MARK: - UISearchBarDelegate
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        DispatchQueue.main.async { [weak self] in
            self?.userIsSearching = true
            self?.tableView.reloadData()
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        currentService.retrieveSuggestions(for: searchText) { sugg in
            self.suggestions = sugg
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        DispatchQueue.main.async { [weak self] in
            self?.userIsSearching = false
            self?.searchLabel.text = "wait_for_results".localized
            self?.searchImage.isHidden = false
            self?.searchLabel.isHidden = false
            self?.tableView.isHidden = true
            self?.currentService.performSearch(for: searchBar.text!) { [weak self] (songs) in
                self?.songs = songs
            }
            self?.searchBar.resignFirstResponder()
        }
    }
    
    //MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return userIsSearching ? (suggestions?.count ?? 0) : (songs?.count ?? 0)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return userIsSearching ? 44 : 55
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if userIsSearching {
            let cell = tableView.dequeueReusableCell(withIdentifier: "sugg", for: indexPath)
            if let sugg = suggestions?[indexPath.row] {
                let ops = [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                           NSCharacterEncodingDocumentAttribute: String.Encoding.utf8.rawValue] as [String : Any]
                
                let attrString = try! NSAttributedString(data: sugg.data(using: .utf8)!,
                                                         options: ops,
                                                         documentAttributes: nil)
                cell.textLabel?.text = attrString.string
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "song", for: indexPath) as! SongTableViewCell
            
            if let effSong = songs?[indexPath.row] {
                cell.displayEphimeralSongInfos(effSong)
                
                if let song = effSong.persistent {
                    if song.isDownloaded { cell.downloadButton!.setIndicatorStatus(.completed) }
                    else if song.isDownloading { cell.downloadButton!.setIndicatorStatus(.indeterminate) }
                    else { cell.downloadButton!.setIndicatorStatus(.none) }
                } else { cell.downloadButton!.setIndicatorStatus(.none) }
                
                cell.downloadButton!.setActionForTap() { [weak self] (view, status) in
                    switch status {
                    case .none:
                        view?.setIndicatorStatus(.indeterminate)
                        
                        if self?.serviceSelector.selectedSegmentIndex == 0 {
                            self?.downloadAction(with: effSong, at: indexPath)
                        } else {
                            let alertController = UIAlertController(title: "fill_info_placeholder".localized, message: nil, preferredStyle: .alert)
                            alertController.addTextField { (text) in text.placeholder = "artist_field_placeholder".localized }
                            alertController.addTextField { (text) in text.placeholder = "song_field_placeholder".localized }
                            
                            let downloadAction = UIAlertAction(title: "ok_button".localized, style: .default) { [weak self] (_) in
                                let artist = alertController.textFields![0].text!
                                let title = alertController.textFields![1].text!
                                effSong.artist = artist != "" ? artist : effSong.artist
                                effSong.title = title != "" ? title : effSong.title
                                self?.downloadAction(with: effSong, at: indexPath)
                            }
                            
                            let cancelAction = UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil)
                            
                            alertController.addAction(downloadAction)
                            alertController.addAction(cancelAction)
                            self?.present(alertController, animated: true, completion: nil)
                        }
                    case .completed:
                        AERecord.Context.background.perform() {
                            if let song = effSong.persistent {
                                song.managedObjectContext?.delete(song)
                                effSong.persistent = nil
                                AERecord.save()
                            }
                        }
                        view?.setIndicatorStatus(.none)
                    case .running: fallthrough
                    default: break
                    }
                }
                
                
            }
            return cell
        }
    }
    
    func handleError(_ error: Error) {
        let alert = UIAlertController(title: "error".localized, message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ok_button".localized, style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    //MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if userIsSearching {
            let ops = [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                       NSCharacterEncodingDocumentAttribute: String.Encoding.utf8.rawValue] as [String : Any]
            
            let attrString = try? NSAttributedString(data: suggestions![indexPath.row].data(using: .utf8)!,
                                                       options: ops,
                                                       documentAttributes: nil)
            searchBar.text = attrString?.string
            searchBarSearchButtonClicked(searchBar)
        }
    }

    func downloadAction(with effSong: EphimeralSong, at indexPath: IndexPath) {
        effSong.createPersistent(in: AERecord.Context.background) { [weak self] (song) in
            if let song = song {
                self?.currentService.performDonwload(song: song, with: "save", handler: { [weak self] (completion) -> Void in
                    guard let cellTmp = self?.tableView.cellForRow(at: indexPath) as? SongTableViewCell
                        else { return }
                    if cellTmp.id == song.id {
                        cellTmp.downloadButton?.setIndicatorStatus(.running)
                        cellTmp.downloadButton?.setProgress(completion, animated: true)
                    }
                }, completion: { (error) in
                    DispatchQueue.main.async { [weak self] in
                        guard let cellTmp = self?.tableView.cellForRow(at: indexPath) as? SongTableViewCell
                            else { return }
                        
                        if cellTmp.id == song.id {
                            if let error = error {
                                self?.handleError(error)
                            }
                            cellTmp.downloadButton?.setIndicatorStatus(error == nil ? .completed : .none)
                        }
                    }
                })
            }
        }
    }
    
    
}

