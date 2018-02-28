// ExecutorService.swift
// Description: An API based on Java's ExecutorService API
//
// Created by: Bruce Brookshire
//

import Foundation

fileprivate protocol SwiftyThreadDelegate {
    func getNextTask() -> (() -> Void)?
}

///ExecutorService uses a specified number of threads to run tasks asynchronously in the background
///Tasks can be runnable or callable, the latter being fulfilled through a potentially blocking call to Future.get()
///It is recommended that Future.get() for Callables only be called after all tasks first submitted for processing.
final class ExecutorService: SwiftyThreadDelegate
{
    private var threads: [SwiftyThread]
    private var queue: ArrayBlockingQueue<() -> Void>
    
    ///Initializes ExecutorService to be able to process submitted tasks
    /// - parameter threadCount: Number of threads to utilize in processing. Default is 1
    /// - parameter qos: Quality of service with which to process submitted tasks. Default is .default
    init (threadCount: Int = 1, qos: QualityOfService = .default) {
        threads = []
        queue = ArrayBlockingQueue()
        
        for i in 0..<threadCount {
            threads.append(SwiftyThread(delegate: self, qos: qos))
            threads[i].name = String(i)
        }
        
        for thread in threads { thread.start() }
    }
    
    deinit { if threads.count > 0 { shutdownNow() } }
    
    ///Delegate method for a SwiftyThread to retreive the next processable entity
    /// - returns: A processable entity. If nil, there was no process to complete
    func getNextTask() -> (() -> Void)? {
        queue.lock()
        defer {queue.unlock()}
        
        if queue.size() > 0 {
            return queue.next()
        } else {
            return nil
        }
    }
    
    ///Submit a callable for execution
    /// - parameter callable: A Callable that processes and returns an entity
    /// - returns: A Future to the entity returned from Callable
    func submit<T>(_ callable: Callable<T>) -> Future<T> { return submit(callable.call) }
    
    ///Submit a Runnable for execution
    /// - parameter runnable: A Runnable that processes a task
    func submit(_ runnable: Runnable) { submit(runnable.run) }
    
    ///Submit a callable for execution
    /// - parameter lambda: A callable that processes and returns an entity
    /// - returns: A Future to the entity returned from lambda
    func submit<T>(_ lambda: @escaping () -> T?) -> Future<T> {
        queue.lock()
        defer {queue.unlock()}
        
        let future = Future<T>()
        let task = { future.set(t: lambda()) }
        
        queue.insert(task)
        
        return future
    }
    
    ///Submit a task for execution
    /// - parameter task: A runnable that processes a task
    func submit(_ task: @escaping () -> Void) {
        queue.lock()
        defer {queue.unlock()}
        
        queue.insert(task)
    }
    
    ///Shutdown current threads managed by the ExecutorService
    func shutdownNow() {
        for thread in threads {
            thread.cancel()
        }
        for thread in threads {
            print(thread.isCancelled)
        }
        threads = []
    }
}

///Custom Thread class to be able to retrieve tasks to process utilizing
///     a work stealing approach
fileprivate class SwiftyThread: Thread
{
    private var swifty_delegate: SwiftyThreadDelegate
    
    ///Submit a callable for execution
    /// - parameter delegate: Protocol that delivers the source of tasks to process
    /// - parameter qos: Service quality to be performed by the thread
    init(delegate: SwiftyThreadDelegate, qos: QualityOfService) {
        self.swifty_delegate = delegate
        super.init()
        qualityOfService = qos
    }
    
    ///Hook method overriden from Thread to perform execution.
    ///     accesses delegate for task supply. If there is no task to perform,
    ///     Thread sleeps for 1/100th of a second.
    override func main() {
        while (true) {
            if let task = swifty_delegate.getNextTask() { task() }
            else { Thread.sleep(forTimeInterval: 0.01) }
        }
    }
}

///Template class. Implement and override run() to submit a task to ExecutorService
class Runnable { func run() {} }

///Template class. Implement and override call() -> T? to submit a task to ExecutorService
class Callable<T> { func call() -> T? { return nil } }
