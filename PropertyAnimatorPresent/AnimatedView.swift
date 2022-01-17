//
//  KeyframeVC.swift
//  PropertyAnimatorPresent
//
//  Created by Thomas Walther on 2022-01-17.
//

import UIKit


class AnimatedView: UIView {
    private var animator: UIViewPropertyAnimator!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    func setup() {
        backgroundColor = .systemYellow
        
        updateAnimator()
    }
    
    func updateAnimator() {
        guard window != nil else {
            destroyAnimator()
            return
        }
        
        if animator == nil {
            animator = UIViewPropertyAnimator(duration: 10, curve: .linear) {
                UIView.animateKeyframes(
                    // The duration given here is ignored, only the duration passed to the animator's initializer is regarded.
                    withDuration: 0,
                    // The delay *must be* between 0 and the delay given in the `.startAnimation()` call.
                    // Else, the animation simply skips to the end without actually animating.
                    // Ideally, let's keep it at 0, because I haven't tested and documented the exact behaviour if it's > 0 yet
                    delay: 0,
                    animations: {
                        UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0) {
                            self.frame.size = CGSize(width: 2, height: 100)
                        }
                        UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1) {
                            self.frame.size = CGSize(width: 200, height: 100)
                        }
                    }
                    // We're intentionally not using the `completion` of the `animateKeyframes` method
                    // since modifying the animator in said completion introduces race conditions.
                    // Also, the behaviour of the animator completion block added below is better to handle.
                )
            }
            animator.addCompletion { [weak self] _ in
                // This completion is only called when the animation has completed on its own.
                // It is not called when `destroyAnimator` is executed, since we're calling
                // `stopAnimation(true)` and then *not* calling `finishAnimation(_:)`.
                //
                // We don't need to call `stopAnimation(_:)` here since the default value
                // of `animator.pausesOnCompletion` is false (and we don't set it to true),
                // so inside *this* completion block, the animator is already stopped and finished
                // and can be released safely.
                //
                // We're using the animator's completion instead of the `UIView.animateKeyframes`,
                // see the `UIView.animateKeyframes` for further explanation.
                self?.animator = nil
            }
        }
        
        animator.pauseAnimation()
    }
    
    func destroyAnimator() {
        guard animator != nil else { return }
        if animator!.state == .active {
            // Passing `withoutFinishing: true` to `stopAnimation(_:)`, so we don't have to call `finishAnimation(_:)` afterwards.
            // The parameter name `withoutFinishing` basically means "stop and deactivate the animator, clean up its animations and completions"
            // This removes the completion block from the animator *without calling it*.
            // Calling `finishAnimation(_:)` after `stopAnimation(true)` would noop.
            animator!.stopAnimation(true)
        }
        animator = nil
    }
    
    override func didMoveToWindow() { updateAnimator() }
}
