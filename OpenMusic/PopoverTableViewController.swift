//
//  MultipleChoiceSelectorTableViewController.swift
//
//
//  Created by Matteo Riva on 09/10/15.
//
//

import UIKit
import Popover

class PopoverTableViewController: Popover, UITableViewDelegate, UITableViewDataSource {
    
    private var choicesToDisplay: [String]!
    private var selectedIndex: Int?
    private var completionHandler: ((Int,String) -> Void)!
    
    var tableView: UITableView!
    
    convenience init(frame: CGRect, choicesToDisplay: [String], selectedIndex: Int?, completionHandler: @escaping ((Int,String) -> Void)) {
        
        let popoverOptions: [PopoverOption] = [
            .type(.down),
            .blackOverlayColor(UIColor(white: 0.0, alpha: 0.6))
        ]
        
        self.init(options: popoverOptions)
        
        self.choicesToDisplay = choicesToDisplay
        self.selectedIndex = selectedIndex
        self.completionHandler = completionHandler
        
        tableView = UITableView(frame: frame, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isScrollEnabled = false
    }
    
    func showFromPoint(_ point: CGPoint) {
        super.show(tableView, point: point)
    }
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return choicesToDisplay.count 
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        
        if (indexPath as NSIndexPath).row == selectedIndex {
            cell.accessoryType = .checkmark
        }
        
        cell.textLabel?.text = choicesToDisplay[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        completionHandler((indexPath as NSIndexPath).row,choicesToDisplay[(indexPath as NSIndexPath).row])
        self.dismiss()
    }
    
}
