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
    private var future: T?
    private var m: pthread_mutex_t
    
    init() {
        m = pthread_mutex_t()
        pthread_mutex_lock(&m)
    }
    
    ///Use this method to block until the result is available.
    func get() -> T? {
        pthread_mutex_lock(&m)
        defer {pthread_mutex_unlock(&m)}
        return future
    }
    
    ///If you did not create the object, do not use this method.
    ///Otherwise, behavior will be undefined.
    func set(t: T?) {
        defer {pthread_mutex_unlock(&m)}
        future = t
    }
}
