//
//  Notification Convenience.swift
//  TapeIt
//
//  Created by Jan Nash on 18.10.20.
//  Copyright © 2020 Tape It Music GmbH. All rights reserved.
//

import Foundation


@objc protocol NotificationConvenience {
    @objc optional func sender(for notificationName: Notification.Name) -> Any
}


extension NotificationConvenience {
    func handle(_ notificationName: Notification.Name, from object: Any? = nil, with handler: Selector) {
        handle([notificationName], from: object, with: handler)
    }
    
    func handle(_ notificationNames: [Notification.Name], from object: Any? = nil, with handlers: Selector...) {
        let senderFor = (object as? NotificationConvenience)?.resolvedSender ?? { _ in object }
        notificationNames.forEach { name in
            handlers.forEach { NotificationCenter.default.addObserver(self, selector: $0, name: name, object: senderFor(name)) }
        }
    }
    
    func post(_ notificationName: Notification.Name, userInfo: [Notification.UserInfoKey: Any]? = nil) {
        NotificationCenter.default.post(name: notificationName, object: resolvedSender(for: notificationName), userInfo: userInfo)
    }
    
    static func post(_ notificationName: Notification.Name, userInfo: [Notification.UserInfoKey: Any]? = nil) {
        NotificationCenter.default.post(name: notificationName, object: self, userInfo: userInfo)
    }
    
    func isSender(of notification: Notification) -> Bool {
        notification.object as AnyObject === resolvedSender(for: notification.name)
    }
    
    private func resolvedSender(for notificationName: Notification.Name) -> AnyObject {
        (sender?(for: notificationName) ?? self) as AnyObject
    }
}


extension Optional where Wrapped: NotificationConvenience {
    func isSender(of notification: Notification) -> Bool {
        self?.isSender(of: notification) ?? false
    }
}


extension Notification {
    struct UserInfoKey: Hashable {
        init(_ rawKey: AnyHashable) { self.rawKey = rawKey }
        fileprivate let rawKey: AnyHashable
    }
    
    func value<T>(for key: UserInfoKey) -> T? { userInfo?[key] as? T }
}


extension NSObject: NotificationConvenience {}
