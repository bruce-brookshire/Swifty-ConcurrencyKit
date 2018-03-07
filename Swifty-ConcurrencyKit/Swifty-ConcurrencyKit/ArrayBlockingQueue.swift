//
//  ArrayBlockingQueue.swift
//  Swifty-ConcurrencyKit
//
//  Created by Bruce Brookshire on 2/27/18.
//  Copyright © 2018 bruce-brookshire.com. All rights reserved.
//

///ArrayBlockingQueue ensures thread-safe semantics by requiring
///only one thread at a time to access the queue at a time.
///If the queue is empty, instead of devising inefficient ways to spin and check,
///ArrayBlockingQueue will block the current thread until a task is available.
class ArrayBlockingQueue<T>
{
    ///Array to hold values
    private var array: [T] = []
    ///Low-level lock to ensure fast and responsive Mutual Exclusion between threads
    private var m: pthread_mutex_t
    ///Low-level condition variable to allow efficient thread blocking/wake semantics
    ///based on queue state
    private var q_not_empty: pthread_cond_t
    
    ///Initialize lock and condition variables to ensure that they are always available
    ///for use during the lifecycle of the queue.
    init() {
        m = pthread_mutex_t()
        pthread_mutex_init(&m, nil)
        q_not_empty = pthread_cond_t()
        pthread_cond_init(&q_not_empty, nil)
    }
    
    ///Destroy lock and condition variable on deinit.
    deinit {
        pthread_mutex_destroy(&m)
        pthread_cond_destroy(&q_not_empty)
    }
    
    ///Inserts the element: T into the queue in a thread safe manner.
    func insert(_ element: T) {
        pthread_mutex_lock(&m)
        defer { pthread_mutex_unlock(&m) }
        array.append(element)
        if array.count == 1 {
            pthread_cond_signal(&q_not_empty)
        }
    }
    
    ///Returns and pops the next element from the queue in a thread safe manner.
    func next() -> T {
        pthread_mutex_lock(&m)
        defer { pthread_mutex_unlock(&m) }
        
        while(array.count == 0) {
            pthread_cond_wait(&q_not_empty, &m)
        }
        
        return array.remove(at: 0)
    }
}


