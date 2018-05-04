//
//  Future.swift
//  Swifty-ConcurrencyKit
//
//  Created by Bruce Brookshire on 2/27/18.
//  Copyright © 2018 bruce-brookshire.com. All rights reserved.
//


///Vehicle to deliver an object after asynchronous processing is complete
public class Future<T>
{
    ///The future value to deliver upon a blocking get()
    private var future: T?
    
    ///DispatchSemaphore used in place of sem_t, as sem_t is unavailable
    ///for use in Swift.
    private var s: DispatchSemaphore
    
    ///Shows that the operation has been completed and guarded suspension can release
    private var completed = false    

    ///Initialises the semaphore such that when self is given to the user,
    ///get() only returns after the value is filled from the source given by the user.
    public init() {
        s = DispatchSemaphore(value: 1)
        s.wait()
    }
    
    ///Use this method to block until the result is available.
    /// - returns: the value expected from the operation that created self: Future
    public func get() -> T? {
        while !completed {  s.wait() }
        defer { s.signal() }
        return future
    }
    
    ///Succeeds with getting the value if it is immediately available
    /// - returns: A tuple containing the success of the attempt and the value if successful.
    ///value should be ignored if success is false.
    func tryGet() -> (success: Bool,value: T?) {
        if completed {
            defer { s.signal() }
            return (true, future)
        } else {
            return (false, nil)
        }
    }
    
    ///If you did not create the object, do not use this method.
    ///Otherwise, behavior will be undefined. Results in the availability of the future.
    /// - parameter t: the value to set of type T
    public func set(t: T?) {
        defer {
            completed = true
            s.signal()
        }

        future = t
    }
}
