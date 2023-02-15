//
//  TransitionAnimator.swift
//  MeratiMusic
//
//  Created by Matteo Riva on 03/03/16.
//  Copyright © 2016 Matteo Riva. All rights reserved.
//

import UIKit

enum ModalTransitionType {
    case present, dismiss
}

class ModalTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    private let type: ModalTransitionType
    
    init(type: ModalTransitionType) {
        self.type = type
        super.init()
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        guard
            let fromVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from),
            let toVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)
        else
            { return }
        
        let containerView = transitionContext.containerView
        let scBounds = UIScreen.main.bounds
        
        switch type {
        case .present:
            let finalFrameForVC = transitionContext.finalFrame(for: toVC)
            toVC.view.frame = finalFrameForVC.offsetBy(dx: 0, dy: scBounds.size.height)
            containerView.addSubview(toVC.view)
            
            UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: .curveLinear, animations: {
                fromVC.view.alpha = 0.5
                toVC.view.frame = finalFrameForVC
            }, completion: { finished in
                transitionContext.completeTransition(true)
                fromVC.view.alpha = 1.0
            })
        case .dismiss:
            
            containerView.insertSubview(toVC.view, belowSubview: fromVC.view)
            let finalFrame = transitionContext.finalFrame(for: toVC).offsetBy(dx: 0, dy: scBounds.size.height)
            toVC.view.alpha = 0.5
            UIView.animate(
                withDuration: transitionDuration(using: transitionContext),
                animations: {
                    fromVC.view.frame = finalFrame
                    toVC.view.alpha = 1.0
                },
                completion: { _ in
                    transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                }
            )
        }
        
    }
}
