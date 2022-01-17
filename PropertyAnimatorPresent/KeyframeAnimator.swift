//
//  KeyframeAnimator.swift
//  TapeIt
//
//  Created by Jan Nash on 24.09.20.
//  Copyright © 2020 Tape It Music GmbH. All rights reserved.
//

import UIKit


class KeyframeAnimator: NotificationConvenience {
    // State
    typealias Keyframe = (relStart: Double, relDuration: Double, animations: () -> Void)
    typealias KeyframeProvider = () -> [Keyframe]
    var keyframeProvider: KeyframeProvider? = nil { didSet { if animator != nil { reload() } } }
    
    typealias Completion = () -> Void
    var completion: Completion? { didSet { if animator != nil { reload() } } }
    
    //
    // To ensure proper "background mode" behaviour of the animator, this property *must* be reliably set to
    // the value of the `window` property of the first common superview of all animated views.
    //
    // When it is set to `nil` the `UIViewPropertyAnimator` instance will be destroyed: The animator moves into "background mode".
    //
    // When it is set to a non-nil value, a new `UIViewPropertyAnimator` instance will be created: The animator returns from the "background mode".
    // The animator's `fractionComplete` property will be updated to reflect the time that passed while the property was set to `false`
    // - if the animation was running before the property was set to `false`, it will then be started again.
    // - if the animation was paused before the property was set to `false`, it will then stay paused.
    //
    var window: UIWindow? { didSet { updateAnimator() } }
    
    // Initializer
    init(duration: Double, curve: UIView.AnimationCurve = .linear, window: UIWindow?) {
        (self.duration, self.curve, self.window) = (duration, curve, window)
        appIsInForeground = UIApplication.shared.applicationState == .active
        handle([
            UIApplication.didEnterBackgroundNotification,
            UIApplication.willEnterForegroundNotification
        ], with: #selector(handleAppLifecycle))
    }
    
    // Destructor
    deinit { destroyAnimator() }
    
    // Animation curve
    private let curve: UIView.AnimationCurve
    
    // Duration
    private let duration: Double
    
    // UIViewPropertyAnimator
    private var animator: UIViewPropertyAnimator?
    private var animationState: AnimationState = .inactive
    private enum AnimationState: Equatable {
        case inactive
        case paused(atProgress: Double)
        case playing(fromProgress: Double, sinceAbsoluteTime: Double)
    }
    
    // App state
    private var appIsInForeground: Bool { didSet { updateAnimator() } }
    
    // Play / Pause
    // Absolute time
    func play(atTime time: Double) { play(atProgress: time / duration) }
    func pause(atTime time: Double) { pause(atProgress: time / duration) }
    
    // Relative progress (`0...1`)
    func play(atProgress progress: Double) {
        animationState = .playing(fromProgress: progress, sinceAbsoluteTime: CACurrentMediaTime())
        updateAnimator()
    }
    
    func pause(atProgress progress: Double) {
        animationState = .paused(atProgress: progress)
        updateAnimator()
    }
    
    // Reload
    // This method should be called if the frames, espcecially the sizes,
    // of views that are animated by this animator have changed.
    // Generally recommended places to do this are:
    // - in a `UIView`, at the end of a `layoutSubviews()` override
    // - in a `UIViewController`, at the end of a `viewDidLayoutSubviews()` override
    @objc func reload() {
        destroyAnimator()
        updateAnimator()
    }
}


// MARK: // Private
private extension KeyframeAnimator {
    @objc func handleAppLifecycle(_ notification: Notification) {
        //
        // When the "Control Centre"/"Notification Centre" is swiped in, the animator runs fine
        // while the "... Centre" is displayed, so we don't need to switch to "background mode".
        // This is also the reason we're listening for the 'didEnterBackgroundNotification',
        // since this notification is only fired when the app actually moves into the background
        // (i.e. not when the "Control Centre"/"Notification Centre" is swiped in).
        //
        // The `willEnterForegroundNotification` *is also fired* when one of the "... Centre"s is dismissed. However,
        // this is not a problem since `updateAnimator()` (which is called in `appIsInForeground.didSet`) is idempotent.
        //
        // We are keeping and tracking our own custom app state since `UIApplication.shared.applicationState`
        // will still be `background` when the `willEnterForegroundNotification` is fired.
        //
        // See comment in SceneDelegate regarding the custom SceneDelegate notifications.
        switch notification.name {
        case UIApplication.didEnterBackgroundNotification:
            appIsInForeground = false
        case UIApplication.willEnterForegroundNotification:
            appIsInForeground = true
        default: return
        }
    }
    
    func updateAnimator() {
        guard window != nil, appIsInForeground else {
            // We're not resetting the `animationState` here, so, when the app returns from "background mode",
            // the implementation can correctly create a new animator if appropriate.
            destroyAnimator()
            return
        }
        
        // If we don't have any keyframes, we don't need an animator.
        guard let keyframes = keyframeProvider?() else { return }
        
        let progress: Double
        switch animationState {
        case .inactive:
            // Don't recreate the animator if it was already finished or has not yet been played or paused.
            return
        case .paused(atProgress: let lastSavedProgress):
            progress = lastSavedProgress
        case .playing(fromProgress: let lastSavedProgress, sinceAbsoluteTime: let absoluteStartTime):
            // If the animator has been running in the background, we calculate the progress since it was last played.
            progress = lastSavedProgress + ((CACurrentMediaTime() - absoluteStartTime) / duration)
        }
        
        if animator == nil {
            animator = UIViewPropertyAnimator(duration: duration, curve: curve) {
                UIView.animateKeyframes(
                    // The duration given here is ignored, only the duration passed to the animator's initializer is regarded.
                    withDuration: 0,
                    // The delay *must be* between 0 and the delay given in the `.startAnimation()` call.
                    // Else, the animation simply skips to the end without actually animating.
                    // Ideally, let's keep it at 0, because I haven't tested and documented the exact behaviour if it's > 0 yet
                    delay: 0,
                    animations: { keyframes.forEach(UIView.addKeyframe) }
                    // We're intentionally not using the `completion` of the `animateKeyframes` method
                    // since modifying the animator in said completion introduces race conditions.
                    // Also, the behaviour of the animator completion block added below is better to handle.
                )
            }
            animator!.addCompletion { [weak self] _ in
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
                // Here, we reset the animationState to .inactive, so no new animator is created
                // if the app returns from the "background mode" or if `reload` is called.
                // A new animator will then only be created again if `play(_:)` or `pause(_:)` is called.
                self?.animationState = .inactive
                // Now, we call the completion block, if one is set.
                self?.completion?()
            }
        }
        
        // The documentation states the following about `fractionComplete`:
        // `You can update the value of this property only while the animator is paused.`
        animator!.pauseAnimation()
        animator!.fractionComplete = CGFloat(progress)
        if case .playing = animationState { animator!.startAnimation() }
    }
    
    // This method is used in three places:
    // - inside `deinit`
    // - inside `updateAnimator` in case the animator moves to the "background mode"
    // - inside `reload`
    // The `animationState` *must not* be changed/reset inside the implementation of this method.
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
}
