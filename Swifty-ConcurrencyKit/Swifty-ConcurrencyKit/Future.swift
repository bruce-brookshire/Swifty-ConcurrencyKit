//
//  Future.swift
//  Swifty-ConcurrencyKit
//
//  Created by Bruce Brookshire on 2/27/18.
//  Copyright © 2018 bruce-brookshire.com. All rights reserved.
//

import Foundation

///Vehicle to deliver an object after asynchronous processing is complete
class Future<T>
{
    ///The future value to deliver upon a blocking get()
    private var future: T?
    ///DispatchSemaphore used in place of sem_t, as sem_t is unavailable
    ///for use in Swift.
    private var s: DispatchSemaphore
    
    ///Initialises the semaphore such that when self is given to the user,
    ///get() only returns after the value is filled from the source given by the user.
    init() {
        s = DispatchSemaphore(value: 1)
        s.wait()
    }
    
    ///Use this method to block until the result is available.
    /// - returns: the value expected from the operation that created self: Future
    func get() -> T? {
        s.wait()
        defer { s.signal() }
        return future
    }
    
    ///Tries to secure the value from self. Returns after 1/10th of a second if
    ///the value is still unavailable.
    /// - returns: A tuple containing the success of the attempt and the value if successful.
    ///value should be ignored if success is false.
    func tryGet() -> (success: Bool,value: T?) {
        let result = s.wait(timeout: DispatchTime.now() + 0.1)
        
        if result == .success {
            defer { s.signal() }
            return (true, future)
        } else {
            return (false, nil)
        }
    }
    
    ///If you did not create the object, do not use this method.
    ///Otherwise, behavior will be undefined. Results in the availability of the future.
    /// - parameter t: the value to set of type T
    func set(t: T?) {
        defer { s.signal() }
        future = t
    }
}
