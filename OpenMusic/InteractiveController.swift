//
//  InteractiveController.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 03/03/16.
//  Copyright © 2016 Matteo Riva. All rights reserved.
//

import UIKit

class InteractiveController: UIPercentDrivenInteractiveTransition {
    
    var navigationController: UINavigationController!
    var shouldCompleteTransition = false
    var transitionInProgress = false
    private let gesture: UIPanGestureRecognizer
    
    override init() {
        gesture = UIPanGestureRecognizer()
        super.init()
        gesture.addTarget(self, action: #selector(InteractiveController.handlePanGesture(_:)))
    }

    
    func attachToNavigationController(_ navController: UINavigationController) {
        navigationController = navController
        setupGestureRecognizer(navController.navigationBar)
    }
    
    private func setupGestureRecognizer(_ view: UIView) {
        view.addGestureRecognizer(gesture)
    }
    
    func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        
        let scBound = UIScreen.main.bounds
        let percentThreshold: CGFloat = 0.3
        
        // convert y-position to downward pull progress (percentage)
        let translation = gestureRecognizer.translation(in: navigationController.navigationBar)
        let verticalMovement = translation.y / scBound.height
        let progress = min(max(verticalMovement, 0), 1)
        
        switch gestureRecognizer.state {
        case .began:
            transitionInProgress = true
            navigationController.dismiss(animated: true, completion: nil)
        case .changed:
            shouldCompleteTransition = progress > percentThreshold
            update(progress)
        case .cancelled, .ended:
            transitionInProgress = false
            if !shouldCompleteTransition || gestureRecognizer.state == .cancelled {
                cancel()
            } else {
                finish()
            }
        default: break
        }
    }

}
