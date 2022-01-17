//
//  KeyframeVC.swift
//  PropertyAnimatorPresent
//
//  Created by Thomas Walther on 2022-01-17.
//

import UIKit


class AnimatedView: UIView {
    private var animator: KeyframeAnimator!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    func setup() {
        backgroundColor = .systemYellow
        
        animator = KeyframeAnimator(duration: 10, window: window)
        animator.keyframeProvider = { [unowned self] in
            [
                (relStart: 0, relDuration: 0, animations: { setProgress(0) }),
                (relStart: 0, relDuration: 1, animations: { setProgress(1) })
            ]
        }
        
        animator.pause(atTime: 0)
    }
    
    func setProgress(_ progress: CGFloat) {
        frame.size = CGSize(width: (10 + 190 * progress), height: 100)
    }
    
    override func didMoveToWindow() { animator.window = window }
}

