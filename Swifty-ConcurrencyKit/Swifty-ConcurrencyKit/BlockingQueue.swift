//
//  BlockingQueue.swift
//  Swifty-ConcurrencyKit
//
//  Created by Bruce Brookshire on 2/27/18.
//  Copyright © 2018 bruce-brookshire.com. All rights reserved.
//

///BlockingQueue ensures thread-safe semantics by requiring
///only one thread at a time to access the queue at a time.
///If the queue is empty, instead of devising inefficient ways to spin and check,
///BlockingQueue will block the current thread until a task is available.
class BlockingQueue<T>
{
    
    ///Node for the linked list implementation of our queue
    private class Node<T> {
        var value: T
        var previous: Node<T>?
        init(value: T) { self.value = value }
    }
    
    ///Front of our queue
    private var front: Node<T>?
    ///Back of our queue
    private var back: Node<T>?
    ///Size of our queue
    private var size: Int
    
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
        size = 0
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
        
        if front == nil {
            front = Node<T>(value: element)
            back = front
        } else {
            back?.previous = Node<T>(value: element)
            back = back?.previous
        }
        
        size += 1
        
        if size == 1 {
            pthread_cond_signal(&q_not_empty)
        }
    }
    
    ///Pops the next element from the queue in a thread safe manner.
    /// - returns: The element popped from the front of the queue
    func next() -> T {
        pthread_mutex_lock(&m)
        defer { pthread_mutex_unlock(&m) }
        
        while(size == 0) {
            pthread_cond_wait(&q_not_empty, &m)
        }
        
        return getNext()
    }
    
    ///Attemps to pop the next element from the queue in a thread safe manner.
    ///Only succeeds if the lock is uncontested and the queue is not empty
    /// - returns: The success of the operation and the element popped from the front of the queue (returns nil if failed)
    func tryNext() -> (success: Bool, value: T?) {
        let success = pthread_mutex_trylock(&m)
        if success != 0 || size == 0 { return (false, nil) }
        defer { pthread_mutex_unlock(&m) }
        return (true, getNext())
    }
    
    ///Returns the next element in the queue.
    ///Helper method
    private func getNext() -> T {
        let element = front
        
        if size == 1 {
            back = nil
            front = nil
        } else {
            front = front?.previous
        }
        
        size -= 1
        return element!.value
    }
    
    ///Gets the size of the queue. Operation is only a rough estimate, as it does not
    ///contest for a lock for an accurate value.
    /// - returns: A close estimate of the size of the queues
    func unsafeGetSize() -> Int {
        return size
    }
    
    ///Gets the size of the queue. Operation blocks until lock is acquired to provide an accurate size
    /// - returns: Size of the queue
    func getSize() -> Int {
        pthread_mutex_lock(&m)
        defer { pthread_mutex_unlock(&m) }
        return size
    }
}


