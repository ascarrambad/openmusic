//
//  AbstractTableViewController.swift
//  Subspedia
//
//  Created by Matteo Riva on 09/07/15.
//  Copyright (c) 2015 Matteo Riva. All rights reserved.
//

import UIKit
import CoreData
import NAKPlaybackIndicatorView
import AECoreDataUI
import AERecord

class AbstractTableViewController: CoreDataTableViewController, UIViewControllerTransitioningDelegate {
    
    private let interactionController = InteractiveController()
    let notificationCenter = NotificationCenter.default
    let corePlayer = CorePlayer.shared
    let searchController = UISearchController(searchResultsController: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        notificationCenter.addObserver(self, selector: #selector(playingStatusUpdateHandler), name: .CorePlayerStatusDidChange, object: nil)
        
        notificationCenter.addObserver(forName: .CorePlayerStatusDidChange, object: nil, queue: .main) { [weak self] (_) in
            self?.tableView.reloadData()
        }
        
        tableView.tintColor = navigationController?.navigationBar.barTintColor
        
        searchController.searchBar.barTintColor = .white
        searchController.searchBar.backgroundColor = navigationController!.navigationBar.barTintColor
        searchController.searchBar.tintColor = navigationController!.navigationBar.barTintColor
        
        playingStatusUpdateHandler()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.tintColor = navigationController?.navigationBar.barTintColor
        
        guard let barButton = navigationItem.leftBarButtonItem,
            let button = barButton.customView as? UIButton,
            let indicator = button.subviews.first as? NAKPlaybackIndicatorView
            else { return }
        
        indicator.refreshAnimation()
    }
    
    func playingStatusUpdateHandler() {
        DispatchQueue.main.async { [unowned self] in
            if self.corePlayer.isPlaying && self.corePlayer.current != nil {
                let indicator = NAKPlaybackIndicatorView()
                indicator.state = .playing
                let button = UIButton(type: .custom)
                button.addSubview(indicator)
                let nowPlaying = UIBarButtonItem(customView: button)
                indicator.sizeToFit()
                button.addTarget(self, action: #selector(AbstractTableViewController.nowPlayingSegue), for: .touchUpInside)
                self.navigationItem.leftBarButtonItem = nowPlaying
            } else {
                self.navigationItem.leftBarButtonItem = nil
            }
        }
    }
    
    func nowPlayingSegue() {
        performSegue(withIdentifier: "nowPlayingSegue", sender: self)
    }
    
    //MARK: - TableViewDelegate
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let obj = self.fetchedResultsController!.object(at: indexPath) 
            obj.managedObjectContext?.delete(obj)
            AERecord.save()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    //MARK: - UIViewControllerTransitioningDelegate
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return nil//ModalTransitionAnimator(type: .Present)
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ModalTransitionAnimator(type: .dismiss)
    }
    
    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactionController.transitionInProgress ? interactionController : nil
    }
    
    //MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "nowPlayingSegue" {
            guard
                let destNav = segue.destination as? UINavigationController,
                let destView = destNav.viewControllers.first as? PlayerViewController
                else
            { return }
            
            destNav.transitioningDelegate = self
            destNav.navigationBar.barTintColor = self.navigationController?.navigationBar.barTintColor
            destView.isNowPlaying = true
            interactionController.attachToNavigationController(destNav)
        }
    }

}
