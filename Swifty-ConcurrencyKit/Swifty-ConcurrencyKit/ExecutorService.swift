//
//  ExecutorService.swift
//  Swifty-ConcurrencyKit
//
//  Created by Bruce Brookshire on 2/27/18.
//  Copyright © 2018 bruce-brookshire.com. All rights reserved.
//

///Protocol for SwiftyThread to communicate with its ExecutorService owner
fileprivate protocol SwiftyThreadDelegate {
    func getNextTask() -> (() -> Void)?
    func timeOutThread()
}

///ExecutorService uses a specified number of threads to run tasks asynchronously in the background
///Tasks can be runnable or callable, the latter being fulfilled through a potentially blocking call to Future.get()
///It is recommended that Future.get() for Callables only be called after all tasks first submitted for processing.
public class ExecutorService: SwiftyThreadDelegate
{
    ///Worker threads for the tasks submitted to the queue
    private var threads: [SwiftyThread]
    ///The queue of tasks
    private var queue: BlockingQueue<() -> Void>
    ///Prevents multiple threads from modifying the ThreadPool at the same time
    private var threadQueueLock: NSLock = NSLock()
    ///Counter to keep track of unique thread ID names
    private var threadId = 0
    ///If the thread pool autoscales
    private var autoScaling: Bool
    ///QualityOfService delivered by the threads in the ThreadPool
    private var qos: QualityOfService
    ///Shutdown flag
    var isShutdown: Bool
    
    ///Returns if the thread pool will autoscale threads
    var isAutoScaling: Bool {
        get {
            return autoScaling
        }
        set {
            autoScaling = newValue
            if threads.count == 0 {
                let processors = ProcessInfo.processInfo.activeProcessorCount
                do {
                    try addThreads(quantity: (processors > 1 ? (processors - 1) : 1))
                } catch {
                    shutdownEventually()
                    print("Unknown executor service issue. shutting down.")
                }
                
            } else {
                threadQueueLock.lock()
                for thread in threads {
                    thread.isScalable = autoScaling
                }
                threadQueueLock.unlock()
            }
        }
    }
    
    ///The quality of service of thread execution
    var qualityOfService: QualityOfService {
        get {
            return qos
        }
        set {
            qos = newValue
            threadQueueLock.lock()
            for thread in threads {
                thread.qualityOfService = newValue
            }
            threadQueueLock.unlock()
        }
    }
    
    ///Number of working threads
    var numberOfThreads: Int {
        get {
            return threads.count
        }
    }
    
    ///Initializes ExecutorService to be able to process submitted tasks
    /// - parameter threadCount: Number of threads to utilize in processing. Default is 1
    /// - parameter qos: Quality of service with which to process submitted tasks. Default is .default
    public init (threadCount: Int? = nil, qos: QualityOfService = .default, autoScaling: Bool = true) {
        threads = []
        queue = BlockingQueue()
        self.autoScaling = autoScaling
        self.qos = qos
        self.isShutdown = false
        
        var threadCount = threadCount
        if threadCount == nil {
            let processors = ProcessInfo.processInfo.activeProcessorCount
            threadCount = (processors > 1 ? (processors - 1) : 1)
        }
        
        for i in 0..<threadCount! {
            threads.append(SwiftyThread(delegate: self, qos: qos, isScalable: autoScaling))
            threads[i].name = String(i)
        }
        threadId = threadCount!
        
        for thread in threads { thread.start() }
    }
    
    ///Shuts down the threads before exiting
    deinit { if threads.count > 0 { shutdownEventually() } }
    
    ///Delegate method for a SwiftyThread to retreive the next processable entity
    /// - returns: A processable entity. If nil, there was no process to complete
    fileprivate func getNextTask() -> (() -> Void)? {
        return queue.timedNext(waitTimeSeconds: 5)
    }
    
    ///Scales the number of threads according to the size of the work queue
    private func scaleIfNecessary() {
        if autoScaling && queue.unsafeGetSize()/2 > threads.count {
            threadQueueLock.lock()
            defer { threadQueueLock.unlock() }
            
            let thread = SwiftyThread(delegate: self, qos: qos, isScalable: autoScaling)
            thread.name = String(threadId)
            threads.append(thread)
            thread.start()
            
            threadId += 1
        }
    }
    
    ///Adds the specified number of threads to the pool
    /// - parameter quantity: Number of threads to add
    /// - throws: if quantity <= 0
    public func addThreads(quantity: Int) throws {
        guard !isShutdown else {
            throw ExecutorServiceError.IllegalState("You are modifying a shutdown executor!")
        }
        
        threadQueueLock.lock()
        defer { threadQueueLock.unlock() }
        
        if quantity <= 0 {
            throw ExecutorServiceError.InvalidValue("Cannot add a non-positive number of threads")
        } else {
            for _ in 0..<quantity {
                let thread = SwiftyThread(delegate: self, qos: qos, isScalable: autoScaling)
                thread.name = String(threadId)
                threads.append(thread)
                thread.start()
                threadId += 1
            }
        }
    }
    
    ///Removes the specified number of threads from the pool
    /// - parameter quantity: Number of threads to remove
    /// - throws: if quantity <= 0 or > existing thread pool size
    public func reduceThreads(quantity: Int) throws {
        guard !isShutdown else {
            throw ExecutorServiceError.IllegalState("You are modifying a shutdown executor!")
        }
        
        threadQueueLock.lock()
        defer { threadQueueLock.unlock() }
        
        if quantity <= 0 {
            throw ExecutorServiceError.InvalidValue("Cannot remove a non-positive number of threads")
        } else if quantity > threads.count {
            throw ExecutorServiceError.InvalidValue("Cannot remove more threads than exist")
        } else {
            for i in 0..<quantity {
                threads[i].cancel()
            }
        }
    }
    
    ///Removes thread from active working thread array. Only works if thread is in ThreadPool
    fileprivate func timeOutThread() {
        threadQueueLock.lock()
        defer { threadQueueLock.unlock() }
        
        let name = Thread.current.name!
        for i in 0..<threads.count {
            if threads[i].name! == name { threads.remove(at: i); break}
        }
    }
    
    ///Submit a callable for execution
    /// - parameter callable: A Callable that processes and returns an entity
    /// - returns: A Future to the entity returned from Callable
    public func submit<T>(_ callable: Callable<T>) -> Future<T> { return submit(callable.call) }
    
    ///Submit a Runnable for execution
    /// - parameter runnable: A Runnable that processes a task
    public func submit(_ runnable: Runnable) { submit(runnable.run) }
    
    ///Submit a callable for execution
    /// - parameter lambda: A callable that processes and returns an entity
    /// - returns: A Future to the entity returned from lambda
    public func submit<T>(_ lambda: @escaping () -> T?) -> Future<T> {
        guard !isShutdown else { print("You are submitting to a shutdown executor!"); return Future() }
        let future = Future<T>()
        let task = { future.set(t: lambda()) }
        
        queue.insert(task)
        scaleIfNecessary()
        return future
    }
    
    ///Submit a task for execution
    /// - parameter task: A runnable that processes a task
    public func submit(_ task: @escaping () -> Void) {
        guard !isShutdown else { print("You are submitting to a shutdown executor!"); return }
        queue.insert(task)
        scaleIfNecessary()
    }
    
    ///Shutdown current threads managed by the ExecutorService
    public func shutdownEventually() {
        isShutdown = true
        for thread in threads {
            thread.cancel()
        }
        threads = []
    }
    
    public enum ExecutorServiceError: Error {
        case InvalidValue(String)
        case IllegalState(String)
    }
}

///Custom Thread class to be able to retrieve tasks to process utilizing
///     a work stealing approach
fileprivate class SwiftyThread: Thread
{
    private var swifty_delegate: SwiftyThreadDelegate
    fileprivate var isScalable: Bool
    
    ///Submit a callable for execution
    /// - parameter delegate: Protocol that delivers the source of tasks to process
    /// - parameter qos: Service quality to be performed by the thread
    init(delegate: SwiftyThreadDelegate, qos: QualityOfService, isScalable: Bool) {
        self.swifty_delegate = delegate
        self.isScalable = isScalable
        super.init()
        qualityOfService = qos
    }
    
    ///Hook method overriden from Thread to perform execution.
    ///     accesses delegate for task supply. If there is no task to perform,
    ///     Thread blocks for 60s then shuts down.
    override func main() {
        while (!isCancelled) {
            if let task = swifty_delegate.getNextTask() {
                task()
            } else {
                if isScalable {
                    cancel()
                }
            }
        }
        swifty_delegate.timeOutThread()
    }
}

///Template class. Implement and override run() to submit a task to ExecutorService
open class Runnable { open func run() {} }

///Template class. Implement and override call() -> T? to submit a task to ExecutorService
open class Callable<T> { open func call() -> T? { return nil } }
